# Requirements Document — Phase 2: Serverless Ingest

> **Status:** IMPLEMENTED IN REPO — runtime gate validation pending.

## Introduction

Phase 2 extends the Phase 1 device-to-cloud baseline with durable storage and serverless processing. Shared AWS infrastructure (IoT Rules, IAM, CloudWatch, Lambda, DynamoDB) is managed as Terraform code. Phase 1 CloudWatch verification paths remain active; Lambda and DynamoDB are added alongside them, not as replacements.

**Depends on:** [Phase 1 requirements](../phase-1/requirements.md) — firmware, MQTT topics, payload contract, and IoT Rules → CloudWatch must be complete and verified.

**Master index:** [README.md](../README.md)

## Project Phases

| Phase | Scope | Spec location |
|-------|-------|---------------|
| 1 | Device + IoT baseline | [phase-1/requirements.md](../phase-1/requirements.md) |
| 2 | Serverless ingest (this document) | `phase-2/` |
| 3 | API + Amplify dashboard | [phase-3/requirements.md](../phase-3/requirements.md) |

## Stable Contracts (must not change)

These are locked in Phase 1 and consumed unchanged by Phase 2:

- **Telemetry_Topic:** `devices/{Thing_Name}/telemetry`
- **Events_Topic:** `devices/{Thing_Name}/events`
- **IoT Rule SQL patterns:** `SELECT * FROM 'devices/+/telemetry'` and `SELECT * FROM 'devices/+/events'`
- **Payload base fields:** `device_id`, `ts`, `type` (see [docs/PAYLOAD.md](../../../../docs/PAYLOAD.md))

## Glossary

- **Terraform_Root**: The `terraform/` directory containing environment configuration and module composition for shared AWS resources
- **IoT_Rule_Fanout**: Terraform module that configures IoT Rules with multiple actions (CloudWatch + Lambda) on existing topic patterns
- **Lambda_Processor**: The serverless function that receives IoT Rule payloads, normalizes/enriches them, and writes to DynamoDB
- **DynamoDB_Tables**: Persistent storage for telemetry and event records keyed by device and timestamp
- **Phase_1_Gate**: Acceptance criteria from Phase 1 that must pass before Phase 2 implementation begins (firmware build, device publish, CloudWatch log verification)

## Requirements

### Requirement P2-1: Terraform Foundation

**User Story:** As an operator, I want shared AWS infrastructure defined as Terraform code with environment support, so that cloud resources are reproducible and version-controlled.

#### Acceptance Criteria

1. THE Terraform_Root SHALL define shared infrastructure for IoT Rules, IAM roles/policies, CloudWatch log groups, Lambda, and DynamoDB
2. THE Terraform_Root SHALL support at least one named environment (e.g., `dev`) via variables or workspace convention `[TBD: backend strategy at implementation]`
3. THE Terraform_Root SHALL expose outputs for IoT endpoint, rule ARNs, Lambda ARNs, and table names consumed by bootstrap scripts
4. WHEN `terraform plan` runs against an environment with no drift, THE plan SHALL show no changes `[TBD: state import steps from Phase 1 CLI resources]`

### Requirement P2-2: IoT Rule Fan-Out

**User Story:** As a developer, I want IoT Rules to route messages to both CloudWatch and Lambda, so that I retain Phase 1 verification while enabling durable processing.

#### Acceptance Criteria

1. THE IoT_Rule_Fanout module SHALL preserve existing CloudWatch log actions for telemetry and events rules
2. THE IoT_Rule_Fanout module SHALL add Lambda actions on the same topic patterns without changing rule SQL statements
3. THE Telemetry_Topic and Events_Topic patterns SHALL NOT change from Phase 1 stable contracts
4. IF a Lambda action fails, THE rule error action SHALL continue routing to the Phase 1 error CloudWatch log group `[TBD: retry/DLQ strategy at implementation]`

### Requirement P2-3: Lambda Processor

**User Story:** As a developer, I want incoming device messages processed by a Lambda function, so that payloads are normalized before persistence.

#### Acceptance Criteria

1. THE Lambda_Processor SHALL receive IoT Rule payloads for both telemetry and events topics
2. THE Lambda_Processor SHALL validate presence of base schema fields (`device_id`, `ts`, `type`) before writing
3. THE Lambda_Processor SHALL perform idempotent writes to DynamoDB `[TBD: idempotency key strategy at implementation]`
4. THE Lambda_Processor SHALL log processing errors to CloudWatch Logs with sufficient context for debugging
5. THE Lambda_Processor SHALL NOT modify or republish to MQTT topics

### Requirement P2-4: DynamoDB Persistence

**User Story:** As a developer, I want device telemetry and events stored in DynamoDB, so that data is available for query APIs in Phase 3.

#### Acceptance Criteria

1. THE DynamoDB_Tables SHALL store records keyed by `device_id` and `ts` with a sort key or GSI strategy for time-ordered queries `[TBD: single-table vs dual-table at implementation]`
2. WHEN `ts` is 0 (NTP unavailable per Phase 1 Requirement 13), THE Lambda_Processor SHALL use a fallback ordering key (e.g., `uptime_s` or ingest timestamp) `[TBD: exact fallback at implementation]`
3. THE DynamoDB_Tables SHALL retain the full JSON payload or normalized subset sufficient for Phase 3 query endpoints
4. THE DynamoDB_Tables SHALL use on-demand or provisioned capacity appropriate for demo scale `[TBD: capacity mode at implementation]`

### Requirement P2-5: Phase 2 Gate

**User Story:** As an operator, I want a verifiable end-to-end ingest path, so that I know Phase 2 is complete before starting Phase 3.

#### Acceptance Criteria

1. WHEN an ESP32 device publishes telemetry, THEN a corresponding record SHALL appear in DynamoDB within `[TBD: SLA seconds]` of publish
2. WHEN an ESP32 device publishes a button event, THEN a corresponding record SHALL appear in DynamoDB
3. THE Phase 1 CloudWatch verification path SHALL continue to receive telemetry and events after Phase 2 deployment
4. THE operator workflow from Phase 1 (flash device → see cloud data) SHALL remain reproducible with updated docs `[TBD: docs path at implementation]`

## Out of Scope (Phase 2)

- REST/HTTP query API (Phase 3)
- Web dashboard or Amplify hosting (Phase 3)
- Per-device certificate generation (remains in bootstrap scripts)
- Firmware changes beyond stable contract compliance
