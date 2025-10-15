# terraform/modules/vpc/outputs.tf

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
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

output "database_subnet_ids" {
  description = "IDs of database subnets (alias for private_data_subnet_ids)"
  value       = aws_subnet.private_data[*].id
}

output "nat_gateway_ids" {
  description = "IDs of NAT Gateways"
  value       = var.enable_nat_gateway ? aws_nat_gateway.main[*].id : []
}

output "nat_gateway_public_ips" {
  description = "Public IP addresses of NAT Gateways"
  value       = var.enable_nat_gateway ? aws_eip.nat[*].public_ip : []
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public.id
}

output "private_app_route_table_ids" {
  description = "IDs of private app route tables"
  value       = aws_route_table.private_app[*].id
}

output "private_data_route_table_id" {
  description = "ID of the private data route table"
  value       = aws_route_table.private_data.id
}

output "vpc_endpoint_s3_id" {
  description = "ID of S3 VPC endpoint"
  value       = var.enable_vpc_endpoints ? aws_vpc_endpoint.s3[0].id : null
}

output "vpc_endpoint_ecr_api_id" {
  description = "ID of ECR API VPC endpoint"
  value       = var.enable_vpc_endpoints ? aws_vpc_endpoint.ecr_api[0].id : null
}

output "vpc_endpoint_ecr_dkr_id" {
  description = "ID of ECR DKR VPC endpoint"
  value       = var.enable_vpc_endpoints ? aws_vpc_endpoint.ecr_dkr[0].id : null
}

output "vpc_endpoint_logs_id" {
  description = "ID of CloudWatch Logs VPC endpoint"
  value       = var.enable_vpc_endpoints ? aws_vpc_endpoint.logs[0].id : null
}

output "vpc_endpoint_secretsmanager_id" {
  description = "ID of Secrets Manager VPC endpoint"
  value       = var.enable_vpc_endpoints ? aws_vpc_endpoint.secretsmanager[0].id : null
}

output "vpc_endpoints_security_group_id" {
  description = "Security group ID for VPC endpoints"
  value       = var.enable_vpc_endpoints ? aws_security_group.vpc_endpoints[0].id : null
}

output "availability_zones" {
  description = "List of availability zones used"
  value       = var.availability_zones
}

