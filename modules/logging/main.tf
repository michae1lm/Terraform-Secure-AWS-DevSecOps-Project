locals {
  trail_arn      = "arn:aws:cloudtrail:${var.aws_region}:${var.account_id}:trail/${var.trail_name}"
  log_bucket     = "tfsec-trail-${var.account_id}-${var.aws_region}"
  access_logs    = "tfsec-access-${var.account_id}-${var.aws_region}"
  cw_log_group   = "/aws/cloudtrail/tfsec-lab"
}

data "aws_iam_policy_document" "kms_logs" {
  statement {
    sid       = "EnableAccountIAMAdministration"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_id}:root"]
    }
  }
  statement {
    sid       = "AllowCloudTrailToEncryptTrail"
    effect    = "Allow"
    actions   = ["kms:GenerateDataKey*", "kms:Decrypt", "kms:DescribeKey"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = [local.trail_arn]
    }
    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:cloudtrail:arn"
      values   = ["arn:aws:cloudtrail:*:${var.account_id}:trail/*"]
    }
  }
  statement {
    sid       = "AllowCloudWatchLogsEncryption"
    effect    = "Allow"
    actions   = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["logs.${var.aws_region}.amazonaws.com"]
    }
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${var.aws_region}:${var.account_id}:log-group:/aws/*"]
    }
  }
}

resource "aws_kms_key" "logs" {
  description             = "CloudTrail and CloudWatch log encryption key"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.kms_logs.json
}

resource "aws_kms_alias" "logs" {
  name          = "alias/tfsec-logs"
  target_key_id = aws_kms_key.logs.key_id
}

# Dedicated destination for S3 server access logs, to avoid recursive logging.
resource "aws_s3_bucket" "access_logs" {
  bucket        = local.access_logs
  force_destroy = false
}

resource "aws_s3_bucket_public_access_block" "access_logs" {
  bucket                  = aws_s3_bucket.access_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  rule { object_ownership = "BucketOwnerEnforced" }
}

resource "aws_s3_bucket_versioning" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  rule {
    id     = "expire-lab-access-logs"
    status = "Enabled"
    filter {}
    expiration { days = var.retention_days }
    noncurrent_version_expiration { noncurrent_days = 30 }
  }
  depends_on = [aws_s3_bucket_versioning.access_logs]
}

data "aws_iam_policy_document" "access_logs" {
  statement {
    sid       = "AllowServerAccessLogDelivery"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.access_logs.arn}/${local.log_bucket}/*"]
    principals {
      type        = "Service"
      identifiers = ["logging.s3.amazonaws.com"]
    }
    condition {
      test = "ArnLike"
      variable = "aws:SourceArn"
      values = ["arn:aws:s3:::${local.log_bucket}"]
    }
    condition {
      test = "StringEquals"
      variable = "aws:SourceAccount"
      values = [var.account_id]
    }
  }
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.access_logs.arn, "${aws_s3_bucket.access_logs.arn}/*"]
    principals { type = "*" identifiers = ["*"] }
    condition { test = "Bool" variable = "aws:SecureTransport" values = ["false"] }
  }
}

resource "aws_s3_bucket_policy" "access_logs" {
  bucket = aws_s3_bucket.access_logs.id
  policy = data.aws_iam_policy_document.access_logs.json
}

data "aws_iam_policy_document" "cloudtrail_bucket" {
  statement {
    sid       = "AWSCloudTrailAclCheck"
    effect    = "Allow"
    actions   = ["s3:GetBucketAcl"]
    resources = ["arn:aws:s3:::${local.log_bucket}"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition { test = "StringEquals" variable = "aws:SourceArn" values = [local.trail_arn] }
  }
  statement {
    sid       = "AWSCloudTrailWrite"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["arn:aws:s3:::${local.log_bucket}/AWSLogs/${var.account_id}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition { test = "StringEquals" variable = "aws:SourceArn" values = [local.trail_arn] }
    condition { test = "StringEquals" variable = "s3:x-amz-acl" values = ["bucket-owner-full-control"] }
  }
}

module "trail_bucket" {
  source                  = "../secure-s3"
  bucket_name             = local.log_bucket
  kms_key_arn             = aws_kms_key.logs.arn
  additional_policy_json  = data.aws_iam_policy_document.cloudtrail_bucket.json
  access_log_bucket       = aws_s3_bucket.access_logs.id
  lifecycle_days          = var.retention_days
  depends_on              = [aws_s3_bucket_policy.access_logs]
}

resource "aws_cloudwatch_log_group" "cloudtrail" {
  name              = local.cw_log_group
  retention_in_days = var.retention_days
  kms_key_id        = aws_kms_key.logs.arn
}

data "aws_iam_policy_document" "trail_cw_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals { type = "Service" identifiers = ["cloudtrail.amazonaws.com"] }
  }
}

resource "aws_iam_role" "trail_cloudwatch" {
  name               = "tfsec-workload-cloudtrail-cw"
  assume_role_policy = data.aws_iam_policy_document.trail_cw_trust.json
}

data "aws_iam_policy_document" "trail_to_cw" {
  statement {
    effect = "Allow"
    actions = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.cloudtrail.arn}:log-stream:*"]
  }
}

resource "aws_iam_role_policy" "trail_to_cw" {
  name   = "tfsec-trail-to-cw"
  role   = aws_iam_role.trail_cloudwatch.id
  policy = data.aws_iam_policy_document.trail_to_cw.json
}

resource "aws_cloudtrail" "main" {
  name                          = var.trail_name
  s3_bucket_name                = module.trail_bucket.bucket_id
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true
  enable_logging                = true
  kms_key_id                    = aws_kms_key.logs.arn
  cloud_watch_logs_group_arn    = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn     = aws_iam_role.trail_cloudwatch.arn
  depends_on = [module.trail_bucket, aws_iam_role_policy.trail_to_cw]
}
