#include <unity.h>

#include <rapidcheck.h>

#include "connectivity_timeout_utils.h"

void test_property_connectivity_timeout() {
  const bool ok = rc::check(
      "Feature: esp32-aws-iot-demo, Property 8: Connectivity timeout triggers reset", []() {
        const uint32_t timeout_ms = 5UL * 60UL * 1000UL;
        const uint32_t last_dual = static_cast<uint32_t>(*rc::gen::inRange(0, 100000));
        const uint32_t delta = static_cast<uint32_t>(*rc::gen::inRange(0, 600001));
        const uint32_t now = last_dual + delta;

        const bool should_reset = ConnectivityTimeoutUtils::shouldReset(now, last_dual, timeout_ms);
        RC_ASSERT(should_reset == (delta >= timeout_ms));
      });
  TEST_ASSERT_TRUE(ok);
}

int main(int, char**) {
  UNITY_BEGIN();
  RUN_TEST(test_property_connectivity_timeout);
  return UNITY_END();
}
