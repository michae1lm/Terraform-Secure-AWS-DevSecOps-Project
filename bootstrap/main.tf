data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  account_id   = data.aws_caller_identity.current.account_id
  state_bucket = "tfsec-state-${local.account_id}-${var.bucket_suffix}"
  access_logs  = "tfsec-state-logs-${local.account_id}-${var.bucket_suffix}"
}

resource "aws_kms_key" "state" {
  description             = "KMS key for personal Terraform remote state"
  enable_key_rotation     = true
  deletion_window_in_days = 30
}

resource "aws_kms_alias" "state" {
  name          = "alias/tfsec-state"
  target_key_id = aws_kms_key.state.key_id
}

# State server-access-logging destination must be a different bucket.
resource "aws_s3_bucket" "state_access_logs" {
  bucket        = local.access_logs
  force_destroy = false
}

resource "aws_s3_bucket_public_access_block" "state_access_logs" {
  bucket                  = aws_s3_bucket.state_access_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "state_access_logs" {
  bucket = aws_s3_bucket.state_access_logs.id
  rule { object_ownership = "BucketOwnerEnforced" }
}

resource "aws_s3_bucket_versioning" "state_access_logs" {
  bucket = aws_s3_bucket.state_access_logs.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state_access_logs" {
  bucket = aws_s3_bucket.state_access_logs.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "state_access_logs" {
  bucket = aws_s3_bucket.state_access_logs.id
  rule {
    id     = "expire-access-logs"
    status = "Enabled"
    filter {}
    expiration { days = 30 }
    noncurrent_version_expiration { noncurrent_days = 30 }
  }
  depends_on = [aws_s3_bucket_versioning.state_access_logs]
}

data "aws_iam_policy_document" "state_access_logs" {
  statement {
    sid     = "AllowServerAccessLogging"
    effect  = "Allow"
    actions = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.state_access_logs.arn}/state/*"]
    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }
    condition {
      test = "ArnLike"
      variable = "aws:SourceArn"
      values = ["arn:aws:s3:::${local.state_bucket}"]
    }
    condition {
      test = "StringEquals"
      variable = "aws:SourceAccount"
      values = [local.account_id]
    }
  }
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [aws_s3_bucket.state_access_logs.arn, "${aws_s3_bucket.state_access_logs.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "state_access_logs" {
  bucket = aws_s3_bucket.state_access_logs.id
  policy = data.aws_iam_policy_document.state_access_logs.json
}

resource "aws_s3_bucket" "state" {
  bucket        = local.state_bucket
  force_destroy = false
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "state" {
  bucket = aws_s3_bucket.state.id
  rule { object_ownership = "BucketOwnerEnforced" }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.state.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_logging" "state" {
  bucket        = aws_s3_bucket.state.id
  target_bucket = aws_s3_bucket.state_access_logs.id
  target_prefix = "state/"
  depends_on    = [aws_s3_bucket_policy.state_access_logs]
}

data "aws_iam_policy_document" "state" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = data.aws_iam_policy_document.state.json
}

# Bootstrap security principals use local, administrator-controlled state. The
# deploy workflow cannot alter its own trust policies or administrator roles.
module "github_oidc" {
  source              = "../modules/github-oidc"
  account_id          = local.account_id
  github_owner        = var.github_owner
  github_repo         = var.github_repo
  state_bucket_name   = aws_s3_bucket.state.id
  state_key           = "dev/terraform.tfstate"
  state_kms_key_arn   = aws_kms_key.state.arn
}
