# Requirements Document — Phase 1: Device + IoT Baseline

> **Status:** ACTIVE — implement now.

## Introduction

This document defines the requirements for the ESP32 AWS IoT Demo — a demonstration project that connects an IdeaSpark esp32-c board to AWS IoT Core over MQTT. The firmware publishes structured JSON telemetry (Wi-Fi RSSI, uptime, free heap, chip temperature) on a configurable interval and one-shot button events via the onboard BOOT button. The payload and topic design supports downstream serverless processing through IoT Rules, Lambda, and storage services. No external sensors are required for v0/v1.

The repository targets the PlatformIO `esp32dev` board profile, which is compatible with IdeaSpark esp32-c modules and other classic ESP32 dev boards. Implementation artifacts (firmware, AWS provisioning scripts, and documentation) are specified below.

**Master index:** [README.md](../README.md)

## Project Phases

| Phase | Scope | Spec location |
|-------|-------|---------------|
| 1 | Device + IoT baseline (this document) | `phase-1/` |
| 2 | Serverless ingest | [phase-2/requirements.md](../phase-2/requirements.md) |
| 3 | API + Amplify dashboard | [phase-3/requirements.md](../phase-3/requirements.md) |

Requirement 14 (Future Extensibility) remains valid; Phase 2 and Phase 3 specs are the authoritative expansion of those extension points.

## Stable Contracts (defined here, locked for all phases)

- **Telemetry_Topic:** `devices/{Thing_Name}/telemetry`
- **Events_Topic:** `devices/{Thing_Name}/events`
- **IoT Rule SQL patterns:** `SELECT * FROM 'devices/+/telemetry'` and `SELECT * FROM 'devices/+/events'`
- **Payload base fields:** `device_id`, `ts`, `type` (see [docs/PAYLOAD.md](../../../../docs/PAYLOAD.md))

## Glossary

- **Firmware**: The PlatformIO-based application code flashed onto the esp32-c board
- **esp32-c**: The IdeaSpark esp32-c development board (classic ESP32, 2.4 GHz Wi-Fi, onboard BOOT button on GPIO0)
- **BOOT_Button**: The onboard button on GPIO0 of the esp32-c used to trigger event messages; GPIO0 is a strapping pin — holding it low during reset enters the UART bootloader, so event testing should occur after normal boot
- **AWS_IoT_Core**: The AWS IoT Core MQTT broker endpoint that receives device messages
- **MQTT_Client**: The MQTT client component within the Firmware that manages the TLS MQTT session and publishes messages to AWS_IoT_Core (Wi-Fi link management is handled separately by the Firmware)
- **Telemetry_Publisher**: The Firmware component responsible for collecting device metrics and publishing periodic telemetry messages
- **Event_Publisher**: The Firmware component responsible for publishing one-shot event messages triggered by hardware inputs
- **IoT_Rule**: An AWS IoT Core rule that evaluates incoming messages using SQL and routes them to downstream actions
- **Thing_Name**: The unique AWS IoT Thing identifier assigned to the device, used in topic paths and the device_id payload field
- **Telemetry_Topic**: The MQTT topic `devices/{Thing_Name}/telemetry` used for periodic telemetry messages
- **Events_Topic**: The MQTT topic `devices/{Thing_Name}/events` used for one-shot event messages
- **Telemetry_Payload**: A JSON object containing device_id, ts, type, rssi, uptime_s, heap_free, and chip_temp_c fields
- **Event_Payload**: A JSON object containing device_id, ts, type, and event fields
- **Device_Certificate**: The X.509 certificate and private key used to authenticate the device to AWS_IoT_Core via mutual TLS
- **IoT_Policy**: The AWS IoT policy attached to the Device_Certificate that grants least-privilege permissions
- **Amazon_Root_CA**: The Amazon Trust Services root CA certificate used to validate the AWS_IoT_Core server certificate
- **Publish_Interval**: The configurable time between periodic telemetry publishes, defaulting to 60 seconds
- **NTP_Server**: The Network Time Protocol server used to synchronize device wall-clock time after Wi-Fi association

## Requirements

### Requirement 1: Wi-Fi Connection

**User Story:** As a developer, I want the esp32-c to connect to a configured Wi-Fi network, so that the device has network connectivity for MQTT communication.

#### Acceptance Criteria

