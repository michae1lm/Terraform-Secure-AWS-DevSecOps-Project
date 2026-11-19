variable "account_id" { type = string }
variable "aws_region" { type = string }
variable "trail_name" {
  type    = string
  default = "tfsec-management-trail"
}
variable "retention_days" {
  type    = number
  default = 30
}
