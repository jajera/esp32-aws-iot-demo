# Implementation Plan — Phase 1: Device + IoT Baseline

> **Status:** ACTIVE — implement now.

## Overview

This plan implements the ESP32 AWS IoT Demo firmware and AWS provisioning artifacts. The approach builds from the ground up: project scaffold and configuration templates first, then core components (Logger, WiFiManager, NTPSync), followed by MQTT connectivity, publishers, watchdog supervision, the main orchestration loop, AWS provisioning scripts, documentation, and finally native property-based tests. Each task builds incrementally on prior work so there is no orphaned code.

**Master index:** [README.md](../README.md)

## Project Phases

| Phase | Scope | Spec location |
|-------|-------|---------------|
| 1 | Device + IoT baseline (this document) | `phase-1/` |
| 2 | Serverless ingest | [phase-2/tasks.md](../phase-2/tasks.md) |
| 3 | API + Amplify dashboard | [phase-3/tasks.md](../phase-3/tasks.md) |

## Tasks

- [x] 1. Set up PlatformIO project structure and configuration templates
  - [x] 1.1 Create PlatformIO project scaffold
    - Create `firmware/platformio.ini` targeting `esp32dev` board with Arduino framework, `monitor_speed = 115200`, lib_deps for `256dpi/MQTT @ ^2.5.3` and `bblanchon/ArduinoJson @ ^7.0.0`, and `-I include` build flag
    - Create directory structure: `firmware/src/`, `firmware/include/`, `firmware/test/native/`, `firmware/test/embedded/`, `aws/rules/`, `docs/`
    - _Requirements: 12.1, 12.2_

  - [x] 1.2 Create configuration and certificate example headers
    - Create `firmware/include/config.example.h` with placeholder macros: `WIFI_SSID`, `WIFI_PASSWORD`, `AWS_IOT_ENDPOINT`, `THING_NAME`, `PUBLISH_INTERVAL_SEC` (default 60), `NTP_SERVER` (default `pool.ntp.org`), and a compile-time range check (`#error` if `PUBLISH_INTERVAL_SEC` < 10 or > 3600)
    - Create `firmware/include/certs.example.h` with placeholder `AWS_CERT_CA`, `AWS_CERT_CRT`, `AWS_CERT_PRIVATE` as C string literals with escaped newlines
    - _Requirements: 11.1, 11.2, 4.6_

  - [x] 1.3 Create .gitignore for secrets and build artifacts
    - Add entries for `firmware/include/config.h`, `firmware/include/certs.h`, `firmware/**/*.pem`, and PlatformIO build directories (`.pio/`)
    - _Requirements: 11.3_

- [x] 2. Implement Logger component
  - [x] 2.1 Create Logger header
    - Create `firmware/src/logger.h` with `Logger::begin(baud)`, `Logger::log(tag, message)`, `Logger::logf(tag, format, ...)` functions
    - Output format: `[<millis>][<tag>] <message>` at 115200 8N1
    - Implement as header-only with inline functions for simplicity
    - _Requirements: 6.1, 6.2_

  - [x] 2.2 Write property test for log message format
    - **Property 7: Log message format**
    - **Validates: Requirements 6.1, 6.2**

- [x] 3. Implement WiFiManager component
  - [x] 3.1 Create WiFiManager header and implementation
    - Create `firmware/src/wifi_manager.h` with class declaration: `begin(ssid, password)`, `loop() → bool`, `isConnected()`, `getRSSI()`, `getIP()`
    - Create `firmware/src/wifi_manager.cpp` implementing:
      - Wi-Fi STA mode connection with 30s boot timeout
      - Exponential backoff: initial 1s, ×2, max 60s, reset on success
      - Log IP on connect, log event on disconnect
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 6.3, 6.4_

  - [x] 3.2 Write property test for exponential backoff (WiFi)
    - **Property 1: Exponential backoff correctness**
    - **Validates: Requirements 1.2, 3.4**

