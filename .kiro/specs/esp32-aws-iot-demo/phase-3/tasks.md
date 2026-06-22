# Implementation Plan — Phase 3: API + Amplify Dashboard

> **Status:** IMPLEMENTED IN REPO — runtime gate validation pending.

## Overview

Phase 3 adds a read-only HTTP API (API Gateway + query Lambda) and a static dashboard on AWS Amplify.

**Depends on:** [Phase 2 tasks](../phase-2/tasks.md) complete and Phase 2 gate verified (DynamoDB populated from device publishes).

**Master index:** [README.md](../README.md)

**Phase 2 gate status:** Passed (DynamoDB populated from device publishes).

## Tasks

- [x] **P3.1 Lambda query API + DynamoDB read patterns**
  - Implemented `terraform/modules/lambda_query_api` and handler source.
  - Supports latest telemetry and recent events queries by `device_id`.
  - Added unit tests for query logic and empty-result handling.

- [x] **P3.2 API Gateway routes + CORS for Amplify origin**
  - Implemented `terraform/modules/api_gateway`.
  - Wired routes to query Lambda; CORS configurable via `cors_allow_origins`.
  - Exported `query_api_invoke_url` output for dashboard wiring.

- [x] **P3.3 Amplify app scaffold + env config from Terraform output**
  - Implemented `terraform/modules/amplify_hosting` (manual deploy from `web/` on apply; no Git repo/token).
  - Created dashboard SPA scaffold under `web/` (Vite).
  - API base URL wiring via build-time env variable (`VITE_API_URL` by default).

- [x] **P3.4 Minimal dashboard UI (telemetry + events)**
  - Device status header, latest telemetry card, recent events list.
  - Periodic polling against Query API endpoints.
  - Handles loading, empty, and partial error states.

- [ ] **P3.5 End-to-end gate: ESP32 → DynamoDB → API → browser**
  - [x] Documented operator workflow from clone to browser dashboard (`docs/WALKTHROUGH.md`, `terraform/README.md`).
  - [ ] Pending runtime validation in target AWS account:
    - Verify full demo path with live device publishing.
    - Confirm CORS, HTTPS, and env wiring work in target environment.

## Project Complete

When P3.5 passes, the esp32-aws-iot-demo deliverable is complete: device publish → cloud ingest → persistent storage → API → dashboard.
