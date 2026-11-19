#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
bucket="$(terraform -chdir=bootstrap output -raw state_bucket_name)"
kms="$(terraform -chdir=bootstrap output -raw state_kms_key_arn)"
region="$(terraform -chdir=bootstrap output -raw region)"
cat > envs/dev/backend.hcl <<BACKEND
bucket       = "$bucket"
key          = "dev/terraform.tfstate"
region       = "$region"
encrypt      = true
kms_key_id   = "$kms"
use_lockfile = true
BACKEND
printf '%s\n' 'Wrote ignored envs/dev/backend.hcl'
