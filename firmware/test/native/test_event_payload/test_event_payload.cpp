#include <string>

#include <unity.h>

#include <ArduinoJson.h>
#include <rapidcheck.h>

#include "payload_codec.h"

void test_property_event_round_trip() {
  const bool ok = rc::check(
      "Feature: esp32-aws-iot-demo, Property 3: Event payload serialization round-trip", []() {
        const std::string id = "thing-" + std::to_string(*rc::gen::inRange(1, 1000000));
        const EventData data{
            id.c_str(),
            static_cast<uint32_t>(*rc::gen::inRange(0, 2147483647)),
        };

        char out[128] = {0};
        const int len = serializeEventJson(data, out, sizeof(out));
        RC_ASSERT(len > 0);

        JsonDocument doc;
        auto err = deserializeJson(doc, out);
        RC_ASSERT(!err);
        RC_ASSERT(std::string(doc["device_id"].as<const char*>()) == id);
        RC_ASSERT(doc["ts"].as<uint32_t>() == data.ts);
        RC_ASSERT(std::string(doc["type"].as<const char*>()) == "button");
        RC_ASSERT(std::string(doc["event"].as<const char*>()) == "press");
      });
  TEST_ASSERT_TRUE(ok);
}

int main(int, char**) {
  UNITY_BEGIN();
  RUN_TEST(test_property_event_round_trip);
  return UNITY_END();
}
