# Walkthrough — ESP32 AWS IoT Demo

End-to-end operator guide for **ESP32-S3-WROOM-1 N16R8** on Linux (region **ap-southeast-2**). Verified run used Thing `esp32-c` on **2026-06-21**.

- **[Phase 1](#phase-1--zero-to-first-message)** — device firmware, AWS bootstrap, CloudWatch verification (includes failures we hit and fixes)
- **[Phase 2](#phase-2--serverless-ingest-terraform)** — Terraform shared infra, Lambda ingest, DynamoDB persistence
- **[Phase 3](#phase-3--api--amplify-dashboard)** — Query API + dashboard (local Vite and optional Amplify hosting)

Use this as the single onboarding document.

**Reference:** [ARCHITECTURE.md](ARCHITECTURE.md) · [PAYLOAD.md](PAYLOAD.md) · [aws/README.md](../aws/README.md)

---

## Hardware and environment

| Item | Value (verified run) |
|------|----------------------|
| Board | ESP32-S3-WROOM-1 **N16R8** (16 MB flash, 8 MB OPI PSRAM) |
| USB | Native USB-Serial/JTAG → `303a:4001` in `lsusb` (also seen: `303a:1001`) |
| PlatformIO env | `esp32-s3-n16r8` (repo default) — **not** `esp32dev` |
| Serial port | `/dev/ttyACM0` or `/dev/ttyACM1` (S3 may re-enumerate after upload) |
| AWS region | `ap-southeast-2` |
| Thing name | `esp32-c` |
| Host | Ubuntu Linux |

Classic ESP32 devkits (CP210x/CH340 → `/dev/ttyUSB0`) use env `esp32dev` instead; this walkthrough is for **S3 N16R8 only**.

---

## Phase 1 — Zero to First Message

### Phase 1 checklist

1. [Prerequisites](#1-prerequisites)
2. [Environment variables](#2-environment-variables)
3. [Provision AWS](#3-provision-aws)
4. [Generate firmware headers](#4-generate-firmware-headers)
5. [Linux USB setup](#5-linux-usb-setup-one-time)
6. [Build and flash](#6-build-and-flash)
7. [Serial monitor](#7-serial-monitor)
8. [Verify cloud delivery (AWS CLI)](#8-verify-cloud-delivery-aws-cli)
9. [Success criteria](#9-success-criteria)
10. [Teardown (optional)](#10-teardown-optional)

---

## 1. Prerequisites

- PlatformIO CLI (`pio`)
- AWS CLI v2 (`aws`) with credentials for IoT Core, IAM, CloudWatch Logs
- USB **data** cable (not charge-only)
- Wi-Fi network the board can join

---

## 2. Environment variables

Export for the session (replace placeholders):

```bash
export WIFI_SSID="your-ssid"
export WIFI_PASSWORD="your-password"
export THING_NAME="esp32-c"
export AWS_REGION=ap-southeast-2
```

---

## 3. Provision AWS

From repo root:

```bash
./aws/provision.sh
```

Creates CloudFormation stack `esp32-demo-phase1` (IoT Rules, IAM, CloudWatch log groups), then the Thing, certificate, and policy. PEM files land in `firmware/certs/` (gitignored). The script prints `AWS_IOT_ENDPOINT=...`.

**If this step fails:** confirm `aws sts get-caller-identity` works and your IAM user/role can create IoT, IAM, CloudFormation, and CloudWatch Logs resources in `ap-southeast-2`.

---

## 4. Generate firmware headers

```bash
./scripts/generate-headers.sh
```

Requires `WIFI_SSID`, `WIFI_PASSWORD`, and `THING_NAME`. Produces `firmware/include/config.h` and `firmware/include/certs.h`.

**If build later fails with `#error "Missing firmware/include/config.h"`:** re-run this script with env vars set. Headers are gitignored and must exist locally before compile.

---

## 5. Linux USB setup (one-time)

PlatformIO needs read/write access to the serial port. Fix permissions once on the host — **do not** use `sudo pio run … upload` as a workaround.

### Run setup

From repo root:

```bash
sudo ./scripts/setup-linux-usb.sh
```

The script:

1. Installs PlatformIO udev rules to `/etc/udev/rules.d/99-platformio-udev.rules` (Espressif native USB, CP210x, CH340, …).
2. Reloads udev.
3. Adds your user to the **`dialout`** group if not already a member.

**Expected:**

```text
Installing udev rules → /etc/udev/rules.d/99-platformio-udev.rules
Reloading udev
Adding <your-user> to group dialout    # omitted if already in dialout

Setup complete.

Next steps (required):
  1. Log out and log back in (or reboot) ...
  2. Unplug and replug the ESP32 USB cable.
```

Then **log out and back in** (or reboot) and **unplug/replug** the board. A new terminal alone is not always enough for `dialout` to apply.

### Verify before upload

With the board connected:

```bash
groups | grep dialout
lsusb
ls -l /dev/ttyACM0 /dev/ttyACM1 2>/dev/null
pio device list
```

| Check | Expected (ESP32-S3 N16R8) |
|-------|---------------------------|
| `lsusb` | `303a:1001` or `303a:4001` — Espressif Systems |
| Serial port | `/dev/ttyACM0` (or `ttyACM1`) with `crw-rw-rw-` or group `dialout` |
| `groups` | includes `dialout` (after re-login) |

### Problem — no serial port at all

**Symptoms:** `ls /dev/ttyACM*` returns nothing; `lsusb` shows only root hubs (no Espressif line); `pio device list` has no ACM/USB UART device.

**Cause:** charge-only USB cable, bad port/hub, board not powered, or loose connection. Kernel may show a brief connect then immediate disconnect (~10 s).

**Fix:**

1. Use a **data** USB cable (LED on does not prove data lines work).
2. Plug directly into the PC if possible; try another port.
3. Unplug/replug; press **RST/EN** after connecting.
4. Re-check:

   ```bash
   lsusb
   ls /dev/ttyACM* 2>/dev/null
   journalctl -k -n 30 --no-pager   # optional: see connect/disconnect events
   ```

### Problem — `Permission denied` on `/dev/ttyACM0`

**Symptoms:**

```text
Auto-detected: /dev/ttyACM0
...
[Errno 13] Permission denied: '/dev/ttyACM0'
Hint: Try to add user into dialout or uucp group.
```

**Cause:** udev rules not installed, `dialout` group not applied, or board plugged in before setup/re-login.

**Fix:**

1. Run `sudo ./scripts/setup-linux-usb.sh`.
2. **Log out and back in** (or reboot).
3. Unplug and replug the board.
4. Confirm `groups | grep dialout`.

Do **not** flash with `sudo pio …` — fix host permissions instead.

**Note:** If the device node is `crw-rw-rw-` (mode 666), upload may work even before `dialout` appears in `groups`. Still complete setup and re-login for a stable configuration.

### Problem — `outdated … udev.rules` warning

**Symptoms during upload:**

```text
Warning! Your `/etc/udev/rules.d/99-platformio-udev.rules` are outdated.
Please update or reinstall them.
```

**Cause:** Older or trimmed udev rules file on the system.

**Fix:** Re-run `sudo ./scripts/setup-linux-usb.sh`. Upload can still succeed with this warning; refresh rules to silence it and cover all board types.

---

## 6. Build and flash

Compile (no USB required):

```bash
pio run -d firmware -e esp32-s3-n16r8
```

Flash (board connected):

```bash
pio run -d firmware -e esp32-s3-n16r8 -t upload
```

Or upload and monitor in one step:

```bash
pio run -d firmware -e esp32-s3-n16r8 -t upload && pio device monitor -d firmware -b 115200
```

Pin the port if auto-detect picks the wrong device:

```bash
pio run -d firmware -e esp32-s3-n16r8 -t upload --upload-port /dev/ttyACM0
```

`firmware/platformio.ini` enables `board_upload.use_1200bps_touch` and `wait_for_upload_port` so **later** uploads can enter the bootloader without manual BOOT on many boards. **First flash** often still needs manual steps below.

### Problem — wrong PlatformIO env (`esp32dev` on S3)

**Symptoms:** Upload targets wrong chip; `Connecting…` never completes; or esptool reports wrong chip type.

**Cause:** Classic ESP32 env on ESP32-S3 hardware.

**Fix:** Always use `-e esp32-s3-n16r8` (repo default). Classic boards only: `-e esp32dev` + `/dev/ttyUSB0`.

### Problem — `Connecting…` then `Failed to connect` / `No serial data received`

**Symptoms:**

```text
Serial port /dev/ttyACM0
Connecting......................................
A fatal error occurred: Failed to connect to ESP32-S3: No serial data received.
```

**Cause:** ESP32-S3 native USB is not in ROM download mode. Common on **first flash** before this project's firmware is installed. Factory firmware may also be running.

**Fix:**

1. Close any serial monitor using the port (Ctrl+C).
2. Hold **BOOT** (GPIO0).
3. Tap **RST/EN** once, then release **BOOT**.
4. Within a few seconds, run upload again.

If serial shows unrelated output such as `example: log -> USB`, the board is still on **factory demo firmware** — proceed with BOOT+RST and flash this project to replace it.

### Problem — `Invalid head of packet (0x1B)`

**Symptoms:**

```text
Serial port /dev/ttyACM0
Connecting......................................
A fatal error occurred: Failed to connect to ESP32-S3: Invalid head of packet (0x1B):
Possible serial noise or corruption.
```

**Cause:** The running application is printing on USB serial (log output, factory demo, or an open monitor) while esptool expects the bootloader sync byte. `0x1B` is often an ANSI escape from serial text.

**Fix:**

1. Close the serial monitor and any other tool using the port.
2. Enter download mode: hold **BOOT** → tap **RST/EN** → release **BOOT**.
3. Upload immediately.

### Problem — port busy

**Symptoms:** Upload or monitor fails because the device is in use.

**Fix:** Ctrl+C any `pio device monitor`; close Arduino IDE serial tools; retry.

### Problem — port changed (`ttyACM0` → `ttyACM1`)

**Symptoms:** Upload succeeded on `ttyACM1`; monitor auto-picks a different port than expected.

**Cause:** ESP32-S3 USB re-enumerates after reset/flash.

**Fix:** Let PlatformIO auto-detect, or pass `--upload-port` / `--port` for whichever exists:

```bash
ls -l /dev/ttyACM*
```

**Successful upload:** `Chip is ESP32-S3` with `Embedded PSRAM 8MB`, `Hash of data verified`, and `[SUCCESS]`.

---

## 7. Serial monitor

```bash
pio device monitor -d firmware -b 115200
```

### Problem — blank monitor after upload

**Symptoms:** Monitor connects (`--- Terminal on /dev/ttyACM1 | 115200 ---`) but no log lines.

**Cause:** Board reset during upload **before** the monitor opened; boot logs were missed. Common on ESP32-S3 USB CDC.

**Fix:**

1. With monitor still open, press **RST/EN** once — **do not** hold BOOT (that enters bootloader).
2. Or use the one-liner: `pio run … -t upload && pio device monitor …`.

### Problem — Wi-Fi or MQTT never connects

**Symptoms:** No `[wifi] connected` or no `[mqtt] connected`; only retries or timeout messages.

**Likely causes and fixes:**

| Symptom | Fix |
|---------|-----|
| `wifi failed to connect within 30s` | Check `WIFI_SSID` / `WIFI_PASSWORD`; re-run `generate-headers.sh`; rebuild and re-flash |
| MQTT errors after Wi-Fi OK | Confirm `THING_NAME` in `config.h` matches AWS Thing; re-run `provision.sh` + `generate-headers.sh` if certs are stale |
| `ts` is `0` in payloads | NTP not synced yet (or blocked); device still publishes — timestamps populate after SNTP |

### BOOT button vs bootloader

- **After normal boot:** press **BOOT** once → one-shot `[event] published … events`.
- **During reset:** holding **BOOT** while pressing **RST** → download mode (for upload), **not** the app.

### Status LED (telemetry sent)

ESP32-S3-DevKitC-1 boards have an addressable **RGB LED** (WS2812) next to the steady red power LED:

| Signal | LED behavior |
|--------|----------------|
| Successful telemetry publish (~every 60 s) | **Blue flash** (~800 ms, moderate brightness) |
| BOOT button event | No LED change |
| Power | Steady **red** LED always on (3.3 V indicator — not firmware-controlled) |

If serial shows `[telemetry] published` but **no blue flash**:

1. Most boards use **GPIO48** (Arduino default — no build flag needed).
2. Some v1.1 boards use **GPIO38** — add `-DPIN_NEOPIXEL=38` to `build_flags` in `firmware/platformio.ini`.
3. Some boards need the **RGB solder pad** bridged near the LED (factory demo may work without your code if pad was pre-bridged).

Implementation: `firmware/src/status_led.cpp` via `neopixelWrite(RGB_BUILTIN, …)`.

### Recorded output — device publishing (2026-06-21)

```text
--- Terminal on /dev/ttyACM1 | 115200 8-N-1
--- Quit: Ctrl+C | Menu: Ctrl+T | Help: Ctrl+T followed by Ctrl+H
[36247][event] published topic=devices/esp32-c/events payload={"device_id":"esp32-c","ts":1782032741,"type":"button","event":"press"}
[60477][event] published topic=devices/esp32-c/events payload={"device_id":"esp32-c","ts":1782032765,"type":"button","event":"press"}
[60842][telemetry] published topic=devices/esp32-c/telemetry bytes=129
[120827][telemetry] published topic=devices/esp32-c/telemetry bytes=130
[180819][telemetry] published topic=devices/esp32-c/telemetry bytes=130
[240834][telemetry] published topic=devices/esp32-c/telemetry bytes=130
[300839][telemetry] published topic=devices/esp32-c/telemetry bytes=130
```

**What to look for:**

- `[event] published` on BOOT press
- `[telemetry] published` roughly every 60 s (`PUBLISH_INTERVAL_SEC` in `config.h`)

---

## 8. Verify cloud delivery (AWS CLI)

IoT Rules (`esp32_demo_telemetry_rule`, `esp32_demo_events_rule`) route MQTT messages to CloudWatch Logs. With the device still publishing:

```bash
export AWS_REGION=ap-southeast-2

# Live tail — Ctrl+C to stop
aws logs tail /aws/iot/esp32-demo/telemetry --follow
aws logs tail /aws/iot/esp32-demo/events --follow
```

Recent entries (last 10 minutes):

```bash
START=$(($(date +%s)*1000 - 600000))
aws logs filter-log-events --log-group-name /aws/iot/esp32-demo/telemetry --start-time "$START"
aws logs filter-log-events --log-group-name /aws/iot/esp32-demo/events --start-time "$START"
```

### Problem — CloudWatch logs empty but serial shows publishes

**Checks:**

```bash
# Wrong region is a common mistake — must match provision region
echo "$AWS_REGION"

# Rule execution errors
aws logs tail /aws/iot/esp32-demo/errors --since 1h

# Rules enabled?
aws iot get-topic-rule --rule-name esp32_demo_telemetry_rule --query 'rule.ruleDisabled'
aws iot get-topic-rule --rule-name esp32_demo_events_rule --query 'rule.ruleDisabled'
```

Both `ruleDisabled` queries should return `false`. If the errors log group has entries, fix IAM or rule config (re-run `./aws/provision-infra.sh` if infra was partially deleted).

**End-to-end lag:** allow a few seconds after serial `[telemetry] published` before entries appear in CloudWatch.

### Recorded output — telemetry log group

```bash
aws logs tail /aws/iot/esp32-demo/telemetry --follow
```

```text
2026-06-21T09:06:06.397000+00:00 esp32_demo_telemetry_rule-318512224 {"device_id":"esp32-c","ts":1782032766,"type":"connectivity","rssi":-51,"uptime_s":60,"heap_free":245704,"chip_temp_c":28.5}
2026-06-21T09:07:06.367000+00:00 esp32_demo_telemetry_rule--74325831 {"device_id":"esp32-c","ts":1782032826,"type":"connectivity","rssi":-44,"uptime_s":120,"heap_free":243872,"chip_temp_c":28.5}
2026-06-21T09:08:06.345000+00:00 esp32_demo_telemetry_rule-1255445564 {"device_id":"esp32-c","ts":1782032886,"type":"connectivity","rssi":-47,"uptime_s":180,"heap_free":244112,"chip_temp_c":28.5}
2026-06-21T09:09:06.355000+00:00 esp32_demo_telemetry_rule--1605823419 {"device_id":"esp32-c","ts":1782032946,"type":"connectivity","rssi":-44,"uptime_s":240,"heap_free":245704,"chip_temp_c":28.5}
2026-06-21T09:10:06.340000+00:00 esp32_demo_telemetry_rule--116446680 {"device_id":"esp32-c","ts":1782033006,"type":"connectivity","rssi":-48,"uptime_s":300,"heap_free":244112,"chip_temp_c":28.5}
```

### Recorded output — events log group

```bash
aws logs tail /aws/iot/esp32-demo/events --follow
```

```text
2026-06-21T09:05:41.799000+00:00 esp32_demo_events_rule--2099631500 {"device_id":"esp32-c","ts":1782032741,"type":"button","event":"press"}
2026-06-21T09:06:06.011000+00:00 esp32_demo_events_rule--1541773067 {"device_id":"esp32-c","ts":1782032765,"type":"button","event":"press"}
```

**Cross-check:** CloudWatch `ts` values match serial monitor event timestamps; telemetry arrives ~every 60 s with `type: "connectivity"` and RSSI/heap/temp fields.

---

## 9. Success criteria

| Layer | Pass condition |
|-------|----------------|
| USB | `lsusb` shows Espressif `303a:…`; serial port exists; upload does not hit `Permission denied` |
| Flash | `[SUCCESS]`; chip reports ESP32-S3 + 8 MB PSRAM |
| Device serial | `[telemetry]` every ~60 s; blue RGB flash on each publish; `[event]` on BOOT press |
| CloudWatch telemetry | JSON with `device_id`, `ts`, `type: connectivity`, metrics |
| CloudWatch events | JSON with `type: button`, `event: press` |
| End-to-end | Serial publish timestamps align with CloudWatch log timestamps |

---

## 10. Teardown (optional)

Remove AWS resources and local PEM files:

```bash
FORCE=1 REMOVE_LOCAL=1 AWS_REGION=ap-southeast-2 THING_NAME=esp32-c ./aws/deprovision.sh
```

Partial cleanup: `DEVICE_ONLY=1` or `INFRA_ONLY=1` — see [aws/README.md](../aws/README.md).

---

### Quick symptom index (Phase 1)

| Symptom | Section |
|---------|---------|
| No `/dev/ttyACM*` / no Espressif in `lsusb` | [§5 — no serial port](#problem--no-serial-port-at-all) |
| `Permission denied` on `/dev/ttyACM0` | [§5 — permission denied](#problem--permission-denied-on-devttyacm0) |
| `outdated udev.rules` | [§5 — udev warning](#problem--outdated--udevrules-warning) |
| `Failed to connect` / `No serial data received` | [§6 — first flash](#problem--connecting-then-failed-to-connect--no-serial-data-received) |
| `Invalid head of packet (0x1B)` | [§6 — invalid head](#problem--invalid-head-of-packet-0x1b) |
| Wrong env / classic ESP32 profile | [§6 — wrong env](#problem--wrong-platformio-env-esp32dev-on-s3) |
| Blank serial monitor | [§7 — blank monitor](#problem--blank-monitor-after-upload) |
| Wi-Fi / MQTT stuck | [§7 — Wi-Fi or MQTT](#problem--wi-fi-or-mqtt-never-connects) |
| CloudWatch empty | [§8 — empty logs](#problem--cloudwatch-logs-empty-but-serial-shows-publishes) |
| No blue LED on telemetry | [§7 — status LED](#status-led-telemetry-sent) |

---

## Phase 2 — Serverless Ingest (Terraform)

Phase 2 manages shared AWS infra with Terraform: CloudWatch log groups, IoT Rules (CloudWatch + Lambda fan-out), Lambda processor, and DynamoDB tables. Per-device provisioning (Thing, certs, headers) stays in bootstrap scripts.

**Prerequisites:** Phase 1 gate passed (device publish + CloudWatch verification); `terraform` >= 1.5; AWS credentials for `ap-southeast-2`.

### Checklist

1. [Initialize Terraform](#initialize-terraform)
2. [Apply stack](#apply-stack)
3. [Capture outputs](#capture-outputs)
4. [Device workflow](#device-workflow-phase-2)
5. [Gate validation](#gate-validation)
6. [Teardown](#teardown-phase-2)

### Initialize Terraform

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
terraform -chdir=terraform init
```

Edit `terraform/terraform.tfvars` if needed (`environment`, `aws_region`, `billing_mode`). Stable MQTT topic patterns default to Phase 1 contracts.

### Apply stack

```bash
terraform -chdir=terraform plan
terraform -chdir=terraform apply
```

Provisions:

- CloudWatch log groups `/aws/iot/esp32-demo/{telemetry,events,errors}`
- IoT Rules `esp32_demo_telemetry_rule`, `esp32_demo_events_rule` (CloudWatch + Lambda actions)
- IAM role `esp32-demo-iot-rule-role`
- Lambda `esp32-demo-<env>-lambda-processor`
- DynamoDB tables `esp32-demo-<env>-telemetry`, `esp32-demo-<env>-events`

All resources are destroyable via `terraform destroy` (no deletion protection on DynamoDB; IAM roles use `force_detach_policies`).

Module layout: see [terraform/README.md](../terraform/README.md).

### Capture outputs

```bash
terraform -chdir=terraform output
terraform -chdir=terraform output -json > terraform/outputs.dev.json
```

Important outputs:

- `aws_iot_endpoint`
- `lambda_processor_arn`
- `telemetry_table_name`
- `events_table_name`

### Device workflow (Phase 2)

Per-device credentials are unchanged — bootstrap scripts only:

```bash
export WIFI_SSID="your-ssid"
export WIFI_PASSWORD="your-password"
export THING_NAME="esp32-c"
export AWS_REGION=ap-southeast-2

./aws/provision-device.sh
./scripts/generate-headers.sh
pio run -d firmware -e esp32-s3-n16r8 -t upload
pio device monitor -d firmware -b 115200
```

Use `aws_iot_endpoint` from Terraform output when regenerating headers if not auto-fetched.

### Gate validation

With the device publishing:

1. Serial monitor shows `[telemetry]` / `[event]` lines.
2. CloudWatch still receives telemetry and events (Phase 1 verification path preserved).
3. DynamoDB receives rows written by Lambda (new Phase 2 path).

```bash
export AWS_REGION=ap-southeast-2

# CloudWatch (must still work)
aws logs tail /aws/iot/esp32-demo/telemetry --since 10m
aws logs tail /aws/iot/esp32-demo/events --since 10m

# DynamoDB (Phase 2 ingest)
TELEMETRY_TABLE="$(terraform -chdir=terraform output -raw telemetry_table_name)"
EVENTS_TABLE="$(terraform -chdir=terraform output -raw events_table_name)"

aws dynamodb scan --table-name "$TELEMETRY_TABLE" --max-items 5
aws dynamodb scan --table-name "$EVENTS_TABLE" --max-items 5
```

CloudWatch output matches [Phase 1 §8](#8-verify-cloud-delivery-aws-cli). Device serial shows the same `[telemetry]` / `[event]` lines plus blue LED flash on publish.

### Recorded output — DynamoDB events table

```text
"Count": 1,
"Items": [
  {
    "device_id": { "S": "esp32-c" },
    "record_type": { "S": "event" },
    "effective_ts": { "N": "1782036168" },
    "ts_fallback_used": { "BOOL": false },
    "payload": {
      "device_id": "esp32-c",
      "ts": 1782036168,
      "type": "button",
      "event": "press"
    }
  }
]
```

### Recorded output — DynamoDB telemetry table

```text
"Count": 2,
"Items": [
  {
    "device_id": { "S": "esp32-c" },
    "record_type": { "S": "telemetry" },
    "effective_ts": { "N": "1782036210" },
    "ts_fallback_used": { "BOOL": false },
    "payload": {
      "device_id": "esp32-c",
      "ts": 1782036210,
      "type": "connectivity",
      "rssi": -49,
      "uptime_s": 60,
      "heap_free": 245672,
      "chip_temp_c": 33.5
    }
  },
  {
    "device_id": { "S": "esp32-c" },
    "record_type": { "S": "telemetry" },
    "effective_ts": { "N": "1782036270" },
    "payload": {
      "device_id": "esp32-c",
      "ts": 1782036270,
      "type": "connectivity",
      "rssi": -50,
      "uptime_s": 120,
      "heap_free": 245672,
      "chip_temp_c": 31.5
    }
  }
]
```

**Cross-check:** CloudWatch `ts` values match DynamoDB `effective_ts` and serial publish timestamps; telemetry arrives ~every 60 s on both CloudWatch and DynamoDB paths.

**Phase 2 success criteria:**

| Layer | Pass condition |
|-------|----------------|
| CloudWatch telemetry | JSON payloads in `/aws/iot/esp32-demo/telemetry` |
| CloudWatch events | JSON payloads in `/aws/iot/esp32-demo/events` |
| DynamoDB telemetry | Rows in telemetry table with `device_id`, `effective_ts`, `payload` |
| DynamoDB events | Rows in events table for BOOT presses |
| End-to-end | Serial publish → CloudWatch log + DynamoDB row within a few seconds |

**Notes:**

- Lambda `ts=0` fallback writes `effective_ts=ingest_ts` and sets `ts_fallback_used=true`.
- DynamoDB uses dual tables with GSI `device_ts_idx` (`device_id` + `effective_ts`).

### Teardown (Phase 2)

Remove Terraform-managed shared infra:

```bash
terraform -chdir=terraform destroy
```

Per-device resources (Thing, certs, local PEMs) are removed separately:

```bash
FORCE=1 REMOVE_LOCAL=1 AWS_REGION=ap-southeast-2 THING_NAME=esp32-c ./aws/deprovision.sh
```

Partial cleanup options: [aws/README.md](../aws/README.md) (`DEVICE_ONLY`, `INFRA_ONLY`).

---

## Phase 3 — API + Amplify Dashboard

Phase 3 adds a read-only Query API and dashboard on top of Phase 2 data:

- API Gateway routes:
  - `GET /devices/{deviceId}/telemetry/latest`
  - `GET /devices/{deviceId}/events?limit=N`
- Query Lambda reads DynamoDB (no direct browser access to DynamoDB)
- Optional Amplify hosting for the `web/` dashboard app (manual deploy on apply — no Git repo/token)

### Phase 3 checklist

1. [Apply Terraform with Phase 3 modules](#apply-terraform-phase-3)
2. [Validate Query API responses](#validate-query-api)
3. [Run dashboard locally](#run-dashboard-locally)
4. [Amplify hosting](#amplify-hosting)
5. [Phase 3 gate validation](#phase-3-gate-validation)

### Apply Terraform (Phase 3)

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
terraform -chdir=terraform init
terraform -chdir=terraform plan
terraform -chdir=terraform apply
```

After apply, Terraform automatically builds and deploys `web/` to Amplify when `deploy_amplify_on_apply = true` (default). No GitHub repo or access token is required.

To skip the frontend deploy during apply (for example CI without Node.js):

```bash
terraform apply -var='deploy_amplify_on_apply=false'
# deploy later:
API_URL="$(terraform -chdir=terraform output -raw query_api_invoke_url)"
AMPLIFY_APP_ID="$(terraform -chdir=terraform output -raw amplify_app_id)"
AMPLIFY_BRANCH=main VITE_API_URL="${API_URL}" ./scripts/deploy-amplify.sh
```

### Validate Query API

Get the API base URL:

```bash
API_URL="$(terraform -chdir=terraform output -raw query_api_invoke_url)"
```

Query latest telemetry and recent events:

```bash
curl -s "${API_URL}/devices/esp32-c/telemetry/latest" | jq .
curl -s "${API_URL}/devices/esp32-c/events?limit=10" | jq .
```

Expected:

- HTTP 200 with telemetry payload fields (`rssi`, `uptime_s`, `heap_free`, `chip_temp_c`)
- HTTP 200 with `events` list for button presses
- HTTP 404 for unknown devices with no data

### Run dashboard locally

```bash
cd web
npm ci
VITE_API_URL="$(terraform -chdir=../terraform output -raw query_api_invoke_url)" npm run dev
```

Open the local Vite URL and enter a device id (for example `esp32-c`).

Dashboard shows:

- Device status header (`device_id`, last seen)
- Latest telemetry card
- Recent events list
- Polling refresh (default 15s)

### Amplify hosting

Amplify app and branch are created on every apply. With `deploy_amplify_on_apply=true` (default), `./scripts/deploy-amplify.sh` runs after apply so you do not get the Amplify Welcome placeholder page.

```bash
terraform -chdir=terraform output amplify_app_url
```

That URL serves the dashboard with `VITE_API_URL` wired from the Query API output.

### Phase 3 gate validation

1. ESP32 continues publishing telemetry/events.
2. DynamoDB updates via Phase 2 ingest path.
3. Query API returns latest telemetry + recent events.
4. Dashboard renders live data from Query API (local and/or Amplify URL).
5. Browser never calls DynamoDB directly.
