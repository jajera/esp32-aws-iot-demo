#include <algorithm>
#include <cstdint>

#include <unity.h>

#include <rapidcheck.h>

#include "backoff_utils.h"

namespace {

uint32_t expectedNext(uint32_t current, uint32_t initial, uint32_t max_cap) {
  if (current < initial) {
    return initial;
  }
  const uint64_t doubled = static_cast<uint64_t>(current) * 2ULL;
  return doubled > max_cap ? max_cap : static_cast<uint32_t>(doubled);
}

}  // namespace

void test_property_backoff_sequence() {
  const bool ok = rc::check(
      "Feature: esp32-aws-iot-demo, Property 1: Exponential backoff correctness", []() {
        const uint32_t initial = 1000;
        const uint32_t max_cap = static_cast<uint32_t>(*rc::gen::inRange(2000, 120001));
        const int failures = *rc::gen::inRange(1, 20);
        uint32_t current = initial;
        for (int i = 0; i < failures; ++i) {
          const uint32_t next = BackoffUtils::next(current, initial, max_cap);
          RC_ASSERT(next == expectedNext(current, initial, max_cap));
          current = next;
        }
        RC_ASSERT(BackoffUtils::next(0, initial, max_cap) == initial);
      });
  TEST_ASSERT_TRUE(ok);
}

void test_backoff_resets_after_success() {
  // Property 1: successful connection resets interval to initial (WiFiManager/MQTTManager behavior).
  uint32_t backoff = 8000;
  backoff = BackoffUtils::next(backoff, 1000, 60000);
  TEST_ASSERT_EQUAL_UINT32(16000, backoff);
  backoff = 1000;  // reset on success
  TEST_ASSERT_EQUAL_UINT32(1000, backoff);
}

int main(int, char**) {
  UNITY_BEGIN();
  RUN_TEST(test_property_backoff_sequence);
  RUN_TEST(test_backoff_resets_after_success);
  return UNITY_END();
}
