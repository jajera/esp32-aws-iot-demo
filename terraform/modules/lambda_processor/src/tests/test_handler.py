import unittest
from unittest.mock import patch

import handler


class _FakeTable:
    def __init__(self, name):
        self.name = name
        self.last_item = None

    def put_item(self, Item, ConditionExpression):  # noqa: N803 (AWS style)
        self.last_item = {
            "Item": Item,
            "ConditionExpression": ConditionExpression,
        }
        return {"ResponseMetadata": {"HTTPStatusCode": 200}}


class _FakeDynamo:
    def __init__(self):
        self.tables = {}

    def Table(self, name):  # noqa: N802 (boto3 style)
        if name not in self.tables:
            self.tables[name] = _FakeTable(name)
        return self.tables[name]


class HandlerTests(unittest.TestCase):
    def setUp(self):
        self.fake_dynamo = _FakeDynamo()
        self.dynamo_patch = patch.object(handler, "dynamodb", self.fake_dynamo)
        self.dynamo_patch.start()

    def tearDown(self):
        self.dynamo_patch.stop()

    def test_telemetry_payload_writes_to_telemetry_table(self):
        payload = {
            "device_id": "esp32-c",
            "ts": 1782033006,
            "type": "connectivity",
            "rssi": -48,
        }

        result = handler.lambda_handler(payload, None)

        self.assertEqual(result["statusCode"], 200)
        self.assertEqual(result["record_type"], "telemetry")
        self.assertEqual(result["table_name"], handler.TELEMETRY_TABLE_NAME)
        self.assertFalse(result["ts_fallback_used"])

        written = self.fake_dynamo.tables[handler.TELEMETRY_TABLE_NAME].last_item
        self.assertEqual(written["Item"]["device_id"], "esp32-c")
        self.assertEqual(written["Item"]["payload"]["type"], "connectivity")

    def test_button_payload_writes_to_events_table(self):
        payload = {
            "device_id": "esp32-c",
            "ts": 1782032741,
            "type": "button",
            "event": "press",
        }

        result = handler.lambda_handler(payload, None)

        self.assertEqual(result["record_type"], "event")
        self.assertEqual(result["table_name"], handler.EVENTS_TABLE_NAME)
        written = self.fake_dynamo.tables[handler.EVENTS_TABLE_NAME].last_item
        self.assertEqual(written["Item"]["payload"]["event"], "press")

    @patch("handler._now_epoch", return_value=1700000000)
    def test_ts_zero_uses_fallback_timestamp(self, _mock_now):
        payload = {
            "device_id": "esp32-c",
            "ts": 0,
            "type": "connectivity",
        }

        result = handler.lambda_handler(payload, None)

        self.assertTrue(result["ts_fallback_used"])
        self.assertEqual(result["effective_ts"], 1700000000)

    def test_missing_base_fields_raises(self):
        payload = {"device_id": "esp32-c", "type": "connectivity"}
        with self.assertRaises(ValueError):
            handler.lambda_handler(payload, None)


if __name__ == "__main__":
    unittest.main()
