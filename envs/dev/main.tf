provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "terraform-secure-aws"
      Environment = "dev"
      ManagedBy   = "terraform"
      Owner       = "personal-security-lab"
    }
  }
}

data "aws_caller_identity" "current" {}

module "account_baseline" {
  source = "../../modules/account-baseline"
}

module "logging" {
  source     = "../../modules/logging"
  account_id = data.aws_caller_identity.current.account_id
  aws_region = var.aws_region
}

module "network" {
  source                   = "../../modules/network"
  aws_region               = var.aws_region
  logs_kms_key_arn         = module.logging.kms_key_arn
  enable_private_endpoints = var.enable_private_endpoints || var.enable_compute
}

module "detection" {
  source  = "../../modules/detection"
  enabled = var.enable_guardduty
}

module "compute" {
  count             = var.enable_compute ? 1 : 0
  source            = "../../modules/compute"
  vpc_id            = module.network.vpc_id
  vpc_cidr          = module.network.vpc_cidr
  private_subnet_id = module.network.private_subnet_ids[0]
  ebs_kms_key_arn   = module.account_baseline.ebs_kms_key_arn
  instance_type     = var.instance_type
  depends_on        = [module.network]
}
