# From the repository root: .\scripts\configure-backend.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
    $bucket = (terraform -chdir=bootstrap output -raw state_bucket_name).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Bootstrap state bucket output not available' }
    $kms = (terraform -chdir=bootstrap output -raw state_kms_key_arn).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Bootstrap KMS key output not available' }
    $region = (terraform -chdir=bootstrap output -raw region).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Bootstrap region output not available' }
    @"
bucket       = "$bucket"
key          = "dev/terraform.tfstate"
region       = "$region"
encrypt      = true
kms_key_id   = "$kms"
use_lockfile = true
"@ | Set-Content -Path 'envs/dev/backend.hcl' -Encoding UTF8
    Write-Host 'Created envs/dev/backend.hcl (Git-ignored)'
    Write-Host 'Next: terraform -chdir=envs/dev init -backend-config=backend.hcl'
} finally {
    Pop-Location
}
