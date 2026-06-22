# Requirements Document — Phase 3: API + Amplify Dashboard

> **Status:** IMPLEMENTED IN REPO — runtime gate validation pending.

## Introduction

Phase 3 exposes persisted device data through a read-only HTTP API and a static web dashboard hosted on AWS Amplify. The browser never accesses DynamoDB directly; all reads go through API Gateway and a query Lambda. Terraform owns API, Lambda, and Amplify hosting configuration.

**Depends on:** [Phase 2 requirements](../phase-2/requirements.md) — DynamoDB tables populated by the Lambda processor must exist and contain device records.

**Master index:** [README.md](../README.md)

## Project Phases

| Phase | Scope | Spec location |
|-------|-------|---------------|
| 1 | Device + IoT baseline | [phase-1/requirements.md](../phase-1/requirements.md) |
| 2 | Serverless ingest | [phase-2/requirements.md](../phase-2/requirements.md) |
| 3 | API + Amplify dashboard (this document) | `phase-3/` |

## Stable Contracts (must not change)

Phase 3 consumes data written by Phase 2 using Phase 1 payload semantics:

- **Telemetry_Topic:** `devices/{Thing_Name}/telemetry`
- **Events_Topic:** `devices/{Thing_Name}/events`
- **Payload base fields:** `device_id`, `ts`, `type`
- **Device identifier in API:** maps to `device_id` / `Thing_Name` from Phase 1

## Glossary

- **Query_API**: The read-only HTTP API exposed via API Gateway for telemetry and event retrieval
- **Lambda_Query_API**: The serverless function that reads from DynamoDB and returns JSON responses
- **API_Gateway**: AWS API Gateway (REST or HTTP API) fronting the query Lambda
- **Amplify_Hosting**: AWS Amplify static hosting for the dashboard SPA
- **Phase_2_Gate**: Phase 2 acceptance criteria — ESP32 publish → DynamoDB row verifiable

## Requirements

### Requirement P3-1: Query API

**User Story:** As an operator, I want HTTP endpoints to retrieve device telemetry and events, so that I can inspect device state without AWS console access.

#### Acceptance Criteria

1. THE Query_API SHALL expose endpoints for latest telemetry and recent events per device `[TBD: exact paths at implementation — see design sketch]`
2. THE Query_API SHALL return JSON responses with appropriate HTTP status codes (200, 404, 400)
3. THE Query_API SHALL scope all queries by `device_id` matching Phase 1 `Thing_Name`
4. THE Query_API SHALL NOT expose write or delete operations on device data

### Requirement P3-2: API Gateway + Lambda Query

**User Story:** As a developer, I want API Gateway to invoke a read-only Lambda, so that DynamoDB is never exposed directly to the browser.

#### Acceptance Criteria

1. THE Lambda_Query_API SHALL read from DynamoDB tables created in Phase 2 with least-privilege IAM (read-only)
2. THE API_Gateway SHALL route HTTP requests to THE Lambda_Query_API with request/response mapping `[TBD: REST vs HTTP API at implementation]`
3. THE API_Gateway SHALL enable CORS for the Amplify dashboard origin `[TBD: exact origin pattern at implementation]`
4. IF a device has no records, THE Lambda_Query_API SHALL return 404 with a clear error body

### Requirement P3-3: Amplify Static Hosting

**User Story:** As an operator, I want a web dashboard hosted on Amplify, so that I can view device data in a browser with minimal hosting cost.

#### Acceptance Criteria

1. THE Amplify_Hosting SHALL deploy a static SPA built from a `web/` or equivalent directory in the repository `[TBD: framework choice at implementation]`
2. THE Amplify_Hosting SHALL serve the dashboard over HTTPS with Amplify-managed certificate
3. THE dashboard MVP SHALL display: device status summary, latest telemetry, and recent events `[TBD: polling vs refresh interval]`
4. THE dashboard SHALL NOT connect to DynamoDB or IoT Core directly

### Requirement P3-4: Environment Wiring

**User Story:** As a developer, I want the API base URL configured automatically from Terraform outputs, so that Amplify builds target the correct environment.

#### Acceptance Criteria

1. THE Terraform_Root SHALL output an API base URL consumed by Amplify build configuration
2. THE Amplify_Hosting module SHALL inject the API URL as a build-time environment variable (e.g., `VITE_API_URL` or equivalent) `[TBD: env var name at implementation]`
3. WHEN deploying to a new environment, THE operator SHALL not manually hardcode API URLs in dashboard source code
4. THE environment wiring contract SHALL be documented in operator docs `[TBD: doc path at implementation]`

### Requirement P3-5: Phase 3 Gate

**User Story:** As an operator, I want a full end-to-end demo path from device to browser, so that the project deliverable is complete.

#### Acceptance Criteria

1. WHEN an ESP32 device publishes telemetry and events, THEN the dashboard SHALL display updated data via the Query_API within `[TBD: refresh/poll interval]`
2. THE browser SHALL load the dashboard from the Amplify app URL without manual API configuration
3. THE full path ESP32 → IoT Core → Lambda processor → DynamoDB → Query API → dashboard SHALL be reproducible from documented operator steps
4. `[TBD: auth strategy at implementation]` — MVP may be open read API; document security posture explicitly

## Out of Scope (Phase 3)

- Device firmware changes (Phase 1)
- Ingest pipeline changes beyond read patterns (Phase 2)
- Real-time WebSocket push from IoT Core to browser `[TBD: future enhancement]`
- Multi-tenant user management and authentication `[TBD: future enhancement]`
