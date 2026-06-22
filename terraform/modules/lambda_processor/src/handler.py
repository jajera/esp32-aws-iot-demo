import hashlib
import json
import os
import time
from decimal import Decimal

try:
    import boto3
except ModuleNotFoundError:  # Local test environments may not ship boto3.
    boto3 = None


TELEMETRY_TABLE_NAME = os.getenv("TELEMETRY_TABLE_NAME", "telemetry")
EVENTS_TABLE_NAME = os.getenv("EVENTS_TABLE_NAME", "events")

dynamodb = boto3.resource("dynamodb") if boto3 else None


def _now_epoch() -> int:
    return int(time.time())


def _normalize_event(event):
    if isinstance(event, str):
        return json.loads(event)
    if isinstance(event, dict) and "body" in event and isinstance(event["body"], str):
        return json.loads(event["body"])
    if isinstance(event, dict):
        return event
    raise ValueError("Unsupported event payload")


def _extract_record_type(payload: dict) -> str:
    event_type = payload.get("type")
    if event_type == "button":
        return "event"
    return "telemetry"


def _effective_ts(payload: dict):
    raw_ts = payload.get("ts", 0)
    try:
        ts = int(raw_ts)
    except (TypeError, ValueError):
        ts = 0

    if ts <= 0:
        return _now_epoch(), True
    return ts, False


def _record_id(payload: dict, record_type: str, effective_ts: int) -> str:
    canonical = json.dumps(payload, sort_keys=True, separators=(",", ":"))
    digest_input = f"{record_type}:{payload['device_id']}:{effective_ts}:{canonical}"
    return hashlib.sha256(digest_input.encode("utf-8")).hexdigest()


def _to_dynamo_value(value):
    if isinstance(value, float):
        return Decimal(str(value))
    if isinstance(value, list):
        return [_to_dynamo_value(item) for item in value]
    if isinstance(value, dict):
        return {k: _to_dynamo_value(v) for k, v in value.items()}
    return value


def _select_table(record_type: str):
    if dynamodb is None:
        raise RuntimeError("DynamoDB client is not initialized")
    table_name = EVENTS_TABLE_NAME if record_type == "event" else TELEMETRY_TABLE_NAME
    return dynamodb.Table(table_name)


def _validate_payload(payload: dict):
    required_fields = ("device_id", "ts", "type")
    missing = [field for field in required_fields if field not in payload]
    if missing:
        raise ValueError(f"Missing required fields: {', '.join(missing)}")

    if not str(payload["device_id"]).strip():
        raise ValueError("device_id must be non-empty")


def _build_item(payload: dict):
    _validate_payload(payload)

    record_type = _extract_record_type(payload)
    effective_ts, ts_fallback_used = _effective_ts(payload)
    record_id = _record_id(payload, record_type, effective_ts)

    return {
        "device_id": str(payload["device_id"]),
        "record_id": record_id,
        "record_type": record_type,
        "effective_ts": effective_ts,
        "ts_original": int(payload.get("ts", 0) or 0),
        "ts_fallback_used": ts_fallback_used,
        "ingest_ts": _now_epoch(),
        "payload": _to_dynamo_value(payload),
    }


def lambda_handler(event, _context):
    payload = _normalize_event(event)
    item = _build_item(payload)
    table = _select_table(item["record_type"])

    table.put_item(
        Item=item,
        ConditionExpression="attribute_not_exists(device_id) AND attribute_not_exists(record_id)",
    )

    return {
        "statusCode": 200,
        "record_type": item["record_type"],
        "table_name": table.name,
        "record_id": item["record_id"],
        "effective_ts": item["effective_ts"],
        "ts_fallback_used": item["ts_fallback_used"],
    }