- [x] 4. Implement NTPSync component
  - [x] 4.1 Create NTPSync header and implementation
    - Create `firmware/src/ntp_sync.h` with class declaration: `begin(server)`, `loop() → bool`, `isSynced()`, `getEpoch()`, `resetSync()`
    - Create `firmware/src/ntp_sync.cpp` implementing:
      - `configTime()` SNTP synchronization
      - 30s timeout with ≤5s polling interval
      - Log ISO 8601 UTC time on success, warning on timeout
      - `resetSync()` called on Wi-Fi loss if time not yet synced
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6_

- [x] 5. Implement MQTTManager component
  - [x] 5.1 Create MQTTManager header and implementation
    - Create `firmware/src/mqtt_manager.h` with class declaration: `begin(endpoint, thingName, certs)`, `loop() → bool`, `isConnected()`, `publish(topic, payload, qos) → bool`
    - Create `firmware/src/mqtt_manager.cpp` implementing:
      - WiFiClientSecure with embedded CA, cert, and private key
      - 256dpi/MQTT client with keep-alive 60s, clean session, buffer sized for 256-byte payload
      - Exponential backoff: initial 1s, ×2, max 120s, reset on success
      - 30s connect timeout per attempt
      - 10s QoS 1 publish acknowledgement timeout
      - Log connect/disconnect state transitions and error codes
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7, 4.2, 4.8, 6.5, 6.8_

- [x] 6. Checkpoint - Core connectivity components
  - Core connectivity tests pass (`test_backoff`, `test_logger_format`, `test_connectivity_timeout`) and `pio run -d firmware -e esp32dev` succeeds.

- [x] 7. Implement TelemetryPublisher component
  - [x] 7.1 Create TelemetryPublisher header and implementation
    - Create `firmware/src/telemetry_publisher.h` with class declaration: `begin(interval)`, `loop(mqttMgr, ntpSync)`, `buildPayload(buffer, size) → int`
    - Create `firmware/src/telemetry_publisher.cpp` implementing:
      - `buildPayload()` as a pure function: serializes device_id, ts, type="connectivity", rssi, uptime_s, heap_free, chip_temp_c into JSON using ArduinoJson StaticJsonDocument
      - Interval check with ±5s tolerance
      - Publish via MQTTManager at QoS 1
      - ts=0 fallback when NTP unavailable
      - Log topic and payload size on publish; log warning when MQTT unavailable
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.7, 6.6, 13.1, 13.3, 13.4, 13.5_

  - [ ]* 7.2 Write property test for telemetry payload round-trip
    - **Property 2: Telemetry payload serialization round-trip**
    - **Validates: Requirements 4.3, 4.4, 13.1, 13.3**

  - [ ]* 7.3 Write property test for payload size constraint (telemetry)
    - **Property 5: Payload size constraint (telemetry portion)**
    - **Validates: Requirements 13.5**

  - [ ]* 7.4 Write property test for timestamp fallback
    - **Property 6: Timestamp fallback when NTP unavailable**
    - **Validates: Requirements 13.4, 2.5**

  - [ ]* 7.5 Write property test for publish interval tolerance
    - **Property 9: Telemetry publish interval tolerance**
    - **Validates: Requirements 4.1**

- [x] 8. Implement EventPublisher component
  - [x] 8.1 Create EventPublisher header and implementation
    - Create `firmware/src/event_publisher.h` with class declaration: `begin()`, `loop(mqttMgr, ntpSync)`, `buildPayload(buffer, size) → int`, private `onFallingEdge()` ISR
    - Create `firmware/src/event_publisher.cpp` implementing:
      - GPIO0 configured as INPUT_PULLUP with falling-edge interrupt
      - `volatile bool pendingPress` flag set in ISR
      - 300ms debounce filter
      - `buildPayload()` as a pure function: serializes device_id, ts, type="button", event="press"
      - Publish within 500ms of accepted press; log "MQTT unavailable" and discard if disconnected
      - ts=0 fallback when NTP unavailable
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 6.7, 13.2, 13.3, 13.4, 13.5_

  - [ ]* 8.2 Write property test for event payload round-trip
    - **Property 3: Event payload serialization round-trip**
    - **Validates: Requirements 5.3, 13.2, 13.3**

  - [ ]* 8.3 Write property test for button debounce filter
    - **Property 4: Button debounce filter correctness**
    - **Validates: Requirements 5.1, 5.4, 5.6**

  - [ ]* 8.4 Write property test for payload size constraint (event)
    - **Property 5: Payload size constraint (event portion)**
    - **Validates: Requirements 13.5**

