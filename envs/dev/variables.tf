variable "aws_region" {
  type    = string
  default = "us-west-2"
}

variable "enable_guardduty" {
  type        = bool
  default     = true
  description = "GuardDuty is a billable service outside promotional trials."
}

variable "enable_compute" {
  type        = bool
  default     = false
  description = "Launch private EC2 only for a controlled demo. Automatically enables billable SSM endpoints."
}

variable "enable_private_endpoints" {
  type        = bool
  default     = false
  description = "SSM interface endpoints incur hourly charges."
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}
