# Terraform — Phase 2 + 3 Shared Infra

Source of truth for shared cloud resources:

- CloudWatch log groups (`/aws/iot/esp32-demo/*`)
- IoT Rules (`esp32_demo_telemetry_rule`, `esp32_demo_events_rule`)
- IoT rules IAM role (`esp32-demo-iot-rule-role`)
- Lambda processor (ingest)
- DynamoDB telemetry/events tables
- Query API Lambda + API Gateway routes
- Amplify hosting (manual deploy from `web/` on apply)

Per-device provisioning (Thing, certs, policy, local headers) stays in bootstrap scripts.

All resources are destroyable via `terraform destroy` (no deletion protection, IAM roles use `force_detach_policies`).

## Structure

- `main.tf` — module composition entry point
- `modules/dynamodb` — dual-table persistence with `device_ts_idx` GSI
- `modules/lambda_processor` — ingest Lambda + IAM + packaging
- `modules/iot_rule_fanout` — IoT Rules fan-out (CloudWatch + Lambda) + IAM role
- `modules/lambda_query_api` — read-only query Lambda for telemetry/events
- `modules/api_gateway` — HTTP API routes + CORS
- `modules/amplify_hosting` — Amplify app + branch + optional post-apply deploy
- `terraform.tfvars.example` — copy to `terraform.tfvars` before plan/apply

## Initialize

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
terraform -chdir=terraform init
```

## Configure key variables

In `terraform/terraform.tfvars`:

- `cors_allow_origins` controls API CORS.
- `deploy_amplify_on_apply` defaults to `true` — builds `web/` and uploads to Amplify after apply.
- Set `deploy_amplify_on_apply = false` if apply runs without Node.js/npm (deploy later with `./scripts/deploy-amplify.sh`).

## Plan and apply

```bash
terraform -chdir=terraform plan
terraform -chdir=terraform apply
```

Operator walkthrough: [docs/WALKTHROUGH.md](../docs/WALKTHROUGH.md).

## Destroy

```bash
terraform -chdir=terraform destroy
```

Removes log groups, IoT rules, IAM roles, Lambda, and DynamoDB tables managed by this stack.

## Key outputs for bootstrap workflows

- `aws_iot_endpoint`
- `telemetry_rule_arn`
- `events_rule_arn`
- `lambda_processor_arn`
- `lambda_query_api_arn`
- `query_api_invoke_url`
- `telemetry_table_name`
- `events_table_name`
- `amplify_app_url`

```bash
terraform -chdir=terraform output
terraform -chdir=terraform output -json > terraform/outputs.dev.json
```