- [x] 9. Implement WatchdogSupervisor component
  - [x] 9.1 Create WatchdogSupervisor header and implementation
    - Create `firmware/src/watchdog_supervisor.h` with class declaration: `begin(timeoutSec)`, `feed()`, `noteDualConnected()`, `checkConnectivityTimeout(wifiOk, mqttOk)`
    - Create `firmware/src/watchdog_supervisor.cpp` implementing:
      - Hardware WDT enabled with 30s timeout via `esp_task_wdt` API
      - `feed()` resets WDT (called every loop iteration, satisfies ≤15s requirement)
      - Track last dual-connectivity timestamp; `ESP.restart()` after 5 continuous minutes without both Wi-Fi and MQTT connected
      - Log critical message before reset; log reset reason on boot via `esp_reset_reason()`
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5_

  - [ ]* 9.2 Write property test for connectivity timeout
    - **Property 8: Connectivity timeout triggers reset**
    - **Validates: Requirements 10.4**

- [x] 10. Implement Main orchestration loop
  - [x] 10.1 Create main.cpp with setup() and loop()
    - Create `firmware/src/main.cpp` implementing:
      - Build guards: `#if !__has_include("config.h")` and `#if !__has_include("certs.h")` with descriptive `#error` messages
      - `setup()`: Logger init, log reset reason, WiFiManager begin, NTPSync begin, MQTTManager begin, TelemetryPublisher begin, EventPublisher begin, WatchdogSupervisor begin
      - `loop()`: feed watchdog → WiFiManager loop → NTPSync loop (resetSync on Wi-Fi loss) → MQTTManager loop → TelemetryPublisher loop → EventPublisher loop → WatchdogSupervisor noteDualConnected/checkConnectivityTimeout
      - State machine transitions as per design: BOOT → WIFI_CONNECTING → NTP_SYNC → MQTT_CONNECTING → OPERATIONAL
    - _Requirements: 11.4, 11.5, 10.2, 10.3, 12.7_

- [x] 11. Checkpoint - Complete firmware
  - Core firmware tests pass (`test_backoff`, `test_logger_format`, `test_debounce`, `test_event_payload`, `test_publish_interval`, `test_connectivity_timeout`) and `pio run -d firmware -e esp32dev` succeeds.

- [x] 12. Create AWS provisioning scripts and IoT Rule definitions
  - [x] 12.1 Create AWS provisioning script
    - Create `aws/provision.sh` with AWS CLI commands in dependency order:
      1. Create IoT Thing
      2. Create and activate device certificate; download cert and private key
      3. Create IoT Policy (iot:Connect with client ID = Thing_Name, iot:Publish to telemetry and events topics only)
      4. Attach policy to certificate
      5. Attach certificate to Thing
      6. Retrieve account-specific IoT endpoint
      7. Download AmazonRootCA1.pem
      8. Create IAM role with iot.amazonaws.com trust and CloudWatch Logs permissions
      9. Create log groups and deploy IoT Rules
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8_

  - [x] 12.2 Create IoT Rule JSON definitions
    - Create `aws/rules/telemetry_rule.json` with SQL `SELECT * FROM 'devices/+/telemetry'`, CloudWatch Logs action to `/aws/iot/esp32-demo/telemetry` (7-day retention), error action to `/aws/iot/esp32-demo/errors` (14-day retention)
    - Create `aws/rules/events_rule.json` with SQL `SELECT * FROM 'devices/+/events'`, CloudWatch Logs action to `/aws/iot/esp32-demo/events` (7-day retention), error action to `/aws/iot/esp32-demo/errors` (14-day retention)
    - _Requirements: 8.1, 8.2, 8.3, 8.4, 9.1, 9.2, 9.3, 9.4, 9.5_