1. WHEN the Firmware boots, THE Firmware SHALL connect to the Wi-Fi network specified in the compile-time configuration within 30 seconds
2. IF the Wi-Fi connection is lost, THEN THE Firmware SHALL attempt reconnection using exponential backoff starting at 1 second and doubling up to a maximum interval of 60 seconds
3. WHILE connected to Wi-Fi, THE Firmware SHALL respond to Wi-Fi stack keepalive mechanisms and re-associate automatically if a transient disconnection occurs, without requiring a software reset or manual intervention
4. THE Firmware SHALL read Wi-Fi SSID (up to 32 characters) and password (8 to 63 characters) from a compile-time configuration header file that is excluded from version control
5. IF the Firmware fails to connect to the configured Wi-Fi network within 30 seconds during boot, THEN THE Firmware SHALL log an error to the serial console and continue retrying using the exponential backoff strategy defined in criterion 2

### Requirement 2: Time Synchronization

**User Story:** As a developer, I want the device to synchronize UTC time after joining Wi-Fi, so that published timestamps are meaningful in the cloud.

#### Acceptance Criteria

1. WHEN Wi-Fi connectivity is established for the first time after boot, THE Firmware SHALL synchronize device time via NTP before the first telemetry or event publish attempt
2. THE Firmware SHALL use a compile-time configurable NTP_Server with a default value of `pool.ntp.org`
3. THE Firmware SHALL attempt NTP synchronization for up to 30 seconds, polling at intervals of no more than 5 seconds, before proceeding without synchronized time
4. IF NTP synchronization succeeds, THEN THE Firmware SHALL log the synchronized UTC time in ISO 8601 format (YYYY-MM-DDThh:mm:ssZ) to the serial console
5. IF NTP synchronization fails after the 30-second timeout, THEN THE Firmware SHALL log a warning to the serial console and continue operation using the fallback timestamp behavior defined in Requirement 13 (ts field set to 0)
6. IF Wi-Fi connectivity is re-established after a disconnection and the device does not have a previously synchronized time, THEN THE Firmware SHALL re-attempt NTP synchronization following the same 30-second timeout behavior

### Requirement 3: AWS IoT Core MQTT Connection

**User Story:** As a developer, I want the esp32-c to establish a secure MQTT connection to AWS IoT Core, so that the device can publish telemetry and events to the cloud.

#### Acceptance Criteria

1. WHEN Wi-Fi connectivity is established, THE MQTT_Client SHALL connect to the AWS_IoT_Core endpoint using mutual TLS with the Device_Certificate and TLS 1.2 or higher within 30 seconds
2. THE MQTT_Client SHALL use the Thing_Name as the MQTT client identifier
3. THE MQTT_Client SHALL use a keep-alive interval of 60 seconds
4. IF the MQTT connection attempt fails or the MQTT connection is lost, THEN THE MQTT_Client SHALL attempt reconnection using exponential backoff starting at 1 second and doubling up to a maximum interval of 120 seconds
5. THE MQTT_Client SHALL validate the AWS_IoT_Core server certificate against the Amazon_Root_CA embedded in the Firmware
6. THE Firmware SHALL read the AWS_IoT_Core endpoint, Thing_Name, Device_Certificate, private key, and Amazon_Root_CA from compile-time embedded sources
7. IF the MQTT_Client fails to connect within 30 seconds, THEN THE MQTT_Client SHALL abort the attempt, log the failure to the serial console, and schedule a reconnection attempt using the exponential backoff defined in criterion 4

### Requirement 4: Periodic Telemetry Publishing

**User Story:** As a developer, I want the device to publish connectivity telemetry at a regular interval, so that I can monitor device health in the cloud.

#### Acceptance Criteria

1. WHILE connected to AWS_IoT_Core, THE Telemetry_Publisher SHALL publish a Telemetry_Payload to the Telemetry_Topic every Publish_Interval seconds with a tolerance of ±5 seconds
2. THE Telemetry_Publisher SHALL publish messages at MQTT QoS 1
3. THE Telemetry_Payload SHALL contain the following fields: device_id (string matching Thing_Name), ts (integer Unix seconds UTC when NTP is synchronized, otherwise 0), type (string value "connectivity"), rssi (integer dBm in the range -127 to 0), uptime_s (integer seconds since boot), heap_free (integer bytes of free heap), and chip_temp_c (number degrees Celsius from the ESP32 internal temperature sensor; approximate, not calibrated ambient temperature)
4. THE Telemetry_Publisher SHALL encode all numeric values as JSON numbers and all string values as JSON strings
5. THE Telemetry_Publisher SHALL use a default Publish_Interval of 60 seconds
6. THE Telemetry_Publisher SHALL allow the Publish_Interval to be configured at compile time; IF the configured value is below 10 seconds or above 3600 seconds, THEN the build SHALL fail with a compile-time error indicating the valid range
7. IF the MQTT connection is unavailable at publish time, THEN THE Telemetry_Publisher SHALL skip the publish attempt and log a warning to the serial console
8. IF a QoS 1 publish does not receive an acknowledgement within 10 seconds, THEN THE Telemetry_Publisher SHALL log an error to the serial console and proceed to the next scheduled publish without retrying the failed message

