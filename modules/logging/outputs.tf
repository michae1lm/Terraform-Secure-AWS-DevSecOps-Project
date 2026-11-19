output "kms_key_arn" { value = aws_kms_key.logs.arn }
output "trail_arn" { value = aws_cloudtrail.main.arn }
output "log_bucket_name" { value = module.trail_bucket.bucket_id }
