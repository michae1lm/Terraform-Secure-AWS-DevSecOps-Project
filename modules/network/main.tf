data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "tfsec-private-vpc" }
}

resource "aws_subnet" "private" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags = { Name = "tfsec-private-${count.index + 1}" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "tfsec-private-routes" }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# No internet gateway and no NAT gateway are created.
resource "aws_default_security_group" "restricted" {
  vpc_id  = aws_vpc.main.id
  ingress = []
  egress  = []
  tags    = { Name = "tfsec-default-deny" }
}

resource "aws_security_group" "interface_endpoints" {
  name        = "tfsec-interface-endpoints"
  description = "Allow HTTPS to SSM endpoints only from this VPC"
  vpc_id      = aws_vpc.main.id
  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  egress = []
  tags   = { Name = "tfsec-ssm-endpoints" }
}

# S3 Gateway endpoints have no hourly endpoint charge in the standard pricing model.
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]
  tags = { Name = "tfsec-s3-gateway" }
}

locals {
  ssm_endpoints = toset(["ssm", "ssmmessages", "ec2messages"])
}

resource "aws_vpc_endpoint" "ssm" {
  for_each            = var.enable_private_endpoints ? local.ssm_endpoints : toset([])
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.${each.value}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [aws_subnet.private[0].id]
  security_group_ids  = [aws_security_group.interface_endpoints.id]
  tags = { Name = "tfsec-endpoint-${each.value}" }
}

resource "aws_cloudwatch_log_group" "flow" {
  name              = "/aws/vpc/flowlogs/tfsec-lab"
  retention_in_days = 30
  kms_key_id        = var.logs_kms_key_arn
}

data "aws_iam_policy_document" "flow_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "flow" {
  name               = "tfsec-workload-vpc-flow"
  assume_role_policy = data.aws_iam_policy_document.flow_trust.json
}

data "aws_iam_policy_document" "flow_write" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogGroups",
      "logs:DescribeLogStreams", "logs:CreateLogGroup"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "flow" {
  name   = "tfsec-vpc-flow-write"
  role   = aws_iam_role.flow.id
  policy = data.aws_iam_policy_document.flow_write.json
}

resource "aws_flow_log" "all" {
  vpc_id               = aws_vpc.main.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.flow.arn
  iam_role_arn         = aws_iam_role.flow.arn
  depends_on           = [aws_iam_role_policy.flow]
  tags                 = { Name = "tfsec-vpc-flow-logs" }
}