### Requirement 5: Button Event Publishing

**User Story:** As a developer, I want pressing the BOOT button to publish a one-shot event, so that I can demonstrate event-driven messaging from the device.

#### Acceptance Criteria

1. WHEN the BOOT_Button GPIO0 signal transitions from high to low (active-low press detected after debounce), THE Event_Publisher SHALL publish an Event_Payload to the Events_Topic within 500 milliseconds of the accepted press
2. THE Event_Publisher SHALL publish messages at MQTT QoS 1
3. THE Event_Payload SHALL contain the following fields: device_id (string matching Thing_Name), ts (integer Unix seconds UTC when NTP is synchronized, otherwise 0), type (string value "button"), and event (string value "press")
4. THE Event_Publisher SHALL debounce BOOT_Button presses with a minimum interval of 300 milliseconds between accepted presses, silently discarding any press occurring within 300 milliseconds of the previous accepted press
5. IF the MQTT_Client is not in a connected state when an accepted BOOT_Button press occurs, THEN THE Event_Publisher SHALL log a warning including the text "MQTT unavailable" to the serial console and discard the event without queuing or retrying
6. THE Event_Publisher SHALL configure GPIO0 as input with internal pull-up enabled and detect button presses using the falling-edge signal transition

### Requirement 6: Serial Logging

**User Story:** As a developer, I want the device to output diagnostic information over serial, so that I can debug connectivity and message publishing during development.

#### Acceptance Criteria

1. THE Firmware SHALL initialize the serial console at 115200 baud 8N1 before any other component begins operation
2. THE Firmware SHALL prefix each log message with the milliseconds elapsed since boot and a component tag in the format `[<millis>][<tag>] <message>` where tag identifies the originating component
3. WHEN the Wi-Fi connection is established, THE Firmware SHALL log the assigned IP address to the serial console
4. WHEN the Wi-Fi connection is lost, THE Firmware SHALL log the disconnection event to the serial console
5. WHEN the MQTT connection state changes, THE Firmware SHALL log the new state (connected or disconnected) to the serial console
6. WHEN a telemetry message is published, THE Telemetry_Publisher SHALL log the topic and payload size in bytes to the serial console
7. WHEN a button event is published, THE Event_Publisher SHALL log the topic and payload to the serial console
8. IF a publish attempt fails, THEN THE Firmware SHALL log the MQTT library error code and a description of the failure reason to the serial console

### Requirement 7: AWS IoT Thing Provisioning

**User Story:** As a developer, I want documented steps or scripts to provision the AWS IoT Thing, certificate, and policy, so that I can set up the cloud side of the demo quickly.

#### Acceptance Criteria

1. THE provisioning documentation SHALL include AWS CLI commands to create an IoT Thing with a specified Thing_Name
2. THE provisioning documentation SHALL include AWS CLI commands to create and download a Device_Certificate and private key, and activate the certificate in the same command
3. THE provisioning documentation SHALL include AWS CLI commands to create and attach an IoT_Policy to the Device_Certificate
4. THE provisioning documentation SHALL include AWS CLI commands to attach the Device_Certificate to the IoT Thing
5. THE IoT_Policy SHALL grant the following permissions scoped to the provisioning account and region in the Resource ARN: iot:Connect with client ID matching the Thing_Name, iot:Publish to topics `devices/${iot:Connection.Thing.ThingName}/telemetry` and `devices/${iot:Connection.Thing.ThingName}/events`, and no other actions or resources
6. THE provisioning documentation SHALL include the AWS CLI command to retrieve the account-specific AWS_IoT_Core endpoint
7. THE provisioning documentation SHALL include instructions to download the AmazonRootCA1.pem file from the Amazon Trust Services repository for server certificate validation
8. THE provisioning documentation SHALL present the commands in dependency order: create Thing, create and activate certificate, create policy, attach policy to certificate, attach certificate to Thing, retrieve endpoint

### Requirement 8: IoT Rule for Telemetry Routing

**User Story:** As a developer, I want an IoT Rule that routes telemetry messages to CloudWatch Logs, so that I can verify end-to-end message delivery without building a full processing pipeline.

#### Acceptance Criteria

