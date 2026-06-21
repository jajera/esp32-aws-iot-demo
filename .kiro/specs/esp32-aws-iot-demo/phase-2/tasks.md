# Implementation Plan — Phase 2: Serverless Ingest

> **Status:** IMPLEMENTED AND VERIFIED — runtime gate passed 2026-06-21.

## Overview

Phase 2 adds Terraform-managed serverless ingest: IoT Rule fan-out to Lambda, DynamoDB persistence, while preserving Phase 1 CloudWatch verification.

**Depends on:** [Phase 1 tasks](../phase-1/tasks.md) complete and Phase 1 gate verified.

**Master index:** [README.md](../README.md)

**Phase 1 gate status:** Passed (firmware build, device publish, CloudWatch verification already demonstrated).

## Tasks

- [x] **P2.1 Terraform root + environment layout**
  - Added `terraform/` root: backend, providers, variables, `main.tf`, outputs.
  - Added `terraform/terraform.tfvars.example` (copy to `terraform.tfvars` for plan/apply).
  - Added module composition entry point and output contract (`aws_iot_endpoint`, rule ARNs, Lambda ARN, DynamoDB table names).

- [x] **P2.2 Phase 1 shared infra modeled in Terraform**
  - Implemented Terraform resources for Phase 1 shared infra names:
    - Log groups: `/aws/iot/esp32-demo/{telemetry,events,errors}`
    - IAM role: `esp32-demo-iot-rule-role`
    - IoT rules: `esp32_demo_telemetry_rule`, `esp32_demo_events_rule`
  - Apply guide in `terraform/README.md` and `docs/WALKTHROUGH.md` (Phase 2 section).

- [x] **P2.3 DynamoDB module + table schema decision**
  - Implemented `terraform/modules/dynamodb`.
  - Chosen schema: **dual table** (`<project>-<env>-telemetry`, `<project>-<env>-events`).
  - Key strategy:
    - Primary keys: `device_id` + `record_id` (idempotent writes)
    - GSI `device_ts_idx`: `device_id` + `effective_ts` for time-ordered queries
  - `ts=0` fallback is documented and implemented in Lambda (`effective_ts=ingest_ts`).

- [x] **P2.4 Lambda processor implementation + unit tests**
  - Implemented `terraform/modules/lambda_processor` with package archive, IAM role/policy, and function resource.
  - Added handler source: `terraform/modules/lambda_processor/src/handler.py`.
  - Handler behavior:
    - Validates base fields: `device_id`, `ts`, `type`
    - Normalizes record type (`telemetry`/`event`)
    - Handles `ts=0` fallback to ingest time
    - Computes deterministic `record_id` for idempotency
    - Writes normalized records to DynamoDB
  - Added unit tests: `terraform/modules/lambda_processor/src/tests/test_handler.py`.

- [x] **P2.5 IoT Rule fan-out wiring (CloudWatch + Lambda)**
  - Implemented `terraform/modules/iot_rule_fanout`.
  - Wired both actions on both rules:
    - CloudWatch logs action (existing Phase 1 path)
    - Lambda action (new Phase 2 path)
  - Preserved error action routing to `/aws/iot/esp32-demo/errors`.
  - Added `aws_lambda_permission` for IoT rule invocation.

- [x] **P2.6 Phase 2 gate validation + docs update**
  - [x] Updated operator docs with Terraform-first workflow in `docs/WALKTHROUGH.md` (Phase 2 section).
  - [x] Runtime validation in target AWS account (2026-06-21, Thing `esp32-c`):
    - ESP32 publish → Lambda → DynamoDB row (telemetry + events)
    - CloudWatch telemetry/events path still active post-Phase 2 apply
    - Recorded output in `docs/WALKTHROUGH.md` (Phase 2 gate validation)

## Next Phase

When P2.6 passes, proceed to [Phase 3 tasks](../phase-3/tasks.md) (API + Amplify dashboard).
