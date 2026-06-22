#include <string>

#include <unity.h>

#include <rapidcheck.h>

#include "payload_codec.h"

namespace {
TelemetryData maxTelemetry(const std::string& id) {
  TelemetryData data {};
  data.device_id = id.c_str();
  data.ts = 2147483647u;
  data.rssi = -1;
  data.uptime_s = 4294967295u;
  data.heap_free = 524288u;
  data.chip_temp_c = 125.0f;
  copyField(data.chip_model, sizeof(data.chip_model), "ESP32-S3-WROOM");
  data.cpu_mhz = 240;
  data.flash_bytes = 16777216u;
  copyField(data.wifi_ssid, sizeof(data.wifi_ssid), "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");
  data.wifi_status = 127;
  data.wifi_channel = 14;
  copyField(data.wifi_ip, sizeof(data.wifi_ip), "255.255.255.255");
  copyField(data.wifi_gateway, sizeof(data.wifi_gateway), "255.255.255.255");
  copyField(data.wifi_dns, sizeof(data.wifi_dns), "255.255.255.255");
  data.clock_offset_ms = 2147483647;
  return data;
}
}  // namespace

void test_property_payload_size_limits() {
  const bool ok = rc::check("Feature: esp32-aws-iot-demo, Property 5: Payload size constraint", []() {
    const std::string telemetry_id(*rc::gen::inRange(1, 129), 'x');

    char telemetry[512] = {0};
    const TelemetryData telemetry_data = maxTelemetry(telemetry_id);
    const int tlen = serializeTelemetryJson(telemetry_data, telemetry, sizeof(telemetry));
    RC_ASSERT(tlen > 0);
    RC_ASSERT(tlen <= 512);

    const std::string event_id(*rc::gen::inRange(1, 65), 'x');
    char event[256] = {0};
    const EventData event_data{event_id.c_str(), 2147483647u};
    const int elen = serializeEventJson(event_data, event, sizeof(event));
    RC_ASSERT(elen > 0);
    RC_ASSERT(elen <= 128);
  });
  TEST_ASSERT_TRUE(ok);
}
