# Design Document — Phase 1: Device + IoT Baseline

> **Status:** ACTIVE — implement now.

## Overview

This design describes the firmware architecture and AWS cloud integration for the ESP32 AWS IoT Demo. The system connects an IdeaSpark esp32-c board (PlatformIO `esp32dev` profile) to AWS IoT Core over MQTT with mutual TLS, publishing periodic connectivity telemetry and one-shot button events as structured JSON payloads. AWS IoT Rules route messages to CloudWatch Logs for verification.

The firmware follows a single-threaded cooperative loop architecture on the Arduino framework, managed by PlatformIO under `firmware/`. Components are organized as discrete modules with clear responsibilities: Wi-Fi management, NTP synchronization, MQTT client management, telemetry collection/publishing, button event detection/publishing, watchdog supervision, and serial logging. GPIO0 (BOOT button) is configured as `INPUT_PULLUP`; event detection uses falling-edge interrupts after normal boot (GPIO0 held low during reset enters the UART bootloader).

**Master index:** [README.md](../README.md)

## Project Phases

| Phase | Scope | Spec location |
|-------|-------|---------------|
| 1 | Device + IoT baseline (this document) | `phase-1/` |
| 2 | Serverless ingest | [phase-2/design.md](../phase-2/design.md) |
| 3 | API + Amplify dashboard | [phase-3/design.md](../phase-3/design.md) |

**Key Library Choices:**

