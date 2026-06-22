#include <math.h>

#include <string>

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
  data.clock_offset_ms = 125;
  return data;
}
}  // namespace

void test_property_payload_size_limits();
void test_property_timestamp_fallback();

void test_property_telemetry_round_trip() {
  const bool ok = rc::check(
      "Feature: esp32-aws-iot-demo, Property 2: Telemetry payload serialization round-trip", []() {
        const int id_num = *rc::gen::inRange(1, 1000000);
        const std::string id = "thing-" + std::to_string(id_num);
        const TelemetryData data = sampleTelemetry(
            id.c_str(),
            static_cast<uint32_t>(*rc::gen::inRange(0, 2147483647)),
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
        RC_ASSERT(doc["device_id"].as<const char*>() == id);
        RC_ASSERT(doc["ts"].as<uint32_t>() == data.ts);
        RC_ASSERT(std::string(doc["type"].as<const char*>()) == "connectivity");
        RC_ASSERT(doc["rssi"].as<int>() == data.rssi);
        RC_ASSERT(doc["uptime_s"].as<uint32_t>() == data.uptime_s);
        RC_ASSERT(doc["heap_free"].as<uint32_t>() == data.heap_free);
        RC_ASSERT(fabs(doc["chip_temp_c"].as<float>() - data.chip_temp_c) < 0.001f);
        RC_ASSERT(std::string(doc["chip_model"].as<const char*>()) == "ESP32-S3");
        RC_ASSERT(doc["cpu_mhz"].as<uint16_t>() == 240);
        RC_ASSERT(doc["flash_bytes"].as<uint32_t>() == 16777216);
        RC_ASSERT(doc["clock_offset_ms"].as<int32_t>() == 125);
      });
  TEST_ASSERT_TRUE(ok);
}

int main(int, char**) {
  UNITY_BEGIN();
  RUN_TEST(test_property_telemetry_round_trip);
  RUN_TEST(test_property_payload_size_limits);
  RUN_TEST(test_property_timestamp_fallback);
  return UNITY_END();
}