1. THE IoT_Rule SHALL be named `esp32_demo_telemetry_rule` and use the SQL statement `SELECT * FROM 'devices/+/telemetry'` to match all telemetry messages
2. THE IoT_Rule SHALL route matched messages to a CloudWatch Logs log group named `/aws/iot/esp32-demo/telemetry` with a retention period of 7 days
3. THE provisioning documentation SHALL include the IoT_Rule definition as a deployable AWS CLI command, including creation of the CloudWatch Logs log groups, and an IAM role granting the IoT_Rule permission to write to the `/aws/iot/esp32-demo/telemetry` and `/aws/iot/esp32-demo/errors` log groups
4. IF the IoT_Rule action fails, THEN THE IoT_Rule SHALL route the message to an error action that logs to a CloudWatch Logs log group named `/aws/iot/esp32-demo/errors` with a retention period of 14 days

### Requirement 9: IoT Rule for Event Routing

**User Story:** As a developer, I want an IoT Rule that routes button events to CloudWatch Logs, so that I can verify event delivery separately from telemetry.

#### Acceptance Criteria

1. THE IoT_Rule SHALL be named `esp32_demo_events_rule` and use the SQL statement `SELECT * FROM 'devices/+/events'` to match all event messages
2. THE IoT_Rule SHALL route matched messages to a CloudWatch Logs log group named `/aws/iot/esp32-demo/events`
3. THE provisioning documentation SHALL include the IoT_Rule definition as a deployable JSON or AWS CLI command, separate from the telemetry IoT_Rule defined in Requirement 8
4. IF the IoT_Rule action fails, THEN THE IoT_Rule SHALL route the message to an error action that logs to a CloudWatch Logs log group named `/aws/iot/esp32-demo/errors`
5. THE provisioning documentation SHALL include AWS CLI commands to create an IAM role with a trust policy allowing `iot.amazonaws.com` to assume it, and a permissions policy granting `logs:CreateLogGroup`, `logs:CreateLogStream`, and `logs:PutLogEvents` on the `/aws/iot/esp32-demo/events` and `/aws/iot/esp32-demo/errors` log groups

### Requirement 10: Watchdog and Stability

**User Story:** As a developer, I want the device to recover gracefully from errors, so that the demo runs unattended without manual resets.

#### Acceptance Criteria

1. THE Firmware SHALL enable the hardware watchdog timer with a timeout of 30 seconds
2. WHILE the Firmware main loop is executing, THE Firmware SHALL feed the watchdog timer at least once every 15 seconds to prevent unintended resets
3. WHILE the Firmware is attempting Wi-Fi reconnection or MQTT reconnection, THE Firmware SHALL continue to feed the watchdog timer to prevent spurious resets during expected backoff periods
4. IF the Firmware has not established both Wi-Fi and MQTT connectivity simultaneously for a continuous period of 5 minutes since the last time both were connected (or since boot if never connected), THEN THE Firmware SHALL perform a software reset
5. WHEN the Firmware boots, THE Firmware SHALL log the reset reason from the previous boot cycle to the serial console

### Requirement 11: Configuration and Secrets Management

**User Story:** As a developer, I want a clear separation between committed configuration templates and secret credentials, so that I can share the repo without exposing credentials.

#### Acceptance Criteria

1. THE repository SHALL include a `firmware/include/config.example.h` file containing placeholder values for Wi-Fi SSID, Wi-Fi password, Thing_Name, AWS_IoT_Core endpoint, Publish_Interval, and NTP_Server, where each value is defined as a C preprocessor macro with a commented description of the expected format
2. THE repository SHALL include a `firmware/include/certs.example.h` file containing placeholder macros named `AWS_CERT_CRT`, `AWS_CERT_PRIVATE`, and `AWS_CERT_CA` for the Device_Certificate, private key, and Amazon_Root_CA PEM contents respectively, each defined as a C string literal with escaped newlines
3. THE repository SHALL exclude actual credential files from version control via `.gitignore` entries that cover at minimum `firmware/include/config.h`, `firmware/include/certs.h`, and any `*.pem` files within the `firmware/` directory
4. THE Firmware SHALL embed the Device_Certificate, private key, and Amazon_Root_CA from `firmware/include/certs.h` and read the AWS_IoT_Core endpoint and Thing_Name from `firmware/include/config.h` at compile time
5. IF `firmware/include/config.h` or `firmware/include/certs.h` is missing at compile time, THEN THE build SHALL fail with a preprocessor error message indicating which file must be created from its corresponding `.example.h` template
6. THE repository SHALL include in `docs/CERTIFICATES.md` step-by-step instructions describing how to download certificates from the AWS IoT console or CLI and copy the PEM contents into C string literal macros in `firmware/include/certs.h`