- **MQTT**: [`256dpi/MQTT`](https://github.com/256dpi/arduino-mqtt) (v2.5.3) — supports QoS 1 publish, configurable buffer sizes, ESP32-compatible. Chosen over PubSubClient which only supports QoS 0 publish.
- **TLS**: `WiFiClientSecure` (built into ESP32 Arduino core) — mutual TLS 1.2+ with embedded PEM certificates; keep-alive 60s configured on the MQTT client.
- **NTP**: `configTime()` from ESP32 Arduino core — SNTP synchronization.
- **Watchdog**: `esp_task_wdt` API from ESP-IDF (exposed in Arduino core).
- **JSON**: `ArduinoJson` (v7) — efficient JSON serialization with compile-time size checks.

## Architecture

### System Architecture (Device to Cloud)

```mermaid
graph LR
    subgraph ESP32["esp32-c"]
        FW[Firmware Main Loop]
        WIFI[Wi-Fi Manager]
        NTP_M[NTP Sync]
        MQTT_M[MQTT Manager]
        TELEM[Telemetry Publisher]
        BTN[Button/Event Publisher]
        WDT[Watchdog Supervisor]
        LOG[Serial Logger]
    end

    subgraph AWS["AWS Cloud"]
        IOT[AWS IoT Core<br/>MQTT Broker]
        RULE_T[IoT Rule:<br/>esp32_demo_telemetry_rule]
        RULE_E[IoT Rule:<br/>esp32_demo_events_rule]
        CW_T[CloudWatch Logs<br/>/aws/iot/esp32-demo/telemetry]
        CW_E[CloudWatch Logs<br/>/aws/iot/esp32-demo/events]
        CW_ERR[CloudWatch Logs<br/>/aws/iot/esp32-demo/errors]
    end

    FW --> WIFI
    FW --> NTP_M
    FW --> MQTT_M
    FW --> TELEM
    FW --> BTN
    FW --> WDT
    FW --> LOG

    MQTT_M -->|"mTLS / MQTT 3.1.1"| IOT
    IOT --> RULE_T
    IOT --> RULE_E
    RULE_T --> CW_T
    RULE_E --> CW_E
    RULE_T -.->|"Error Action"| CW_ERR
    RULE_E -.->|"Error Action"| CW_ERR
```

### Firmware State Machine

```mermaid
stateDiagram-v2
    [*] --> BOOT
    BOOT --> WIFI_CONNECTING: Serial init + WDT enabled
    WIFI_CONNECTING --> NTP_SYNC: Wi-Fi connected
    WIFI_CONNECTING --> WIFI_CONNECTING: Backoff retry (1s→60s, log on 30s boot timeout)
    NTP_SYNC --> MQTT_CONNECTING: NTP done (success or 30s timeout, poll ≤5s)
    NTP_SYNC --> NTP_SYNC: Poll SNTP status
    WIFI_CONNECTING --> NTP_SYNC: Wi-Fi reconnected and time not synced
    MQTT_CONNECTING --> OPERATIONAL: MQTT connected
    MQTT_CONNECTING --> MQTT_CONNECTING: Backoff retry (1s→120s)
    OPERATIONAL --> WIFI_CONNECTING: Wi-Fi lost
    OPERATIONAL --> MQTT_CONNECTING: MQTT disconnected
    MQTT_CONNECTING --> WIFI_CONNECTING: Wi-Fi lost during MQTT connect

    note right of OPERATIONAL
        Telemetry every Publish_Interval (±5s)
        Button events on debounced press
        WDT fed every loop iteration (≤15s)
    end note

    note right of BOOT
        Log reset reason
        Init serial 115200
        Enable HW WDT 30s
    end note
```

## Components and Interfaces

### Component Diagram

```mermaid
classDiagram
    class Main {
        +setup()
        +loop()
    }
    class WiFiManager {
        -State state
        -uint32_t backoffMs
        -uint32_t lastAttemptMs
        -uint32_t bootStartMs
        +begin(ssid, password)
        +loop() bool
        +isConnected() bool
        +getRSSI() int8_t
        +getIP() String
    }
    class NTPSync {
        -bool synchronized
        -uint32_t startMs
        -uint32_t lastPollMs
        +begin(server)
        +loop() bool
        +isSynced() bool
        +getEpoch() uint32_t
        +resetSync()
    }
    class MQTTManager {
        -MQTTClient client
        -WiFiClientSecure secureClient
        -State state
        -uint32_t backoffMs
        -uint32_t lastAttemptMs
        -uint32_t connectStartMs
        +begin(endpoint, thingName, certs)
        +loop() bool
        +isConnected() bool
        +publish(topic, payload, qos) bool
    }
    class TelemetryPublisher {
        -uint32_t lastPublishMs
        -uint16_t intervalSec
        +begin(interval)
        +loop(mqttMgr, ntpSync)
        +buildPayload(buffer, size) int
    }
    class EventPublisher {
        -volatile bool pendingPress
        -uint32_t lastPressMs
        +begin() attaches GPIO0 INPUT_PULLUP + ISR
        +loop(mqttMgr, ntpSync)
        +buildPayload(buffer, size) int
        -onFallingEdge() [ISR]
    }
    class WatchdogSupervisor {
        -uint32_t lastDualConnectMs
        -bool everDualConnected
        +begin(timeoutSec)
        +feed()
        +noteDualConnected()
        +checkConnectivityTimeout(wifiOk, mqttOk)
    }
    class Logger {
        +begin(baud)
        +log(tag, message)
        +logf(tag, format, ...)
    }

    Main --> WiFiManager
    Main --> NTPSync
    Main --> MQTTManager
    Main --> TelemetryPublisher
    Main --> EventPublisher
    Main --> WatchdogSupervisor
    Main --> Logger
    MQTTManager --> WiFiManager : checks connectivity
    TelemetryPublisher --> MQTTManager : publishes via
    TelemetryPublisher --> NTPSync : reads timestamp
    EventPublisher --> MQTTManager : publishes via
    EventPublisher --> NTPSync : reads timestamp
```

### Component Responsibilities

| Component | File | Responsibility |
|-----------|------|----------------|
| Main | `firmware/src/main.cpp` | Arduino `setup()`/`loop()`, orchestrates all components, includes build guards |
| WiFiManager | `firmware/src/wifi_manager.cpp/.h` | Wi-Fi connection (30s boot timeout), reconnection with 1s→60s exponential backoff |
| NTPSync | `firmware/src/ntp_sync.cpp/.h` | SNTP sync via `configTime()`, 30s timeout with ≤5s polling, re-sync after Wi-Fi reconnect if unsynced, ISO 8601 success log |
| MQTTManager | `firmware/src/mqtt_manager.cpp/.h` | TLS 1.2+ MQTT connection (keep-alive 60s, 30s connect timeout), 1s→120s backoff, QoS 1 publish API |
| TelemetryPublisher | `firmware/src/telemetry_publisher.cpp/.h` | Periodic metric collection, ±5s interval tolerance, telemetry JSON publishing |
| EventPublisher | `firmware/src/event_publisher.cpp/.h` | GPIO0 `INPUT_PULLUP`, falling-edge ISR, 300ms debounce, event JSON publishing |
| WatchdogSupervisor | `firmware/src/watchdog_supervisor.cpp/.h` | HW WDT (30s timeout, fed every loop), 5-min dual-connectivity timeout → `ESP.restart()` |
| Logger | `firmware/src/logger.h` | `[millis][tag] message` formatted serial output at 115200 8N1 |
| Config | `firmware/include/config.h` | Compile-time Wi-Fi (SSID ≤32, password 8–63), endpoint, thing name, interval, NTP server |
| Certs | `firmware/include/certs.h` | Compile-time PEM certificates as `AWS_CERT_CA`, `AWS_CERT_CRT`, `AWS_CERT_PRIVATE` macros |

### Inter-Component Communication

All communication is synchronous within the single-threaded `loop()`. The only asynchronous element is the GPIO0 ISR which sets a `volatile bool` flag consumed in the next loop iteration.

**Main loop execution order:**

1. Feed watchdog (satisfies ≤15s feed interval; continues during Wi-Fi/MQTT backoff)
2. `WiFiManager::loop()` — manage Wi-Fi state; on connect log IP, on disconnect log event
3. `NTPSync::loop()` — attempt sync when Wi-Fi up and unsynced; call `resetSync()` on Wi-Fi loss
4. `MQTTManager::loop()` — manage MQTT state, call `client.loop()`; log connect/disconnect transitions
5. `TelemetryPublisher::loop()` — publish when `Publish_Interval ±5s` elapsed and MQTT connected
6. `EventPublisher::loop()` — publish debounced press within 500ms; log `"MQTT unavailable"` and discard if disconnected
7. `WatchdogSupervisor::noteDualConnected()` when both Wi-Fi and MQTT up; `checkConnectivityTimeout()` triggers reset after 5 continuous minutes without dual connectivity

## Data Models

### Telemetry Payload Schema

```json
{
  "device_id": "esp32-c",
  "ts": 1700000000,
  "type": "connectivity",
  "rssi": -67,
  "uptime_s": 3600,
  "heap_free": 180000,
  "chip_temp_c": 42.5
}
```

| Field | Type | Constraints | Source |
|-------|------|-------------|--------|
| `device_id` | string | 1–128 chars, matches Thing_Name | `config.h` |
| `ts` | integer | Unix epoch seconds UTC, or 0 if NTP unavailable | `time()` or 0 |
| `type` | string | Enum: `"connectivity"` | Hardcoded |
| `rssi` | integer | -127 to 0 (dBm) | `WiFi.RSSI()` |
| `uptime_s` | integer | 0 to 4294967295 | `millis() / 1000` |
| `heap_free` | integer | 0 to 524288 (bytes) | `ESP.getFreeHeap()` |
| `chip_temp_c` | number | -40.0 to 125.0, 1 decimal | `temperatureRead()` (internal sensor; approximate) |

**Max serialized size: 256 bytes**

### Event Payload Schema

```json
{
  "device_id": "esp32-c",
  "ts": 1700000000,
  "type": "button",
  "event": "press"
}
```

| Field | Type | Constraints | Source |
|-------|------|-------------|--------|
| `device_id` | string | 1–128 chars, matches Thing_Name | `config.h` |
| `ts` | integer | Unix epoch seconds UTC, or 0 if NTP unavailable | `time()` or 0 |
| `type` | string | Enum: `"button"` | Hardcoded |
| `event` | string | Enum: `"press"` | Hardcoded |

**Max serialized size: 128 bytes**

### MQTT Topic Structure

| Purpose | Topic Pattern | Example |
|---------|---------------|---------|
| Telemetry | `devices/{Thing_Name}/telemetry` | `devices/esp32-c/telemetry` |
| Events | `devices/{Thing_Name}/events` | `devices/esp32-c/events` |

### Configuration Header (`firmware/include/config.h`)

Copied from `firmware/include/config.example.h` (excluded from version control):

```c
#ifndef CONFIG_H
#define CONFIG_H

#define WIFI_SSID       "your-ssid"          // max 32 characters
#define WIFI_PASSWORD   "your-password"      // 8–63 characters

#define AWS_IOT_ENDPOINT "xxxxxx-ats.iot.ap-southeast-2.amazonaws.com"
#define THING_NAME       "esp32-c"    // 1–128 characters; matches IoT Thing

#define PUBLISH_INTERVAL_SEC 60
#define NTP_SERVER           "pool.ntp.org"

#if PUBLISH_INTERVAL_SEC < 10 || PUBLISH_INTERVAL_SEC > 3600
  #error "PUBLISH_INTERVAL_SEC must be between 10 and 3600"
#endif

#endif
```

### Certificate Header (`firmware/include/certs.h`)

Copied from `firmware/include/certs.example.h` (excluded from version control). Macro names must match the example template:

```c
#ifndef CERTS_H
#define CERTS_H

static const char AWS_CERT_CA[] PROGMEM = R"EOF(
-----BEGIN CERTIFICATE-----
...AmazonRootCA1...
-----END CERTIFICATE-----
)EOF";

static const char AWS_CERT_CRT[] PROGMEM = R"EOF(
-----BEGIN CERTIFICATE-----
...device certificate...
-----END CERTIFICATE-----
)EOF";

static const char AWS_CERT_PRIVATE[] PROGMEM = R"EOF(
-----BEGIN RSA PRIVATE KEY-----
...private key...
-----END RSA PRIVATE KEY-----
)EOF";

#endif
```

### Build Guards (`firmware/src/main.cpp`)

Before including headers, the firmware checks that developer-local files exist:

```c
#if !__has_include("config.h")
  #error "Missing firmware/include/config.h — copy from config.example.h and fill in values"
#endif
#if !__has_include("certs.h")
  #error "Missing firmware/include/certs.h — copy from certs.example.h; see docs/CERTIFICATES.md"
#endif
```

### PlatformIO Configuration (`firmware/platformio.ini`)

```ini
[env:esp32dev]
platform = espressif32
board = esp32dev
framework = arduino
monitor_speed = 115200
build_flags =
  -I include
lib_deps =
  256dpi/MQTT @ ^2.5.3
  bblanchon/ArduinoJson @ ^7.0.0
```

MQTT client is configured with `setKeepAlive(60)`, `setCleanSession(true)`, and a publish buffer sized for the 256-byte telemetry payload.

### Repository Layout

```
esp32-aws-iot-demo/
├── firmware/
│   ├── platformio.ini
│   ├── include/
│   │   ├── config.example.h
│   │   ├── certs.example.h
│   │   ├── config.h          # gitignored, developer-local
│   │   └── certs.h           # gitignored, developer-local
│   ├── src/
│   │   ├── main.cpp
│   │   ├── wifi_manager.cpp/.h
│   │   ├── ntp_sync.cpp/.h
│   │   ├── mqtt_manager.cpp/.h
│   │   ├── telemetry_publisher.cpp/.h
│   │   ├── event_publisher.cpp/.h
│   │   ├── watchdog_supervisor.cpp/.h
│   │   └── logger.h
│   └── test/
│       ├── native/
│       └── embedded/
├── aws/
│   ├── provision.sh            # CLI commands in dependency order
│   └── rules/
│       ├── telemetry_rule.json
│       └── events_rule.json
├── docs/
│   ├── PAYLOAD.md
│   ├── ARCHITECTURE.md
│   └── CERTIFICATES.md
├── README.md
└── LICENSE
```

`.gitignore` excludes at minimum: `firmware/include/config.h`, `firmware/include/certs.h`, and `firmware/**/*.pem`.

### Exponential Backoff Parameters

| Context | Initial | Multiplier | Max | Connect Timeout | Reset Condition |
|---------|---------|-----------|-----|-----------------|-----------------|
| Wi-Fi reconnect | 1000 ms | ×2 | 60000 ms | 30s on boot | Successful connection |
| MQTT reconnect | 1000 ms | ×2 | 120000 ms | 30s per attempt | Successful connection |

### AWS IoT Rule Definitions

**Telemetry Rule (`esp32_demo_telemetry_rule`):**

- SQL: `SELECT * FROM 'devices/+/telemetry'`
- Action: CloudWatch Logs → `/aws/iot/esp32-demo/telemetry` (7-day retention)
- Error Action: CloudWatch Logs → `/aws/iot/esp32-demo/errors` (14-day retention)

**Events Rule (`esp32_demo_events_rule`):**

- SQL: `SELECT * FROM 'devices/+/events'`
- Action: CloudWatch Logs → `/aws/iot/esp32-demo/events` (7-day retention)
- Error Action: CloudWatch Logs → `/aws/iot/esp32-demo/errors` (14-day retention)

Provisioning scripts under `aws/` deploy rules separately and create log groups before rule creation.

### AWS Provisioning Workflow

Commands in `aws/provision.sh` follow this dependency order (Requirements 7–9):

1. Create IoT Thing (`THING_NAME`)
2. Create and activate Device_Certificate; download cert and private key
3. Create IoT_Policy granting only `iot:Connect` (client ID = Thing name) and `iot:Publish` to `devices/${iot:Connection.Thing.ThingName}/telemetry` and `.../events`
4. Attach policy to certificate
5. Attach certificate to Thing
6. Retrieve account-specific IoT endpoint (`aws iot describe-endpoint --endpoint-type iot:Data-ATS`)
7. Download `AmazonRootCA1.pem` from Amazon Trust Services
8. Create IAM role (`iot.amazonaws.com` trust) with `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents` on the three log groups
9. Create log groups and deploy `esp32_demo_telemetry_rule` and `esp32_demo_events_rule`

Certificate PEM contents are copied into `firmware/include/certs.h` per `docs/CERTIFICATES.md`.

### IAM Role for IoT Rules

- Trust policy: `iot.amazonaws.com` can assume the role
- Permissions: `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents` on:
  - `/aws/iot/esp32-demo/telemetry`
  - `/aws/iot/esp32-demo/events`
  - `/aws/iot/esp32-demo/errors`

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Exponential backoff correctness

*For any* sequence of consecutive connection failures with a given initial interval (1s) and maximum cap (60s for Wi-Fi, 120s for MQTT), each successive backoff interval SHALL equal min(previous × 2, max), and a successful connection SHALL reset the interval to the initial value.

**Validates: Requirements 1.2, 3.4**

### Property 2: Telemetry payload serialization round-trip

*For any* valid set of telemetry metrics (device_id string 1–128 chars, ts non-negative integer, rssi integer -127 to 0, uptime_s integer 0 to 4294967295, heap_free integer 0 to 524288, chip_temp_c float -40.0 to 125.0), serializing via `buildPayload()` SHALL produce valid JSON that, when parsed, contains exactly the fields device_id, ts, type, rssi, uptime_s, heap_free, chip_temp_c with their original values and correct types, no additional fields, and type equal to "connectivity".

**Validates: Requirements 4.3, 4.4, 13.1, 13.3**

### Property 3: Event payload serialization round-trip

*For any* valid event parameters (device_id string 1–128 chars, ts non-negative integer), serializing via `buildPayload()` SHALL produce valid JSON that, when parsed, contains exactly the fields device_id, ts, type, event with their original values, no additional fields, type equal to "button", and event equal to "press".

**Validates: Requirements 5.3, 13.2, 13.3**

### Property 4: Button debounce filter correctness

*For any* sequence of GPIO falling-edge timestamps, the debounce filter SHALL accept a press only if at least 300 milliseconds have elapsed since the last accepted press, and all rejected presses SHALL be silently discarded without side effects.

**Validates: Requirements 5.1, 5.4, 5.6**

### Property 5: Payload size constraint

*For any* valid telemetry input (device_id up to 128 chars, all numeric fields at their maximum representable values), the serialized JSON SHALL be at most 256 bytes. *For any* valid event input (device_id up to 128 chars), the serialized JSON SHALL be at most 128 bytes.

**Validates: Requirements 13.5**

### Property 6: Timestamp fallback when NTP unavailable

*For any* telemetry or event payload produced while NTP synchronization has not succeeded, the ts field SHALL be exactly 0.

**Validates: Requirements 13.4, 2.5**

### Property 7: Log message format

*For any* log tag (non-empty string) and message (arbitrary string), the Logger output SHALL match the pattern `[<millis>][<tag>] <message>` where millis is a non-negative integer.

**Validates: Requirements 6.1, 6.2**

### Property 8: Connectivity timeout triggers reset

*For any* sequence of connectivity state changes (Wi-Fi up/down, MQTT up/down) with timestamps, if no moment exists within a continuous 5-minute window where both Wi-Fi and MQTT are simultaneously connected (since last dual-connectivity or since boot), the supervisor SHALL signal a software reset.

**Validates: Requirements 10.4**

### Property 9: Telemetry publish interval tolerance

*For any* configured `Publish_Interval` and sequence of successful publishes while MQTT remains connected, the elapsed time between consecutive publishes SHALL be within `Publish_Interval ± 5` seconds.

**Validates: Requirements 4.1**

## Error Handling

### Error Categories and Responses

| Error | Detection | Response | Recovery |
|-------|-----------|----------|----------|
| Wi-Fi connection failure | `WiFi.status() != WL_CONNECTED` | Log error, exponential backoff retry | Auto-reconnect up to 60s intervals |
| Wi-Fi timeout on boot | 30s timer expires | Log error, continue with backoff | Same as above |
| NTP sync success | `getLocalTime()` returns true | Log UTC time in ISO 8601 (`YYYY-MM-DDThh:mm:ssZ`) | — |
| NTP sync failure | 30s polling timeout (≤5s poll interval) | Log warning, set ts=0 fallback | Re-attempt on Wi-Fi reconnect if still unsynced |
| MQTT connection failure | `client.connected() == false` | Log error, exponential backoff retry | Auto-reconnect up to 120s intervals |
| MQTT connect timeout | 30s timer expires | Log failure + error code, schedule retry | Backoff retry |
| MQTT publish failure (no ACK) | 10s timeout after QoS 1 publish | Log error code, skip message | Proceed to next scheduled publish |
| Button press while disconnected | `!mqttManager.isConnected()` | Log warning containing `"MQTT unavailable"` | Discard event, no queue/retry |
| 5-minute connectivity loss | Watchdog supervisor timer | Log critical, `ESP.restart()` | Full software reset |
| Watchdog timeout (30s) | Hardware WDT fires | Hard reset (hardware) | Device reboots |
| JSON serialization overflow | ArduinoJson buffer full | Prevented by compile-time `StaticJsonDocument` sizing | N/A — won't occur with valid inputs |

### Error Propagation Strategy

- **No exceptions**: Embedded code uses return values (`bool` success/failure from publish).
- **No message queuing**: Failed publishes are discarded, not retried. Telemetry is periodic so the next cycle recovers naturally.
- **Graceful degradation**: The device continues operating even without cloud connectivity — it collects metrics and handles button presses, just doesn't publish.
- **Last-resort reset**: The 5-minute connectivity timeout and hardware WDT ensure the device never gets permanently stuck.

### Reset Reason Logging

On boot, the firmware logs `esp_reset_reason()` to help diagnose:

- `ESP_RST_POWERON` — normal power-on
- `ESP_RST_SW` — software reset (5-min timeout triggered)
- `ESP_RST_PANIC` — crash/panic
- `ESP_RST_INT_WDT` — interrupt watchdog
- `ESP_RST_TASK_WDT` — task watchdog (our 30s WDT)

## Testing Strategy

### Unit Tests (Example-Based)

Unit tests target the pure logic components that can be isolated from hardware:

| Component | Test Focus |
|-----------|------------|
| `TelemetryPublisher::buildPayload()` | Specific known inputs → expected JSON output |
| `EventPublisher::buildPayload()` | Known device_id/ts → expected JSON |
| Backoff calculation | Specific sequences: 1s, 2s, 4s, 8s... cap |
| Interval check logic | Timer elapsed vs not elapsed |
| Config validation | Out-of-range compile-time error |

**Framework**: Native PlatformIO test environment with `unity` (PlatformIO's default test framework for embedded).

For testability, the `buildPayload()` functions and backoff logic will be implemented as pure functions that take input parameters and return results, separate from hardware-dependent code.

### Property-Based Tests

Property-based tests verify universal correctness properties using generated random inputs.

**Framework**: [`Rapidcheck`](https://github.com/emil-e/rapidcheck) integrated via PlatformIO native test environment (runs on host, not device).

**Configuration**: Minimum 100 iterations per property.

**Tag format**: `Feature: esp32-aws-iot-demo, Property N: <property_text>`

| Property | Test Description | Generators |
|----------|-----------------|------------|
| 1 | Backoff sequence | Random failure counts (1–20), random max caps |
| 2 | Telemetry round-trip | Random device_id (1–128 chars), random valid metrics |
| 3 | Event round-trip | Random device_id (1–128 chars), random ts values |
| 4 | Debounce filter | Random sequences of timestamps (0–10000ms range) |
| 5 | Payload size | Worst-case device_id lengths, max numeric values |
| 6 | Timestamp fallback | Random metrics with NTP flag = false |
| 7 | Log format | Random tags (alphanumeric), random messages |
| 8 | Connectivity timeout | Random state change sequences with timestamps |
| 9 | Publish interval tolerance | Random intervals 10–3600s, simulated loop timing |

### Integration Tests (On-Device)

Integration tests run on the actual ESP32 hardware or against real AWS services:

- Wi-Fi connection and reconnection after AP restart
- NTP synchronization with real server
- MQTT TLS handshake and publish to AWS IoT Core
- End-to-end: button press → CloudWatch Logs entry (or MQTT test client on `devices/+/events`)
- Watchdog reset after deliberate main loop stall

### Test Organization

```
firmware/
├── test/
│   ├── native/           # Runs on host (PBT + unit tests)
│   │   ├── test_backoff/
│   │   ├── test_telemetry_payload/
│   │   ├── test_event_payload/
│   │   ├── test_debounce/
│   │   ├── test_logger_format/
│   │   ├── test_connectivity_timeout/
│   │   └── test_publish_interval/
│   └── embedded/         # Runs on device
│       └── test_integration/
```

### Design Decisions and Rationale

| Decision | Rationale |
|----------|-----------|
| `256dpi/MQTT` over PubSubClient | PubSubClient only supports QoS 0 publish; our requirements mandate QoS 1 |
| ArduinoJson v7 for serialization | Compile-time document sizing prevents runtime allocation failures on ESP32 |
| Pure function extraction for testability | Allows PBT on host without needing actual ESP32 hardware |
| Single-threaded cooperative loop | Avoids FreeRTOS task complexity; sufficient for the publish-only workload |
| `PROGMEM` for certificate storage | Keeps large PEM strings in flash, preserving ~4KB of RAM |
| `volatile bool` for ISR flag | Minimal ISR (just set flag); all work done in main loop context |
| No message queue for failed publishes | Simplicity; telemetry is periodic so next cycle covers any gap |
| 5-minute reset threshold | Long enough to survive transient outages; short enough to recover from stuck states |
| Rapidcheck for PBT (native tests) | Mature C++ PBT library; runs on host via PlatformIO native platform |

## Future Extensibility

The design preserves stable topic patterns and base payload fields to support later phases without breaking existing IoT Rules:

| Extension | Connection Point | Notes |
|-----------|------------------|-------|
| Lambda processing | New IoT Rule action on existing topics | Rules can fan out to Lambda alongside CloudWatch |
| DynamoDB storage | IoT Rule → DynamoDB action | Key on `device_id` + `ts`; use `uptime_s` when `ts=0` |
| Web dashboard | Subscribe via AWS IoT Core or API Gateway + Lambda | Consumes same topic/payload contract documented in `docs/PAYLOAD.md` |
| External sensors | New telemetry `type` values with type-specific fields | Base fields `device_id`, `ts`, `type` remain unchanged per Requirement 14 |

`docs/ARCHITECTURE.md` and `docs/PAYLOAD.md` will document these extension points in a "Future Phases" section during implementation.
