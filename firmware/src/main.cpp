#if !__has_include("config.h")
#error "Missing firmware/include/config.h — run scripts/generate-headers.sh with WIFI_SSID, WIFI_PASSWORD, THING_NAME"
#endif

#if !__has_include("certs.h")
#error "Missing firmware/include/certs.h — run aws/provision.sh, then scripts/generate-headers.sh"
#endif

#include <Arduino.h>

#include "certs.h"
#include "config.h"
#include "event_publisher.h"
#include "logger.h"
#include "mqtt_manager.h"
#include "ntp_sync.h"
#include "status_led.h"
#include "telemetry_publisher.h"
#include "watchdog_supervisor.h"
#include "wifi_manager.h"

namespace {
WiFiManager wifi_manager;
NTPSync ntp_sync;
MQTTManager mqtt_manager;
TelemetryPublisher telemetry_publisher;
EventPublisher event_publisher;
WatchdogSupervisor watchdog;
StatusLed status_led;
bool last_wifi_connected = false;
}  // namespace

void setup() {
  Logger::begin(115200);
  Logger::log("main", "boot");

  watchdog.begin(30);
  watchdog.logResetReason();

  wifi_manager.begin(WIFI_SSID, WIFI_PASSWORD);
  ntp_sync.begin(NTP_SERVER);
  mqtt_manager.begin(AWS_IOT_ENDPOINT, THING_NAME, AWS_CERT_CA, AWS_CERT_CRT, AWS_CERT_PRIVATE);
  telemetry_publisher.begin(THING_NAME, PUBLISH_INTERVAL_SEC);
  telemetry_publisher.setStatusLed(&status_led);
  event_publisher.begin(THING_NAME);
  status_led.begin();
}

void loop() {
  watchdog.feed();

  const bool wifi_connected = wifi_manager.loop();
  if (!wifi_connected && last_wifi_connected && !ntp_sync.isSynced()) {
    ntp_sync.resetSync();
  }
  last_wifi_connected = wifi_connected;

  if (wifi_connected && !ntp_sync.isSynced()) {
    ntp_sync.loop();
  }

  const bool mqtt_connected = mqtt_manager.loop(wifi_connected);
  telemetry_publisher.loop(mqtt_manager, ntp_sync);
  event_publisher.loop(mqtt_manager, ntp_sync);

  if (wifi_connected && mqtt_connected) {
    watchdog.noteDualConnected();
  }
  watchdog.checkConnectivityTimeout(wifi_connected, mqtt_connected);
  status_led.loop();
  delay(10);
}