### Requirement 12: Project Structure and Tooling

**User Story:** As a developer, I want a well-organized repository with PlatformIO as the build system, so that I can clone, configure, and flash the firmware reproducibly.

#### Acceptance Criteria

1. THE repository SHALL use PlatformIO as the build system with a `firmware/platformio.ini` file targeting the `esp32dev` board with the Arduino framework
2. THE repository SHALL organize firmware source code under `firmware/src/`, headers under `firmware/include/`, and AWS provisioning artifacts under `aws/`
3. THE repository SHALL include a README.md with a zero-to-first-message guide covering: prerequisites (PlatformIO CLI, AWS CLI, AWS account), cloning, certificate setup, configuration, flashing, and verifying the first message in the AWS IoT MQTT test client subscribed to the `devices/+/telemetry` topic
4. THE repository SHALL include a `docs/PAYLOAD.md` file documenting the JSON contract for both Telemetry_Payload and Event_Payload, including field names, data types, valid ranges, and a complete example for each payload type
5. THE repository SHALL include a `docs/ARCHITECTURE.md` file documenting the logical architecture from device to cloud, identifying each component (Firmware, Wi-Fi, MQTT, AWS IoT Core, IoT Rules, CloudWatch Logs) and the connections between them
6. THE repository SHALL include a LICENSE file (MIT)
7. THE project SHALL compile successfully with `pio run` when valid `config.h` and `certs.h` files are present in `firmware/include/`

### Requirement 13: Payload Validation Contract

**User Story:** As a developer, I want a documented and stable JSON payload contract, so that downstream consumers can be built against a known schema.

#### Acceptance Criteria

1. THE Telemetry_Payload SHALL conform to the following schema: device_id (string, 1–128 characters matching the Thing_Name, required), ts (integer, required; Unix epoch seconds UTC when NTP is synchronized, otherwise 0), type (string enum "connectivity", required), rssi (integer in the range -127 to 0 representing dBm, required), uptime_s (integer in the range 0 to 4294967295, required), heap_free (integer in the range 0 to 524288 representing bytes, required), chip_temp_c (number in the range -40.0 to 125.0 with at most one decimal place, required)
2. THE Event_Payload SHALL conform to the following schema: device_id (string, 1–128 characters matching the Thing_Name, required), type (string enum "button", required), ts (integer, required; Unix epoch seconds UTC when NTP is synchronized, otherwise 0), event (string enum "press", required)
3. THE Firmware SHALL produce valid JSON with no trailing commas, no NaN values, no unquoted string fields, and no fields beyond those defined in the schema for the respective payload type
4. WHEN NTP synchronization is unavailable, THE Firmware SHALL set the ts field to 0 in both Telemetry_Payload and Event_Payload
5. THE Firmware SHALL produce each Telemetry_Payload in no more than 256 bytes and each Event_Payload in no more than 128 bytes of serialized JSON

### Requirement 14: Future Extensibility (Placeholder)

**User Story:** As a developer, I want the architecture to support future additions (external sensors, Lambda processing, web dashboard), so that I can extend the demo without redesigning the payload or topic structure.

#### Acceptance Criteria

1. THE Telemetry_Topic pattern `devices/{Thing_Name}/telemetry` SHALL NOT change across project phases, so that existing IoT_Rule SQL statements (`SELECT * FROM 'devices/+/telemetry'`) continue to match without modification
2. THE Events_Topic pattern `devices/{Thing_Name}/events` SHALL NOT change across project phases, so that existing IoT_Rule SQL statements (`SELECT * FROM 'devices/+/events'`) continue to match without modification
3. THE Telemetry_Payload SHALL treat the fields device_id, ts, and type as base schema fields that are present in every telemetry message regardless of type value, and SHALL permit additional type-specific fields (e.g., rssi, uptime_s for type "connectivity"; sensor-specific fields for future types) without requiring removal or renaming of the base fields
4. THE docs/ARCHITECTURE.md SHALL include a "Future Phases" section that documents, for each extension point (Lambda processing, DynamoDB storage, and web dashboard), the following: the AWS service involved, how it connects to the existing topic or rule structure, and a description of the data flow from the device through to that service
5. THE docs/PAYLOAD.md SHALL document the base schema fields (device_id, ts, type) as stable across all telemetry types and SHALL describe the convention for adding type-specific fields alongside the base fields when a new type value is introduced
