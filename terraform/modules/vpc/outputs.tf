# ==============================================================================
# terraform/modules/vpc/outputs.tf
# ==============================================================================

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "vpc_arn" {
  description = "ARN of the VPC"
  value       = aws_vpc.main.arn
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_ids" {
  description = "IDs of the NAT Gateways"
  value       = var.enable_nat_gateway ? aws_nat_gateway.main[*].id : []
}

output "nat_gateway_public_ips" {
  description = "Public IPs of the NAT Gateways"
  value       = var.enable_nat_gateway ? aws_eip.nat[*].public_ip : []
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "public_subnet_cidrs" {
  description = "CIDR blocks of public subnets"
  value       = aws_subnet.public[*].cidr_block
}

output "private_app_subnet_ids" {
  description = "IDs of private application subnets"
  value       = aws_subnet.private_app[*].id
}

output "private_app_subnet_cidrs" {
  description = "CIDR blocks of private application subnets"
  value       = aws_subnet.private_app[*].cidr_block
}

output "private_data_subnet_ids" {
  description = "IDs of private data subnets"
  value       = aws_subnet.private_data[*].id
}

output "private_data_subnet_cidrs" {
  description = "CIDR blocks of private data subnets"
  value       = aws_subnet.private_data[*].cidr_block
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public.id
}

output "private_app_route_table_ids" {
  description = "IDs of private application route tables"
  value       = aws_route_table.private_app[*].id
}

output "private_data_route_table_ids" {
  description = "IDs of private data route tables"
  value       = aws_route_table.private_data[*].id
}

output "vpc_endpoint_s3_id" {
  description = "ID of the S3 VPC endpoint"
  value       = aws_vpc_endpoint.s3.id
}

output "vpc_endpoint_ecr_api_id" {
  description = "ID of the ECR API VPC endpoint"
  value       = var.enable_vpc_endpoints ? aws_vpc_endpoint.ecr_api[0].id : null
}

output "vpc_endpoint_ecr_dkr_id" {
  description = "ID of the ECR Docker VPC endpoint"
  value       = var.enable_vpc_endpoints ? aws_vpc_endpoint.ecr_dkr[0].id : null
}

output "vpc_endpoint_logs_id" {
  description = "ID of the CloudWatch Logs VPC endpoint"
  value       = var.enable_vpc_endpoints ? aws_vpc_endpoint.logs[0].id : null
}

output "vpc_endpoint_secretsmanager_id" {
  description = "ID of the Secrets Manager VPC endpoint"
  value       = var.enable_vpc_endpoints ? aws_vpc_endpoint.secretsmanager[0].id : null
}

output "vpc_endpoint_ssm_id" {
  description = "ID of the Systems Manager VPC endpoint"
  value       = var.enable_vpc_endpoints ? aws_vpc_endpoint.ssm[0].id : null
}

output "vpc_endpoints_security_group_id" {
  description = "ID of the VPC endpoints security group"
  value       = var.enable_vpc_endpoints ? aws_security_group.vpc_endpoints[0].id : null
}

output "flow_logs_log_group_name" {
  description = "Name of the VPC Flow Logs CloudWatch Log Group"
  value       = var.enable_flow_logs ? aws_cloudwatch_log_group.vpc_flow_logs[0].name : null
}

output "flow_logs_iam_role_arn" {
  description = "ARN of the IAM role for VPC Flow Logs"
  value       = var.enable_flow_logs ? aws_iam_role.vpc_flow_logs[0].arn : null
}

