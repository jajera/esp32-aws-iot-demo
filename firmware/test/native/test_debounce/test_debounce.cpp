#include <unity.h>

#include <rapidcheck.h>

#include "debounce_utils.h"

void test_property_debounce_filter() {
  const bool ok = rc::check(
      "Feature: esp32-aws-iot-demo, Property 4: Button debounce filter correctness", []() {
        const uint32_t gap_ms = 300;
        uint32_t last_accepted = 0;
        for (int i = 0; i < 100; ++i) {
          const uint32_t t = static_cast<uint32_t>(*rc::gen::inRange(0, 10001));
          const bool accepted = DebounceUtils::shouldAcceptPress(t, last_accepted, gap_ms);
          if (accepted) {
            RC_ASSERT((t - last_accepted) >= gap_ms);
            last_accepted = t;
          } else {
            RC_ASSERT((t - last_accepted) < gap_ms);
          }
        }
      });
  TEST_ASSERT_TRUE(ok);
}

int main(int, char**) {
  UNITY_BEGIN();
  RUN_TEST(test_property_debounce_filter);
  return UNITY_END();
}
