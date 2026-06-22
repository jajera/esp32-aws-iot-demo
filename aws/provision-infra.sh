#!/usr/bin/env bash
# Deploy Phase 1 shared infra (IAM, log groups, IoT Rules) via CloudFormation.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

: "${AWS_REGION:?Set AWS_REGION}"

STACK_NAME="${STACK_NAME:-esp32-demo-phase1}"
ROLE_NAME="${ROLE_NAME:-esp32-demo-iot-rule-role}"
TEMPLATE="${SCRIPT_DIR}/cloudformation/phase1-infra.yaml"

if [[ ! -f "${TEMPLATE}" ]]; then
  echo "Missing CloudFormation template: ${TEMPLATE}" >&2
  exit 1
fi

stack_exists() {
  aws cloudformation describe-stacks \
    --region "${AWS_REGION}" \
    --stack-name "${STACK_NAME}" >/dev/null 2>&1
}

legacy_infra_exists() {
  aws iam get-role --role-name "${ROLE_NAME}" >/dev/null 2>&1
}

if ! stack_exists && legacy_infra_exists; then
  echo "Orphaned CLI-created infra detected (not managed by CloudFormation stack ${STACK_NAME})." >&2
  echo "Remove it first, then re-run this script:" >&2
  echo "  FORCE=1 INFRA_ONLY=1 AWS_REGION=${AWS_REGION} ${SCRIPT_DIR}/deprovision.sh" >&2
  exit 1
fi

echo "Deploying shared infra stack: ${STACK_NAME}"
aws cloudformation deploy \
  --region "${AWS_REGION}" \
  --stack-name "${STACK_NAME}" \
  --template-file "${TEMPLATE}" \
  --capabilities CAPABILITY_NAMED_IAM \
  --no-fail-on-empty-changeset

echo "Shared infra ready (stack: ${STACK_NAME})."
