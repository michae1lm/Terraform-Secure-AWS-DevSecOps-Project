config {
  module              = true
  force               = false
  disabled_by_default = false
}

plugin "aws" {
  enabled = true
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
  version = "0.41.0"
}
