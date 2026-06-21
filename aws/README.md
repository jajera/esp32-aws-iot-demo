# AWS — Phase 1 Bootstrap

Phase 1 cloud setup and per-device provisioning. Shared infra is deployed as a CloudFormation stack; Phase 2 moves long-lived resources to `terraform/`.

| Path | Purpose |
|------|---------|
| `provision.sh` | Full bootstrap: shared infra stack, then device Thing/cert/policy |
| `provision-infra.sh` | CloudFormation stack only (IAM, log groups, IoT Rules) |
| `provision-device.sh` | Per-device Thing, cert, policy only |
| `deprovision.sh` | Tear down device resources and/or CloudFormation stack |
| `cloudformation/phase1-infra.yaml` | Shared infra template (source of truth for rules + logs) |
| `rules/*.json` | Reference payloads for Phase 2 Terraform import (not used at deploy time) |
| `generated/` | Runtime-generated IoT policy JSON (gitignored) |

## Provision

Full setup (recommended):

```bash
AWS_REGION=ap-southeast-2 THING_NAME=esp32-c ./aws/provision.sh
```

Runs in order:

1. `provision-infra.sh` — CloudFormation stack `esp32-demo-phase1` (waits until IoT Rules are live)
2. `provision-device.sh` — Thing, certificate, policy, local PEM files

Outputs:

- PEM files in `firmware/certs/` (gitignored)
- `AWS_IOT_ENDPOINT=...` printed to stdout

Or run steps separately:

```bash
AWS_REGION=ap-southeast-2 ./aws/provision-infra.sh
AWS_REGION=ap-southeast-2 THING_NAME=esp32-c ./aws/provision-device.sh
```

If you previously ran the old CLI-only infra script and see an orphaned-resources error, remove legacy shared infra once, then deploy the stack. **Do not re-run `provision-device.sh` if your Thing and certs are already set up** — that would create a second certificate.

```bash
FORCE=1 INFRA_ONLY=1 AWS_REGION=ap-southeast-2 ./aws/deprovision.sh
AWS_REGION=ap-southeast-2 ./aws/provision-infra.sh
```

## Deprovision (cleanup)

`FORCE=1` is required — the script deletes AWS resources.

Full teardown (device + CloudFormation stack):

```bash
FORCE=1 AWS_REGION=ap-southeast-2 THING_NAME=esp32-c ./aws/deprovision.sh
```

Also delete local PEM files:

```bash
FORCE=1 REMOVE_LOCAL=1 AWS_REGION=ap-southeast-2 THING_NAME=esp32-c ./aws/deprovision.sh
```

Partial cleanup:

```bash
# Device only (keep CloudFormation stack)
FORCE=1 DEVICE_ONLY=1 AWS_REGION=ap-southeast-2 THING_NAME=esp32-c ./aws/deprovision.sh

# Shared infra only (delete CloudFormation stack; keep Thing/certs)
FORCE=1 INFRA_ONLY=1 AWS_REGION=ap-southeast-2 ./aws/deprovision.sh
```

## Stable rule contracts

Do not change topic patterns or SQL — Phase 2 adds Lambda actions alongside these rules:

- Telemetry: `SELECT * FROM 'devices/+/telemetry'`
- Events: `SELECT * FROM 'devices/+/events'`

Spec reference: [Kiro phase-1](../.kiro/specs/esp32-aws-iot-demo/phase-1/requirements.md)
