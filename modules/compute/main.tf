data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_security_group" "instance" {
  name        = "tfsec-private-ec2"
  description = "No inbound traffic; HTTPS outbound within VPC for SSM"
  vpc_id      = var.vpc_id
  ingress     = []
  egress {
    description = "SSM VPC endpoints on 443"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }
  tags = { Name = "tfsec-instance-no-inbound" }
}

data "aws_iam_policy_document" "ec2_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ssm" {
  name               = "tfsec-workload-ec2-ssm"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  name = "tfsec-workload-ec2-ssm"
  role = aws_iam_role.ssm.name
}

resource "aws_instance" "app" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = var.instance_type
  subnet_id                   = var.private_subnet_id
  vpc_security_group_ids      = [aws_security_group.instance.id]
  iam_instance_profile        = aws_iam_instance_profile.ssm.name
  associate_public_ip_address = false
  ebs_optimized               = true
  monitoring                  = false # Basic monitoring avoids detailed-monitoring charges.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }
  root_block_device {
    encrypted   = true
    kms_key_id  = var.ebs_kms_key_arn
    volume_size = 8
    volume_type = "gp3"
  }
  tags       = { Name = "tfsec-private-ec2" }
  depends_on = [aws_iam_role_policy_attachment.ssm]
}
