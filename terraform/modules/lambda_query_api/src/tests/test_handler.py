import json
import unittest
from decimal import Decimal
from unittest.mock import patch

import handler


class _FakeTable:
    def __init__(self, name):
        self.name = name
        self.query_result = {"Items": []}
        self.last_query_kwargs = None

    def query(self, **kwargs):  # noqa: ANN003
        self.last_query_kwargs = kwargs
        return self.query_result


class _FakeDynamo:
    def __init__(self):
        self.tables = {}

    def Table(self, name):  # noqa: N802
        if name not in self.tables:
            self.tables[name] = _FakeTable(name)
        return self.tables[name]


class QueryHandlerTests(unittest.TestCase):
    def setUp(self):
        self.fake_dynamo = _FakeDynamo()
        self.patch_dynamo = patch.object(handler, "dynamodb", self.fake_dynamo)
        self.patch_dynamo.start()

    def tearDown(self):
        self.patch_dynamo.stop()

    def _event(self, route, device_id="esp32-c", query=None):
        return {
            "routeKey": route,
            "rawPath": route.split(" ")[-1].replace("{deviceId}", device_id),
            "pathParameters": {"deviceId": device_id},
            "queryStringParameters": query or {},
        }

    def test_latest_telemetry_returns_200(self):
        table = self.fake_dynamo.Table(handler.TELEMETRY_TABLE_NAME)
        table.query_result = {
            "Items": [
                {
                    "device_id": "esp32-c",
                    "effective_ts": Decimal("1782036270"),
                    "payload": {"type": "connectivity", "rssi": Decimal("-50")},
                }
            ]
        }
        event = self._event("GET /devices/{deviceId}/telemetry/latest")

        result = handler.lambda_handler(event, None)

        self.assertEqual(result["statusCode"], 200)
        body = json.loads(result["body"])
        self.assertEqual(body["device_id"], "esp32-c")
        self.assertEqual(body["telemetry"]["type"], "connectivity")
        self.assertEqual(body["telemetry"]["rssi"], -50)

    def test_recent_events_limit_and_count(self):
        table = self.fake_dynamo.Table(handler.EVENTS_TABLE_NAME)
        table.query_result = {
            "Items": [
                {"payload": {"type": "button", "event": "press", "ts": Decimal("1")}},
                {"payload": {"type": "button", "event": "press", "ts": Decimal("2")}},
            ]
        }
        event = self._event("GET /devices/{deviceId}/events", query={"limit": "2"})

        result = handler.lambda_handler(event, None)

        self.assertEqual(result["statusCode"], 200)
        body = json.loads(result["body"])
        self.assertEqual(body["count"], 2)
        self.assertEqual(body["limit"], 2)
        self.assertEqual(table.last_query_kwargs["Limit"], 2)

    def test_missing_device_returns_400(self):
        event = {"routeKey": "GET /devices/{deviceId}/events", "pathParameters": {}}
        result = handler.lambda_handler(event, None)
        self.assertEqual(result["statusCode"], 400)

    def test_empty_result_returns_404(self):
        event = self._event("GET /devices/{deviceId}/events")
        result = handler.lambda_handler(event, None)
        self.assertEqual(result["statusCode"], 404)

    def test_invalid_limit_returns_400(self):
        event = self._event("GET /devices/{deviceId}/events", query={"limit": "abc"})
        result = handler.lambda_handler(event, None)
        self.assertEqual(result["statusCode"], 400)


if __name__ == "__main__":
    unittest.main()
