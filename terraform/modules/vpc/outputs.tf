# ==============================================================================
# terraform/modules/vpc/outputs.tf
# ==============================================================================
# VPC MODULE OUTPUTS - Information Made Available to Other Modules
# ==============================================================================
# WHAT THIS FILE DOES:
# Provides information about the created network infrastructure to other modules.
# Like giving other departments the building directory, room numbers, and access codes.
#
# WHY OUTPUTS MATTER:
# - Other modules need VPC IDs to create resources in the right network
# - Subnet IDs tell services where they can be deployed
# - Security group modules need VPC ID to create firewall rules
# - Load balancers need public subnet IDs to receive internet traffic
#
# INFORMATION PROVIDED:
# - Network identifiers (VPC ID, subnet IDs)
# - Network configuration (CIDR blocks, route tables)
# - Infrastructure endpoints (NAT gateways, VPC endpoints)
# - Security and monitoring components
# ==============================================================================

# ==============================================================================
# Core VPC Information
# ==============================================================================

output "vpc_id" {
  description = "Unique identifier of the main VPC network container. Other modules use this to create resources in the correct network."
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "IP address range of the VPC (e.g., 10.0.0.0/16). Used by security groups to define network access rules."
  value       = aws_vpc.main.cidr_block
}

output "vpc_arn" {
  description = "Amazon Resource Name (ARN) of the VPC. Used for IAM policies and cross-account access."
  value       = aws_vpc.main.arn
}

# ==============================================================================
# Internet Access Components
# ==============================================================================

output "internet_gateway_id" {
  description = "ID of the Internet Gateway - the main entrance/exit for public internet traffic. Used by route tables to direct traffic."
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_ids" {
  description = "IDs of NAT Gateways - secure back doors that allow private subnets to access internet while blocking inbound traffic."
  value       = var.enable_nat_gateway ? aws_nat_gateway.main[*].id : []
}

output "nat_gateway_public_ips" {
  description = "Public IP addresses of NAT Gateways. These IPs appear as the source when private resources access the internet."
  value       = var.enable_nat_gateway ? aws_eip.nat[*].public_ip : []
}

# ==============================================================================
# Public Subnet Information (Internet-Accessible Areas)
# ==============================================================================

output "public_subnet_ids" {
  description = "IDs of public subnets where internet-facing resources are deployed (load balancers, NAT gateways). These have direct internet access."
  value       = aws_subnet.public[*].id
}

output "public_subnet_cidrs" {
  description = "IP address ranges of public subnets. Used for security group rules and network planning."
  value       = aws_subnet.public[*].cidr_block
}

# ==============================================================================
# Private Application Subnet Information (Secure Application Areas)
# ==============================================================================

output "private_app_subnet_ids" {
  description = "IDs of private application subnets where our microservices run (auth, event, notification services). Protected from direct internet access."
  value       = aws_subnet.private_app[*].id
}

output "private_app_subnet_cidrs" {
  description = "IP address ranges of application subnets. Used by ECS and security groups to deploy and protect our services."
  value       = aws_subnet.private_app[*].cidr_block
}

# ==============================================================================
# Private Data Subnet Information (Maximum Security Database Areas)
# ==============================================================================

output "private_data_subnet_ids" {
  description = "IDs of private data subnets where databases and sensitive storage are deployed (RDS, ElastiCache). No internet access for maximum security."
  value       = aws_subnet.private_data[*].id
}

output "private_data_subnet_cidrs" {
  description = "IP address ranges of data subnets. Used by database services and security groups to ensure data isolation."
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

