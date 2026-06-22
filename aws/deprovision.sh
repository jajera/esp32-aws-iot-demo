#!/usr/bin/env bash
# Reverse of provision.sh — tear down Phase 1 AWS resources in dependency order.
# See aws/README.md.
set -euo pipefail

# Usage:
#   FORCE=1 AWS_REGION=ap-southeast-2 THING_NAME=esp32-c ./aws/deprovision.sh
#
# Optional:
#   DEVICE_ONLY=1  — Thing, cert(s), policy only (keep rules, IAM role, log groups)
#   INFRA_ONLY=1   — rules, IAM role, log groups only (THING_NAME not required)
#   REMOVE_LOCAL=1 — also delete local PEM files and generated JSON for this thing

if [[ "${FORCE:-}" != "1" ]]; then
  echo "Refusing to run without FORCE=1 (destructive)." >&2
  echo "Example: FORCE=1 AWS_REGION=ap-southeast-2 THING_NAME=esp32-c ./aws/deprovision.sh" >&2
  exit 1
fi

: "${AWS_REGION:?Set AWS_REGION}"

DEVICE_ONLY="${DEVICE_ONLY:-0}"
INFRA_ONLY="${INFRA_ONLY:-0}"
REMOVE_LOCAL="${REMOVE_LOCAL:-0}"

if [[ "${DEVICE_ONLY}" == "1" && "${INFRA_ONLY}" == "1" ]]; then
  echo "Set at most one of DEVICE_ONLY or INFRA_ONLY." >&2
  exit 1
fi

if [[ "${INFRA_ONLY}" != "1" ]]; then
  : "${THING_NAME:?Set THING_NAME (or INFRA_ONLY=1 for shared infra only)}"
fi

CERT_DIR="${CERT_DIR:-firmware/certs}"
GEN_DIR="${GEN_DIR:-aws/generated}"
POLICY_NAME="${POLICY_NAME:-${THING_NAME}-policy}"
ROLE_NAME="${ROLE_NAME:-esp32-demo-iot-rule-role}"
STACK_NAME="${STACK_NAME:-esp32-demo-phase1}"
TELEMETRY_RULE_NAME="${TELEMETRY_RULE_NAME:-esp32_demo_telemetry_rule}"
EVENTS_RULE_NAME="${EVENTS_RULE_NAME:-esp32_demo_events_rule}"
LOG_GROUPS=(
  /aws/iot/esp32-demo/telemetry
  /aws/iot/esp32-demo/events
  /aws/iot/esp32-demo/errors
)

cert_id_from_arn() {
  echo "${1##*/}"
}

delete_iot_rules() {
  echo "1) Deleting IoT topic rules"
  aws iot delete-topic-rule --rule-name "${TELEMETRY_RULE_NAME}" >/dev/null 2>&1 || true
  aws iot delete-topic-rule --rule-name "${EVENTS_RULE_NAME}" >/dev/null 2>&1 || true
}

detach_policy_from_all_targets() {
  local targets
  targets="$(aws iot list-targets-for-policy --policy-name "${POLICY_NAME}" \
    --query 'targets[]' --output text 2>/dev/null || true)"
  if [[ -z "${targets}" || "${targets}" == "None" ]]; then
    return 0
  fi
  for target in ${targets}; do
    echo "   Detaching policy ${POLICY_NAME} from ${target}"
    aws iot detach-policy --policy-name "${POLICY_NAME}" --target "${target}" >/dev/null 2>&1 || true
  done
}

delete_certificate() {
  local cert_arn="$1"
  local cert_id
  cert_id="$(cert_id_from_arn "${cert_arn}")"

  echo "   Detaching and deleting certificate ${cert_id}"
  aws iot detach-policy --policy-name "${POLICY_NAME}" --target "${cert_arn}" >/dev/null 2>&1 || true
  if [[ -n "${THING_NAME:-}" ]]; then
    aws iot detach-thing-principal --thing-name "${THING_NAME}" --principal "${cert_arn}" >/dev/null 2>&1 || true
  fi
  aws iot update-certificate --certificate-id "${cert_id}" --new-status INACTIVE >/dev/null 2>&1 || true
  aws iot delete-certificate --certificate-id "${cert_id}" >/dev/null 2>&1 || true
}

delete_device_resources() {
  echo "2) Removing device resources for Thing: ${THING_NAME}"

  local principals
  principals="$(aws iot list-thing-principals --thing-name "${THING_NAME}" \
    --query 'principals[]' --output text 2>/dev/null || true)"
  if [[ -n "${principals}" && "${principals}" != "None" ]]; then
    for cert_arn in ${principals}; do
      delete_certificate "${cert_arn}"
    done
  else
    echo "   No principals on thing (may already be removed)"
  fi

  detach_policy_from_all_targets

  echo "3) Deleting IoT policy: ${POLICY_NAME}"
  aws iot delete-policy --policy-name "${POLICY_NAME}" >/dev/null 2>&1 || true

  echo "4) Deleting IoT thing: ${THING_NAME}"
  aws iot delete-thing --thing-name "${THING_NAME}" >/dev/null 2>&1 || true
}

delete_shared_infra() {
  if aws cloudformation describe-stacks \
      --stack-name "${STACK_NAME}" >/dev/null 2>&1; then
    echo "5) Deleting CloudFormation stack: ${STACK_NAME}"
    aws cloudformation delete-stack --stack-name "${STACK_NAME}"
    aws cloudformation wait stack-delete-complete --stack-name "${STACK_NAME}"
    return 0
  fi

  echo "5) Deleting legacy CLI-created shared infra (no CloudFormation stack)"
  delete_iot_rules
  aws iam delete-role-policy --role-name "${ROLE_NAME}" --policy-name "${ROLE_NAME}-logs" >/dev/null 2>&1 || true
  aws iam delete-role --role-name "${ROLE_NAME}" >/dev/null 2>&1 || true

  echo "6) Deleting CloudWatch log groups"
  for log_group in "${LOG_GROUPS[@]}"; do
    echo "   ${log_group}"
    aws logs delete-log-group --log-group-name "${log_group}" >/dev/null 2>&1 || true
  done
}

remove_local_artifacts() {
  echo "7) Removing local certificate and generated files"
  rm -f \
    "${CERT_DIR}/${THING_NAME}.cert.pem" \
    "${CERT_DIR}/${THING_NAME}.public.key" \
    "${CERT_DIR}/${THING_NAME}.private.key" \
    "${GEN_DIR}/${POLICY_NAME}.json"

  # AmazonRootCA1.pem is shared; remove only when nothing else remains in CERT_DIR.
  if [[ -d "${CERT_DIR}" ]] && [[ -z "$(find "${CERT_DIR}" -mindepth 1 -maxdepth 1 2>/dev/null)" ]]; then
    rmdir "${CERT_DIR}" 2>/dev/null || true
  fi
}

if [[ "${INFRA_ONLY}" == "1" ]]; then
  delete_shared_infra
elif [[ "${DEVICE_ONLY}" == "1" ]]; then
  delete_device_resources
  if [[ "${REMOVE_LOCAL}" == "1" ]]; then
    remove_local_artifacts
  fi
else
  delete_device_resources
  delete_shared_infra
  if [[ "${REMOVE_LOCAL}" == "1" ]]; then
    remove_local_artifacts
  fi
fi

echo "Deprovisioning complete."
