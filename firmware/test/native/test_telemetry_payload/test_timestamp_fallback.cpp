#include <unity.h>

#include <ArduinoJson.h>
#include <rapidcheck.h>

#include "payload_codec.h"

namespace {
TelemetryData sampleTelemetry(const char* id, uint32_t ts, int rssi, uint32_t uptime_s, uint32_t heap_free,
                              float chip_temp_c) {
  TelemetryData data {};
  data.device_id = id;
  data.ts = ts;
  data.rssi = rssi;
  data.uptime_s = uptime_s;
  data.heap_free = heap_free;
  data.chip_temp_c = chip_temp_c;
  copyField(data.chip_model, sizeof(data.chip_model), "ESP32-S3");
  data.cpu_mhz = 240;
  data.flash_bytes = 16777216;
  copyField(data.wifi_ssid, sizeof(data.wifi_ssid), "demo-wifi");
  data.wifi_status = 3;
  data.wifi_channel = 6;
  copyField(data.wifi_ip, sizeof(data.wifi_ip), "192.168.1.10");
  copyField(data.wifi_gateway, sizeof(data.wifi_gateway), "192.168.1.1");
  copyField(data.wifi_dns, sizeof(data.wifi_dns), "8.8.8.8");
  data.clock_offset_ms = 0;
  return data;
}
}  // namespace

void test_property_timestamp_fallback() {
  const bool ok = rc::check(
      "Feature: esp32-aws-iot-demo, Property 6: Timestamp fallback when NTP unavailable", []() {
        const TelemetryData data = sampleTelemetry(
            "thing-test",
            0,
            static_cast<int>(*rc::gen::inRange(-127, 1)),
            static_cast<uint32_t>(*rc::gen::inRange(0, 1000000)),
            static_cast<uint32_t>(*rc::gen::inRange(0, 524288)),
            static_cast<float>(*rc::gen::inRange(-400, 1251)) / 10.0f);

        char out[512] = {0};
        const int len = serializeTelemetryJson(data, out, sizeof(out));
        RC_ASSERT(len > 0);

        JsonDocument doc;
        auto err = deserializeJson(doc, out);
        RC_ASSERT(!err);
        RC_ASSERT(doc["ts"].as<uint32_t>() == 0);
      });
  TEST_ASSERT_TRUE(ok);
}
