# Linux USB Setup

ESP32-S3 N16R8 uses native USB → `/dev/ttyACM0` (`303a:1001` or `303a:4001` in `lsusb`). Classic ESP32 devkits use `/dev/ttyUSB0` and env `esp32dev`.

## One-time setup

```bash
sudo ./scripts/setup-linux-usb.sh
```

Log out and back in (or reboot), then unplug/replug the board. Re-run if PlatformIO warns udev rules are outdated.

[PlatformIO udev rules reference](https://docs.platformio.org/en/latest/core/installation/udev-rules.html)

## Verify

```bash
groups | grep dialout
lsusb
ls -l /dev/ttyACM0 /dev/ttyACM1 2>/dev/null
```

Do not use `sudo pio … upload` — fix permissions instead.

## Upload and monitor

```bash
pio run -d firmware -e esp32-s3-n16r8 -t upload
pio device monitor -d firmware -b 115200
```

**First flash:** if upload hangs at `Connecting…`, hold **BOOT**, tap **RST/EN**, release **BOOT**, retry.

**Troubleshooting** (permission denied, wrong env, port busy, charge-only cable): [WALKTHROUGH.md §5–6](WALKTHROUGH.md#5-linux-usb-setup-one-time)

**Full operator path** (provision → flash → CloudWatch): [WALKTHROUGH.md](WALKTHROUGH.md)
