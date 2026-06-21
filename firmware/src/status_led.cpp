#include "status_led.h"

#if defined(ARDUINO_ESP32S3_DEV) || defined(CONFIG_IDF_TARGET_ESP32S3)
#include "esp32-hal-rgb-led.h"

// Onboard WS2812 on ESP32-S3-DevKitC-1 (Arduino core default GPIO48).
// v1.1 boards may use GPIO38 — override with -DPIN_NEOPIXEL=38 in platformio.ini.
namespace {
constexpr uint32_t kFlashMs = 800;
constexpr uint8_t kBlueLevel = RGB_BRIGHTNESS / 2;

void writeRgb(uint8_t red, uint8_t green, uint8_t blue) {
#ifdef RGB_BUILTIN
  neopixelWrite(RGB_BUILTIN, red, green, blue);
#else
  (void)red;
  (void)green;
  (void)blue;
#endif
}
}  // namespace
#endif

void StatusLed::begin() {
#if defined(ARDUINO_ESP32S3_DEV) || defined(CONFIG_IDF_TARGET_ESP32S3)
#ifdef RGB_BUILTIN
  writeRgb(0, 0, 0);
  initialized_ = true;
#endif
#endif
}

void StatusLed::loop() {
#if defined(ARDUINO_ESP32S3_DEV) || defined(CONFIG_IDF_TARGET_ESP32S3)
  if (!initialized_ || !active_) {
    return;
  }
  if (millis() >= off_at_ms_) {
    writeRgb(0, 0, 0);
    active_ = false;
  }
#endif
}

void StatusLed::flashTelemetrySent() {
#if defined(ARDUINO_ESP32S3_DEV) || defined(CONFIG_IDF_TARGET_ESP32S3)
  if (!initialized_) {
    return;
  }
  writeRgb(0, 0, kBlueLevel);
  active_ = true;
  off_at_ms_ = millis() + kFlashMs;
#endif
}