- [x] 13. Create documentation
  - [x] 13.1 Create docs/CERTIFICATES.md
    - Step-by-step instructions for downloading certificates from AWS IoT console or CLI and copying PEM contents into `firmware/include/certs.h` macro format
    - _Requirements: 11.6_

  - [x] 13.2 Create docs/PAYLOAD.md
    - Document JSON contract for Telemetry_Payload and Event_Payload: field names, types, valid ranges, examples
    - Document base schema fields (device_id, ts, type) as stable across all telemetry types
    - Describe convention for adding type-specific fields
    - _Requirements: 12.4, 13.1, 13.2, 14.5_

  - [x] 13.3 Create docs/ARCHITECTURE.md
    - Document logical architecture from device to cloud (Firmware, Wi-Fi, MQTT, AWS IoT Core, IoT Rules, CloudWatch Logs)
    - Include "Future Phases" section documenting Lambda processing, DynamoDB storage, and web dashboard extension points
    - _Requirements: 12.5, 14.4_

  - [x] 13.4 Update README.md with zero-to-first-message guide
    - Prerequisites (PlatformIO CLI, AWS CLI, AWS account)
    - Cloning, certificate setup, configuration steps
    - Flashing with `pio run -t upload`
    - Verifying first message in AWS IoT MQTT test client on `devices/+/telemetry`
    - _Requirements: 12.3_

- [x] 14. Checkpoint - Complete project with docs and provisioning
  - Provisioning artifacts (`aws/provision.sh`, `aws/rules/*.json`) and docs (`README.md`, `docs/CERTIFICATES.md`, `docs/PAYLOAD.md`, `docs/ARCHITECTURE.md`) are aligned with Phase 1 requirements and Kiro phase model.

