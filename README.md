# esp32-aws-iot-demo

ESP32-S3 demo (ESP32-S3-WROOM-1 **N16R8**: 16 MB flash, 8 MB PSRAM, native USB) connecting to AWS IoT Core over MQTT with mutual TLS, publishing periodic telemetry and BOOT-button events.

**Operator guide:** [docs/WALKTHROUGH.md](docs/WALKTHROUGH.md) (Phase 1–3, troubleshooting, recorded examples)

| Phase | Status | Scope |
|-------|--------|-------|
| **1** | Implemented | Device firmware, AWS bootstrap, CloudWatch verification |
| **2** | Implemented | Terraform serverless ingest (Lambda + DynamoDB) |
| **3** | Implemented | Query API + Amplify dashboard |

MQTT topics: `devices/{Thing_Name}/telemetry`, `devices/{Thing_Name}/events` — [docs/PAYLOAD.md](docs/PAYLOAD.md)

## Prerequisites

- PlatformIO CLI (`pio`)
- AWS CLI v2 (`aws`), region `ap-southeast-2` (Sydney)
- ESP32-S3 N16R8 board, USB **data** cable
- One-time Linux USB setup: [docs/LINUX_USB.md](docs/LINUX_USB.md)

## Quick start (Phase 1)

```bash
export WIFI_SSID="your-ssid" WIFI_PASSWORD="your-password"
export THING_NAME="esp32-c" AWS_REGION=ap-southeast-2

./aws/provision.sh
./scripts/generate-headers.sh
pio run -d firmware -e esp32-s3-n16r8 -t upload && pio device monitor -d firmware -b 115200
```

Full steps, USB troubleshooting, CloudWatch verification, Terraform, and dashboard: **[docs/WALKTHROUGH.md](docs/WALKTHROUGH.md)**

**On the board:** after Wi-Fi and MQTT connect, telemetry publishes every ~60 s. Each successful publish flashes the onboard **RGB LED blue** briefly. Press **BOOT** (GPIO0) after normal boot for a one-shot event — do not hold BOOT during reset (that enters the bootloader).

## Verify locally (no hardware)

```bash
pio test -d firmware -e native
pio run -d firmware -e esp32-s3-n16r8
```

## Project layout

| Path | Purpose |
|------|---------|
| `firmware/` | ESP32 firmware (`env:esp32-s3-n16r8`) |
| `aws/` | Phase 1 bootstrap scripts ([aws/README.md](aws/README.md)) |
| `terraform/` | Shared infra Phases 2–3 ([terraform/README.md](terraform/README.md)) |
| `web/` | Dashboard SPA (Vite) |
| `docs/` | [WALKTHROUGH.md](docs/WALKTHROUGH.md), [ARCHITECTURE.md](docs/ARCHITECTURE.md), [PAYLOAD.md](docs/PAYLOAD.md), [LINUX_USB.md](docs/LINUX_USB.md) |
| `.kiro/specs/` | Kiro design specs |

Gitignored: `firmware/include/config.h`, `firmware/include/certs.h`, `firmware/certs/`
