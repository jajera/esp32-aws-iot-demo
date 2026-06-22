#!/usr/bin/env bash
# One-time Linux setup: PlatformIO udev rules + dialout group for ESP32 USB upload/monitor.
# See docs/LINUX_USB.md
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run with sudo from the repo root:" >&2
  echo "  sudo ./scripts/setup-linux-usb.sh" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULES_SRC="${SCRIPT_DIR}/99-platformio-udev.rules"
RULES_DEST="/etc/udev/rules.d/99-platformio-udev.rules"
TARGET_USER="${SUDO_USER:-${USER}}"

if [[ ! -f "${RULES_SRC}" ]]; then
  echo "Missing ${RULES_SRC}" >&2
  exit 1
fi

if [[ "${TARGET_USER}" == "root" ]]; then
  echo "Run via sudo from a normal user session (SUDO_USER not set)." >&2
  exit 1
fi

echo "Installing udev rules → ${RULES_DEST}"
install -m 644 "${RULES_SRC}" "${RULES_DEST}"

echo "Reloading udev"
udevadm control --reload-rules
udevadm trigger

if id -nG "${TARGET_USER}" | grep -qw dialout; then
  echo "User ${TARGET_USER} is already in group dialout"
else
  echo "Adding ${TARGET_USER} to group dialout"
  usermod -aG dialout "${TARGET_USER}"
  NEED_RELOGIN=1
fi

echo ""
echo "Setup complete."
echo ""
echo "Next steps (required):"
echo "  1. Log out and log back in (or reboot) so group membership applies."
if [[ "${NEED_RELOGIN:-0}" == "1" ]]; then
  echo "     (Needed because dialout was just added.)"
fi
echo "  2. Unplug and replug the ESP32 USB cable."
echo "  3. Verify — see docs/LINUX_USB.md"
echo ""
echo "  groups    # must include dialout"
echo "  lsusb     # must show Espressif / CP210x / CH340 when board is connected"
echo "  ls -l /dev/ttyACM0 /dev/ttyUSB0 2>/dev/null  # port mode should allow rw"
