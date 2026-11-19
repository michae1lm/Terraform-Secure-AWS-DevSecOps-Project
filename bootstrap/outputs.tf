output "aws_account_id" {
  value = data.aws_caller_identity.current.account_id
}
output "region" {
  value = var.aws_region
}
output "state_bucket_name" {
  value = aws_s3_bucket.state.id
}
output "state_kms_key_arn" {
  value = aws_kms_key.state.arn
}
output "plan_role_arn" {
  value = module.github_oidc.plan_role_arn
}
output "apply_role_arn" {
  value = module.github_oidc.apply_role_arn
}