- [x] 15. Set up native test framework and implement property-based tests
  - [x] 15.1 Configure PlatformIO native test environment with Rapidcheck
    - Add `[env:native]` section to `firmware/platformio.ini` with `platform = native` and Rapidcheck lib dependency
    - Create test directory structure under `firmware/test/native/` with subdirectories for each test suite
    - _Requirements: 12.1_

  - [x] 15.2 Implement backoff property test
    - Create `firmware/test/native/test_backoff/test_backoff.cpp`
    - Extract backoff calculation as pure function testable on host
    - Generate random failure counts (1–20), random max caps; verify each interval = min(prev × 2, max) and reset on success
    - Minimum 100 iterations; tag: `Feature: esp32-aws-iot-demo, Property 1: Exponential backoff correctness`
    - _Requirements: 1.2, 3.4_

  - [x] 15.3 Implement telemetry payload round-trip property test
    - Create `firmware/test/native/test_telemetry_payload/test_telemetry_payload.cpp`
    - Generate random device_id (1–128 chars), random valid metrics within defined ranges
    - Verify serialized JSON parses back to identical values with correct types and no extra fields
    - Minimum 100 iterations; tag: `Feature: esp32-aws-iot-demo, Property 2: Telemetry payload serialization round-trip`
    - _Requirements: 4.3, 4.4, 13.1, 13.3_

  - [x] 15.4 Implement event payload round-trip property test
    - Create `firmware/test/native/test_event_payload/test_event_payload.cpp`
    - Generate random device_id (1–128 chars), random ts values
    - Verify serialized JSON contains exactly device_id, ts, type="button", event="press" with no extra fields
    - Minimum 100 iterations; tag: `Feature: esp32-aws-iot-demo, Property 3: Event payload serialization round-trip`
    - _Requirements: 5.3, 13.2, 13.3_

  - [x] 15.5 Implement debounce filter property test
    - Create `firmware/test/native/test_debounce/test_debounce.cpp`
    - Generate random sequences of timestamps (0–10000ms range)
    - Verify accepted presses are at least 300ms apart; rejected presses have no side effects
    - Minimum 100 iterations; tag: `Feature: esp32-aws-iot-demo, Property 4: Button debounce filter correctness`
    - _Requirements: 5.1, 5.4, 5.6_

  - [x] 15.6 Implement payload size constraint property test
    - Create `firmware/test/native/test_telemetry_payload/test_payload_size.cpp`
    - Generate worst-case device_id lengths (up to 128 chars) and max numeric values
    - Verify telemetry JSON ≤ 256 bytes, event JSON ≤ 128 bytes
    - Minimum 100 iterations; tag: `Feature: esp32-aws-iot-demo, Property 5: Payload size constraint`
    - _Requirements: 13.5_

  - [x] 15.7 Implement timestamp fallback property test
    - Create `firmware/test/native/test_telemetry_payload/test_timestamp_fallback.cpp`
    - Generate random metrics with NTP synced flag = false
    - Verify ts field is exactly 0 in serialized output
    - Minimum 100 iterations; tag: `Feature: esp32-aws-iot-demo, Property 6: Timestamp fallback when NTP unavailable`
    - _Requirements: 13.4, 2.5_

  - [x] 15.8 Implement log format property test
    - Create `firmware/test/native/test_logger_format/test_logger_format.cpp`
    - Generate random tags (alphanumeric, non-empty) and random messages
    - Verify output matches pattern `[<millis>][<tag>] <message>` where millis is non-negative integer
    - Minimum 100 iterations; tag: `Feature: esp32-aws-iot-demo, Property 7: Log message format`
    - _Requirements: 6.1, 6.2_

  - [x] 15.9 Implement connectivity timeout property test
    - Create `firmware/test/native/test_connectivity_timeout/test_connectivity_timeout.cpp`
    - Generate random state change sequences (Wi-Fi up/down, MQTT up/down) with timestamps
    - Verify reset is signaled after 5 continuous minutes without simultaneous dual connectivity
    - Minimum 100 iterations; tag: `Feature: esp32-aws-iot-demo, Property 8: Connectivity timeout triggers reset`
    - _Requirements: 10.4_

  - [x] 15.10 Implement publish interval tolerance property test
    - Create `firmware/test/native/test_publish_interval/test_publish_interval.cpp`
    - Generate random intervals (10–3600s), simulate loop timing
    - Verify elapsed time between publishes is within configured interval ±5s
    - Minimum 100 iterations; tag: `Feature: esp32-aws-iot-demo, Property 9: Telemetry publish interval tolerance`
    - _Requirements: 4.1_

- [x] 16. Final checkpoint - All tests and verification
  - `pio test -d firmware -e native` passes across all suites and `pio run -d firmware -e esp32dev` succeeds.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- Unit tests validate specific examples and edge cases
- The firmware uses C++ with Arduino framework on PlatformIO; all code examples use C++
- Rapidcheck runs on the native (host) platform, not on the ESP32 device
- Pure functions (`buildPayload`, backoff calculation, debounce filter) are extracted for testability on host without hardware dependencies
- AWS provisioning is scripted with AWS CLI for reproducibility

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2", "1.3"] },
    { "id": 1, "tasks": ["2.1"] },
    { "id": 2, "tasks": ["2.2", "3.1", "4.1"] },
    { "id": 3, "tasks": ["3.2", "5.1"] },
    { "id": 4, "tasks": ["7.1", "8.1", "9.1"] },
    { "id": 5, "tasks": ["7.2", "7.3", "7.4", "7.5", "8.2", "8.3", "8.4", "9.2"] },
    { "id": 6, "tasks": ["10.1"] },
    { "id": 7, "tasks": ["12.1", "12.2", "13.1", "13.2", "13.3", "13.4"] },
    { "id": 8, "tasks": ["15.1"] },
    { "id": 9, "tasks": ["15.2", "15.3", "15.4", "15.5", "15.6", "15.7", "15.8", "15.9", "15.10"] }
  ]
}
```
