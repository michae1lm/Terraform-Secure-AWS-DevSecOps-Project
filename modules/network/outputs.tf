output "vpc_id" { value = aws_vpc.main.id }
output "vpc_cidr" { value = aws_vpc.main.cidr_block }
output "private_subnet_ids" { value = aws_subnet.private[*].id }
output "vpc_flow_log_id" { value = aws_flow_log.all.id }
output "endpoint_ids" {
  value = { for key, endpoint in aws_vpc_endpoint.ssm : key => endpoint.id }
}
