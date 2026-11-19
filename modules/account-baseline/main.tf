resource "aws_s3_account_public_access_block" "this" {
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_kms_key" "ebs" {
  description             = "EBS customer-managed default encryption key for personal lab"
  enable_key_rotation     = true
  deletion_window_in_days = 30
}

resource "aws_kms_alias" "ebs" {
  name          = var.ebs_key_alias
  target_key_id = aws_kms_key.ebs.key_id
}

resource "aws_ebs_encryption_by_default" "this" {
  enabled = true
}

resource "aws_ebs_default_kms_key" "this" {
  key_arn = aws_kms_key.ebs.arn
  depends_on = [aws_ebs_encryption_by_default.this]
}

# Account-wide change. Use only in a dedicated lab account.
resource "aws_iam_account_password_policy" "this" {
  minimum_password_length        = 14
  require_lowercase_characters   = true
  require_uppercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  allow_users_to_change_password = true
  max_password_age               = 90
  password_reuse_prevention      = 24
}
