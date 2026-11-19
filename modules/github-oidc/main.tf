locals {
  github_repo_slug = "${var.github_owner}/${var.github_repo}"
  state_arn        = "arn:aws:s3:::${var.state_bucket_name}"
  plan_subjects = [
    "repo:${local.github_repo_slug}:pull_request",
    "repo:${local.github_repo_slug}:ref:refs/heads/main"
  ]
  apply_subject = "repo:${local.github_repo_slug}:environment:production"
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
}

data "aws_iam_policy_document" "plan_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.plan_subjects
    }
  }
}

data "aws_iam_policy_document" "apply_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [local.apply_subject]
    }
  }
}

resource "aws_iam_role" "plan" {
  name               = "tfsec-ci-plan"
  description        = "Read-only Terraform plan identity for this GitHub repository"
  assume_role_policy = data.aws_iam_policy_document.plan_trust.json
  max_session_duration = 3600
}

# Read only calls required to refresh the resources in this specific lab.
# No broad AWS managed ReadOnlyAccess policy (which can read unrelated S3 data).
data "aws_iam_policy_document" "plan_read" {
  statement {
    sid = "RefreshLabServices"
    effect = "Allow"
    actions = [
      "ec2:Describe*", "ec2:GetEbsEncryptionByDefault", "ec2:GetEbsDefaultKmsKeyId",
      "s3:GetBucket*", "s3:ListBucket", "s3:ListAllMyBuckets",
      "s3control:GetPublicAccessBlock",
      "kms:DescribeKey", "kms:GetKeyPolicy", "kms:GetKeyRotationStatus", "kms:List*",
      "cloudtrail:Describe*", "cloudtrail:Get*", "cloudtrail:List*",
      "guardduty:Describe*", "guardduty:Get*", "guardduty:List*",
      "logs:Describe*", "logs:Get*", "logs:List*",
      "iam:Get*", "iam:List*", "ssm:Describe*",
      "sts:GetCallerIdentity"
    ]
    resources = ["*"]
  }
  statement {
    sid = "ReadPublicAmazonLinuxAMIParameter"
    effect = "Allow"
    actions = ["ssm:GetParameter"]
    resources = ["arn:aws:ssm:*::parameter/aws/service/ami-amazon-linux-latest/*"]
  }
}

resource "aws_iam_role_policy" "plan_read" {
  name   = "tfsec-lab-read"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.plan_read.json
}

resource "aws_iam_role" "apply" {
  name                 = "tfsec-ci-apply"
  description          = "Protected Terraform deployment identity for personal lab"
  assume_role_policy   = data.aws_iam_policy_document.apply_trust.json
  max_session_duration = 3600
}

# An intentionally documented initial policy: PowerUserAccess is not true
# least privilege. Tighten it from real CloudTrail events before production.
resource "aws_iam_role_policy_attachment" "apply_power_user" {
  role       = aws_iam_role.apply.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

data "aws_iam_policy_document" "plan_state" {
  statement {
    sid       = "ReadStateBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [local.state_arn]
    condition {
      test = "StringLike"
      variable = "s3:prefix"
      values = [var.state_key, "${var.state_key}.tflock"]
    }
  }
  statement {
    sid       = "GetState"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${local.state_arn}/${var.state_key}"]
  }
  statement {
    sid       = "LockStateOnly"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.state_arn}/${var.state_key}.tflock"]
  }
  statement {
    sid       = "DecryptStateOnly"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
    resources = [var.state_kms_key_arn]
  }
}

resource "aws_iam_role_policy" "plan_state" {
  name   = "tfsec-plan-state"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.plan_state.json
}

data "aws_iam_policy_document" "apply_extra" {
  statement {
    sid       = "StateBucketList"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [local.state_arn]
    condition {
      test = "StringLike"
      variable = "s3:prefix"
      values = [var.state_key, "${var.state_key}.tflock"]
    }
  }
  statement {
    sid       = "StateObjectAndLock"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${local.state_arn}/${var.state_key}", "${local.state_arn}/${var.state_key}.tflock"]
  }
  statement {
    sid       = "StateKeyUsage"
    effect    = "Allow"
    actions   = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey", "kms:DescribeKey"]
    resources = [var.state_kms_key_arn]
  }
  statement {
    sid       = "IAMPasswordPolicy"
    effect    = "Allow"
    actions   = ["iam:UpdateAccountPasswordPolicy", "iam:DeleteAccountPasswordPolicy"]
    resources = ["*"]
  }
  statement {
    sid       = "ManageWorkloadServiceRoles"
    effect    = "Allow"
    actions = [
      "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:UpdateAssumeRolePolicy",
      "iam:PutRolePolicy", "iam:DeleteRolePolicy", "iam:GetRolePolicy",
      "iam:TagRole", "iam:UntagRole", "iam:ListRolePolicies",
      "iam:ListAttachedRolePolicies"
    ]
    resources = ["arn:aws:iam::${var.account_id}:role/tfsec-workload-*"]
  }
  statement {
    sid       = "AttachSSMManagedPolicy"
    effect    = "Allow"
    actions   = ["iam:AttachRolePolicy", "iam:DetachRolePolicy"]
    resources = ["arn:aws:iam::${var.account_id}:role/tfsec-workload-*"]
    condition {
      test     = "ArnEquals"
      variable = "iam:PolicyARN"
      values   = ["arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"]
    }
  }
  statement {
    sid       = "ManageWorkloadInstanceProfiles"
    effect    = "Allow"
    actions = [
      "iam:CreateInstanceProfile", "iam:DeleteInstanceProfile", "iam:GetInstanceProfile",
      "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile",
      "iam:TagInstanceProfile"
    ]
    resources = ["arn:aws:iam::${var.account_id}:instance-profile/tfsec-workload-*"]
  }
  statement {
    sid       = "PassWorkloadServiceRoles"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::${var.account_id}:role/tfsec-workload-*"]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ec2.amazonaws.com", "vpc-flow-logs.amazonaws.com", "cloudtrail.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "apply_extra" {
  name   = "tfsec-apply-extra"
  role   = aws_iam_role.apply.id
  policy = data.aws_iam_policy_document.apply_extra.json
}
