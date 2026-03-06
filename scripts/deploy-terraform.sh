#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="$SCRIPT_DIR/../infrastructure/terraform"

echo "==> Running Terraform..."

cd "$TF_DIR"

terraform init -input=false
terraform apply -auto-approve -input=false
