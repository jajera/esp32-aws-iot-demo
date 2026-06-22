#include <cstdio>
#include <regex>
#include <string>

#include <unity.h>

#include <rapidcheck.h>

#include "log_format.h"

void test_property_log_format() {
  const bool ok = rc::check("Feature: esp32-aws-iot-demo, Property 7: Log message format", []() {
    const uint32_t ms = static_cast<uint32_t>(*rc::gen::inRange(0, 1000000));
    const std::string tag = "tag" + std::to_string(*rc::gen::inRange(1, 100));
    const std::string msg = "msg" + std::to_string(*rc::gen::inRange(1, 1000));
    char line[512];
    const int written = formatLogLine(line, sizeof(line), ms, tag.c_str(), msg.c_str());
    RC_ASSERT(written > 0);
    RC_ASSERT(static_cast<size_t>(written) < sizeof(line));
    const std::regex pattern(R"(^\[[0-9]+\]\[[^\]]+\] .+$)");
    RC_ASSERT(std::regex_match(std::string(line), pattern));
  });
  TEST_ASSERT_TRUE(ok);
}

int main(int, char**) {
  UNITY_BEGIN();
  RUN_TEST(test_property_log_format);
  return UNITY_END();
}
