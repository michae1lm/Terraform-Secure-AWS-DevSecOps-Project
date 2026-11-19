variable "vpc_cidr" {
  type    = string
  default = "10.42.0.0/16"
}
variable "aws_region" { type = string }
variable "logs_kms_key_arn" { type = string }
variable "enable_private_endpoints" {
  type    = bool
  default = false
}
