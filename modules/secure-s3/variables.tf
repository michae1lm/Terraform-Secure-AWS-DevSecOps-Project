variable "bucket_name" { type = string }
variable "kms_key_arn" { type = string }
variable "additional_policy_json" {
  type        = string
  default     = ""
  description = "Additional bucket policy JSON merged with the mandatory TLS deny."
}
variable "access_log_bucket" {
  type        = string
  default     = null
  description = "Separate log destination. Null for an access-log destination bucket."
}
variable "lifecycle_days" {
  type    = number
  default = 90
}
