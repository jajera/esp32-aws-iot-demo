#!/usr/bin/env bash
# Phase 1 bootstrap: shared infra (CloudFormation) then per-device Thing/cert/policy.
# Shared infra moves to terraform/ in Phase 2. See aws/README.md and .kiro/specs/.
set -euo pipefail

# Usage:
#   AWS_REGION=ap-southeast-2 THING_NAME=esp32-c ./aws/provision.sh
#
# Teardown (reverse):
#   FORCE=1 AWS_REGION=ap-southeast-2 THING_NAME=esp32-c ./aws/deprovision.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

: "${AWS_REGION:?Set AWS_REGION}"
: "${THING_NAME:?Set THING_NAME}"

echo "=== Shared infra (CloudFormation) ==="
"${SCRIPT_DIR}/provision-infra.sh"

echo ""
echo "=== Device (${THING_NAME}) ==="
"${SCRIPT_DIR}/provision-device.sh"

echo ""
echo "Provisioning complete."
