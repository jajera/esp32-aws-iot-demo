#!/usr/bin/env bash
# Per-device AWS IoT Thing, certificate, and policy.
set -euo pipefail

: "${AWS_REGION:?Set AWS_REGION}"
: "${THING_NAME:?Set THING_NAME}"

CERT_DIR="${CERT_DIR:-firmware/certs}"
GEN_DIR="${GEN_DIR:-aws/generated}"
POLICY_NAME="${POLICY_NAME:-${THING_NAME}-policy}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"

mkdir -p "${CERT_DIR}" "${GEN_DIR}"

echo "1) Creating IoT Thing: ${THING_NAME}"
aws iot create-thing --thing-name "${THING_NAME}" >/dev/null 2>&1 || \
  aws iot describe-thing --thing-name "${THING_NAME}" >/dev/null

echo "2) Creating and activating certificate/key"
CERT_ARN="$(aws iot create-keys-and-certificate \
  --set-as-active \
  --certificate-pem-outfile "${CERT_DIR}/${THING_NAME}.cert.pem" \
  --public-key-outfile "${CERT_DIR}/${THING_NAME}.public.key" \
  --private-key-outfile "${CERT_DIR}/${THING_NAME}.private.key" \
  --query certificateArn --output text)"

echo "3) Creating least-privilege IoT policy: ${POLICY_NAME}"
cat > "${GEN_DIR}/${POLICY_NAME}.json" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "iot:Connect",
      "Resource": "arn:aws:iot:${AWS_REGION}:${ACCOUNT_ID}:client/\${iot:Connection.Thing.ThingName}"
    },
    {
      "Effect": "Allow",
      "Action": "iot:Publish",
      "Resource": [
        "arn:aws:iot:${AWS_REGION}:${ACCOUNT_ID}:topic/devices/\${iot:Connection.Thing.ThingName}/telemetry",
        "arn:aws:iot:${AWS_REGION}:${ACCOUNT_ID}:topic/devices/\${iot:Connection.Thing.ThingName}/events"
      ]
    }
  ]
}
EOF

if aws iot get-policy --policy-name "${POLICY_NAME}" >/dev/null 2>&1; then
  aws iot create-policy-version \
    --policy-name "${POLICY_NAME}" \
    --policy-document "file://${GEN_DIR}/${POLICY_NAME}.json" \
    --set-as-default >/dev/null
else
  aws iot create-policy --policy-name "${POLICY_NAME}" \
    --policy-document "file://${GEN_DIR}/${POLICY_NAME}.json" >/dev/null
fi

echo "4) Attaching policy to certificate"
aws iot attach-policy --policy-name "${POLICY_NAME}" --target "${CERT_ARN}" 2>/dev/null || true

echo "5) Attaching certificate to thing"
aws iot attach-thing-principal --thing-name "${THING_NAME}" --principal "${CERT_ARN}" 2>/dev/null || true

echo "6) Resolving IoT Data endpoint"
IOT_ENDPOINT="$(aws iot describe-endpoint --endpoint-type iot:Data-ATS --query endpointAddress --output text)"
echo "AWS_IOT_ENDPOINT=${IOT_ENDPOINT}"

echo "7) Downloading AmazonRootCA1.pem"
curl -fsSL https://www.amazontrust.com/repository/AmazonRootCA1.pem -o "${CERT_DIR}/AmazonRootCA1.pem"

echo "Device provisioning complete."
echo "Thing: ${THING_NAME}"
echo "Endpoint: ${IOT_ENDPOINT}"
echo "Cert files: ${CERT_DIR}"
