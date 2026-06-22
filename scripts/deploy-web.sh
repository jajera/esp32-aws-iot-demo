#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="${ROOT_DIR}/terraform"

echo "Apply Terraform (API + Amplify deploy on apply by default)"
terraform -chdir="${TF_DIR}" init
terraform -chdir="${TF_DIR}" apply

echo "Key outputs:"
terraform -chdir="${TF_DIR}" output query_api_invoke_url
terraform -chdir="${TF_DIR}" output amplify_app_url

echo "Done."
