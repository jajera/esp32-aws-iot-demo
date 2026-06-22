#include <unity.h>

#include <rapidcheck.h>

#include "interval_utils.h"

void test_property_publish_interval_tolerance() {
  const bool ok = rc::check(
      "Feature: esp32-aws-iot-demo, Property 9: Telemetry publish interval tolerance", []() {
        const uint32_t interval_sec = static_cast<uint32_t>(*rc::gen::inRange(10, 3601));
        const uint32_t elapsed_ms = static_cast<uint32_t>(*rc::gen::inRange(0, 4000000));
        const bool within = IntervalUtils::withinTolerance(elapsed_ms, interval_sec, 5);

        const int64_t target = static_cast<int64_t>(interval_sec) * 1000LL;
        const bool expected = elapsed_ms >= (target - 5000) && elapsed_ms <= (target + 5000);
        RC_ASSERT(within == expected);
      });
  TEST_ASSERT_TRUE(ok);
}

int main(int, char**) {
  UNITY_BEGIN();
  RUN_TEST(test_property_publish_interval_tolerance);
  return UNITY_END();
}
