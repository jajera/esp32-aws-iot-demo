import json
import os
from decimal import Decimal

try:
    import boto3
except ModuleNotFoundError:  # Local tests may not have boto3
    boto3 = None


TELEMETRY_TABLE_NAME = os.getenv("TELEMETRY_TABLE_NAME", "telemetry")
EVENTS_TABLE_NAME = os.getenv("EVENTS_TABLE_NAME", "events")
DEFAULT_EVENTS_LIMIT = int(os.getenv("DEFAULT_EVENTS_LIMIT", "10"))
MAX_EVENTS_LIMIT = int(os.getenv("MAX_EVENTS_LIMIT", "50"))

dynamodb = boto3.resource("dynamodb") if boto3 else None


def _json_default(value):
    if isinstance(value, Decimal):
        if value % 1 == 0:
            return int(value)
        return float(value)
    raise TypeError(f"Unsupported JSON type: {type(value)}")


def _response(status_code: int, body: dict):
    return {
        "statusCode": status_code,
        "headers": {"content-type": "application/json"},
        "body": json.dumps(body, default=_json_default),
    }


def _table(name: str):
    if dynamodb is None:
        raise RuntimeError("DynamoDB client is not initialized")
    return dynamodb.Table(name)


def _query_latest_telemetry(device_id: str):
    result = _table(TELEMETRY_TABLE_NAME).query(
        IndexName="device_ts_idx",
        KeyConditionExpression="#d = :device",
        ExpressionAttributeNames={"#d": "device_id"},
        ExpressionAttributeValues={":device": device_id},
        ScanIndexForward=False,
        Limit=1,
    )
    return result.get("Items", [])


def _query_recent_events(device_id: str, limit: int):
    result = _table(EVENTS_TABLE_NAME).query(
        IndexName="device_ts_idx",
        KeyConditionExpression="#d = :device",
        ExpressionAttributeNames={"#d": "device_id"},
        ExpressionAttributeValues={":device": device_id},
        ScanIndexForward=False,
        Limit=limit,
    )
    return result.get("Items", [])


def _parse_limit(event):
    raw = (event.get("queryStringParameters") or {}).get("limit")
    if raw is None or raw == "":
        return DEFAULT_EVENTS_LIMIT
    try:
        value = int(raw)
    except (TypeError, ValueError):
        raise ValueError("limit must be an integer")
    if value <= 0:
        raise ValueError("limit must be > 0")
    return min(value, MAX_EVENTS_LIMIT)


def _parse_route(event):
    route_key = event.get("routeKey", "")
    if route_key:
        if "telemetry/latest" in route_key:
            return "telemetry_latest"
        if "events" in route_key:
            return "events_recent"
    raw_path = event.get("rawPath", event.get("path", ""))
    if raw_path.endswith("/telemetry/latest"):
        return "telemetry_latest"
    if raw_path.endswith("/events"):
        return "events_recent"
    return None


def lambda_handler(event, _context):
    device_id = (event.get("pathParameters") or {}).get("deviceId")
    if not device_id:
        return _response(400, {"error": "deviceId path parameter is required"})

    route = _parse_route(event)
    if route is None:
        return _response(400, {"error": "unsupported route"})

    if route == "telemetry_latest":
        items = _query_latest_telemetry(device_id)
        if not items:
            return _response(404, {"error": f"No telemetry for device_id={device_id}"})
        return _response(
            200,
            {
                "device_id": device_id,
                "telemetry": items[0].get("payload", {}),
                "record": items[0],
            },
        )

    try:
        limit = _parse_limit(event)
    except ValueError as exc:
        return _response(400, {"error": str(exc)})

    items = _query_recent_events(device_id, limit)
    if not items:
        return _response(404, {"error": f"No events for device_id={device_id}"})

    return _response(
        200,
        {
            "device_id": device_id,
            "events": [item.get("payload", {}) for item in items],
            "records": items,
            "count": len(items),
            "limit": limit,
        },
    )
