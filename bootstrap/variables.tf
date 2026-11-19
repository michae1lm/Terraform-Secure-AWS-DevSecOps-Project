variable "aws_region" {
  type        = string
  description = "Region for the bootstrap state bucket and AWS infrastructure."
  default     = "us-west-2"
}

variable "github_owner" {
  type        = string
  description = "GitHub username/org owning the repository."
  default     = "michae1lm"
}

variable "github_repo" {
  type        = string
  description = "Exact GitHub repository name used by the OIDC trust policy."
  default     = "terraform-secure-aws"
}

variable "bucket_suffix" {
  type        = string
  description = "Suffix for globally unique S3 bucket names."
  default     = "lab"
  validation {
    condition     = can(regex("^[a-z0-9-]{1,12}$", var.bucket_suffix))
    error_message = "Use 1-12 lowercase letters, digits, or hyphens."
  }
}

variable "budget_email" {
  type        = string
  description = "Optional email to create a $10 AWS Budget with 50% and 100% actual cost alerts. Empty disables budget creation."
  default     = ""
}
