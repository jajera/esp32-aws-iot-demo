#ifndef STATUS_LED_H
#define STATUS_LED_H

#include <Arduino.h>

class StatusLed {
 public:
  void begin();
  void loop();
  void flashTelemetrySent();

 private:
#if defined(ARDUINO_ESP32S3_DEV) || defined(CONFIG_IDF_TARGET_ESP32S3)
  bool initialized_ = false;
  bool active_ = false;
  uint32_t off_at_ms_ = 0;
#endif
};

#endif  // STATUS_LED_H
