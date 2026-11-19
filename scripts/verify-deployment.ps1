# Run AFTER apply. This script makes read-only calls, not configuration changes.
$ErrorActionPreference = 'Stop'
$region = 'us-west-2'
Write-Host '--- AWS principal ---'
aws sts get-caller-identity
Write-Host '--- CloudTrail status ---'
aws cloudtrail get-trail-status --name tfsec-management-trail --region $region
Write-Host '--- GuardDuty detector IDs ---'
aws guardduty list-detectors --region $region
Write-Host '--- Account S3 public access block ---'
$account = aws sts get-caller-identity --query Account --output text
aws s3control get-public-access-block --account-id $account --region $region
Write-Host '--- Default EBS encryption ---'
aws ec2 get-ebs-encryption-by-default --region $region
Write-Host '--- Default IAM password policy ---'
aws iam get-account-password-policy
Write-Host '--- VPC resources ---'
terraform -chdir=envs/dev output
Write-Host 'Read-only evidence collected. Save/redact the output before publishing.'
