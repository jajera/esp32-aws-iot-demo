# Payload Contract

Stable across all project phases. Defined in Phase 1; consumed unchanged by Phase 2 ingest and Phase 3 API.

Kiro spec: [phase-1 requirements](../.kiro/specs/esp32-aws-iot-demo/phase-1/requirements.md) (Requirement 13–14).

## Topics

- Telemetry: `devices/{Thing_Name}/telemetry`
- Events: `devices/{Thing_Name}/events`

## Stable Base Fields

Present in every telemetry and event message:

- `device_id` (string) — matches `Thing_Name`
- `ts` (integer) — UTC epoch seconds, or `0` if NTP unavailable
- `type` (string) — message discriminator

Type-specific fields are added alongside the base fields. Do not rename or remove base fields when adding new types.

## Telemetry Payload (`type="connectivity"`)

Example:

```json
{
  "device_id": "esp32-c",
  "ts": 1700000000,
  "type": "connectivity",
  "rssi": -67,
  "uptime_s": 3600,
  "heap_free": 180000,
  "chip_temp_c": 42.5,
  "chip_model": "ESP32-S3",
  "cpu_mhz": 240,
  "flash_bytes": 16777216,
  "wifi_ssid": "MyNetwork",
  "wifi_status": 3,
  "wifi_channel": 6,
  "wifi_ip": "192.168.1.42",
  "wifi_gateway": "192.168.1.1",
  "wifi_dns": "8.8.8.8",
  "clock_offset_ms": 125
}
```

Field contract:

- `device_id`: string, 1-128 chars
- `ts`: integer, UTC epoch seconds, or `0`
- `type`: `"connectivity"`
- `rssi`: integer, -127..0 dBm
- `uptime_s`: integer, seconds since boot
- `heap_free`: integer, bytes
- `chip_temp_c`: number, -40.0..125.0 (internal chip temperature estimate)
- `chip_model`: string, e.g. `ESP32-S3` from `ESP.getChipModel()`
- `cpu_mhz`: integer, CPU frequency from `ESP.getCpuFreqMHz()`
- `flash_bytes`: integer, flash size from `ESP.getFlashChipSize()`
- `wifi_ssid`: string, connected SSID from `WiFi.SSID()` (empty if disconnected)
- `wifi_status`: integer, `WiFi.status()` enum (3 = connected)
- `wifi_channel`: integer, Wi-Fi channel from `WiFi.channel()`
- `wifi_ip`: string, device IP from `WiFi.localIP()`
- `wifi_gateway`: string, gateway from `WiFi.gatewayIP()`
- `wifi_dns`: string, DNS from `WiFi.dnsIP()`
- `clock_offset_ms`: integer, SNTP correction applied at sync (0 when unsynced)

Max serialized size: 512 bytes.

Implemented in `firmware/src/payload_codec.h`.

## Event Payload (`type="button"`)

Example:

```json
{
  "device_id": "esp32-c",
  "ts": 1700000000,
  "type": "button",
  "event": "press"
}
```

Field contract:

- `device_id`: string, 1-128 chars
- `ts`: integer, UTC epoch seconds, or `0`
- `type`: `"button"`
- `event`: `"press"`

Max serialized size: 128 bytes.

## Adding New Telemetry Types

1. Keep base fields unchanged (`device_id`, `ts`, `type`)
2. Add type-specific fields only
3. Do not change topics or remove existing base fields
4. Update this document and the Kiro spec before implementation
