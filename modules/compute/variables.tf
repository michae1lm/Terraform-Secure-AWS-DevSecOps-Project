variable "vpc_id" { type = string }
variable "vpc_cidr" { type = string }
variable "private_subnet_id" { type = string }
variable "ebs_kms_key_arn" { type = string }
variable "instance_type" {
  type    = string
  default = "t3.micro"
}
