# terraform/modules/vpc/main.tf
# ==============================================================================
# VPC Module - Network Infrastructure
# ==============================================================================
# This module creates the VPC infrastructure including:
# - VPC with CIDR block
# - Public and private subnets across multiple AZs
# - Internet Gateway for public subnets
# - NAT Gateways for private subnet internet access
# - Route tables and associations
# - VPC endpoints for AWS services (cost optimization)
# - VPC Flow Logs for security monitoring
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ==============================================================================
# Local Variables
# ==============================================================================

locals {
  # Calculate subnet CIDR blocks
  # Public subnets: 10.0.1.0/24, 10.0.2.0/24
  # Private app subnets: 10.0.10.0/24, 10.0.11.0/24
  # Private data subnets: 10.0.20.0/24, 10.0.21.0/24

  public_subnet_cidrs       = [for i, az in var.availability_zones : cidrsubnet(var.vpc_cidr, 8, i + 1)]
  private_app_subnet_cidrs  = [for i, az in var.availability_zones : cidrsubnet(var.vpc_cidr, 8, i + 10)]
  private_data_subnet_cidrs = [for i, az in var.availability_zones : cidrsubnet(var.vpc_cidr, 8, i + 20)]

  # Common tags
  common_tags = merge(
    var.tags,
    {
      Module      = "vpc"
      Environment = var.environment
    }
  )
}

# ==============================================================================
# VPC
# ==============================================================================

# Create VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true # Required for ECS and RDS
  enable_dns_support   = true # Required for DNS resolution

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-vpc"
    }
  )
}

# ==============================================================================
# Internet Gateway
# ==============================================================================

# Create Internet Gateway for public subnets
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-igw"
    }
  )
}

# ==============================================================================
# Public Subnets
# ==============================================================================

# Create public subnets (for ALB, NAT Gateways)
resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true # Auto-assign public IPs

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-public-${var.availability_zones[count.index]}"
      Tier = "Public"
    }
  )
}

# ==============================================================================
# Private Application Subnets
# ==============================================================================

# Create private subnets for ECS tasks
resource "aws_subnet" "private_app" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_app_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-private-app-${var.availability_zones[count.index]}"
      Tier = "Application"
    }
  )
}

# ==============================================================================
# Private Data Subnets
# ==============================================================================

# Create private subnets for databases
resource "aws_subnet" "private_data" {
  count = length(var.availability_zones)

  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_data_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-private-data-${var.availability_zones[count.index]}"
      Tier = "Data"
    }
  )
}

# ==============================================================================
# Elastic IPs for NAT Gateways
# ==============================================================================

# Create Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.availability_zones)) : 0
  domain = "vpc"

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-nat-eip-${count.index + 1}"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

# ==============================================================================
# NAT Gateways
# ==============================================================================

# Create NAT Gateways for private subnets internet access
resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.availability_zones)) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[var.single_nat_gateway ? 0 : count.index].id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-nat-${count.index + 1}"
    }
  )

  depends_on = [aws_internet_gateway.main]
}

# ==============================================================================
# Route Tables
# ==============================================================================

# Public route table (routes to Internet Gateway)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-public-rt"
    }
  )
}

# Private route tables for application subnets (routes to NAT Gateway)
resource "aws_route_table" "private_app" {
  count  = var.enable_nat_gateway ? length(var.availability_zones) : 1
  vpc_id = aws_vpc.main.id

  # Route to NAT Gateway (if enabled)
  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = var.single_nat_gateway ? aws_nat_gateway.main[0].id : aws_nat_gateway.main[count.index].id
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-private-app-rt-${count.index + 1}"
    }
  )
}

# Private route tables for data subnets (no internet access)
resource "aws_route_table" "private_data" {
  count  = length(var.availability_zones)
  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-private-data-rt-${count.index + 1}"
    }
  )
}

# ==============================================================================
# Route Table Associations
# ==============================================================================

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Associate private app subnets with private app route tables
resource "aws_route_table_association" "private_app" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app[var.single_nat_gateway ? 0 : count.index].id
}

# Associate private data subnets with private data route tables
resource "aws_route_table_association" "private_data" {
  count          = length(var.availability_zones)
  subnet_id      = aws_subnet.private_data[count.index].id
  route_table_id = aws_route_table.private_data[count.index].id
}

# ==============================================================================
# VPC Endpoints (Cost Optimization)
# ==============================================================================

# S3 Gateway Endpoint (Free)
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.aws_region}.s3"

  route_table_ids = concat(
    [aws_route_table.public.id],
    aws_route_table.private_app[*].id,
    aws_route_table.private_data[*].id
  )

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-s3-endpoint"
    }
  )
}

# ECR API Interface Endpoint (for pulling images)
resource "aws_vpc_endpoint" "ecr_api" {
  count = var.enable_vpc_endpoints ? 1 : 0

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private_app[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-ecr-api-endpoint"
    }
  )
}

# ECR Docker Interface Endpoint (for pulling images)
resource "aws_vpc_endpoint" "ecr_dkr" {
  count = var.enable_vpc_endpoints ? 1 : 0

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private_app[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-ecr-dkr-endpoint"
    }
  )
}

# CloudWatch Logs Interface Endpoint (for logging)
resource "aws_vpc_endpoint" "logs" {
  count = var.enable_vpc_endpoints ? 1 : 0

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private_app[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-logs-endpoint"
    }
  )
}

# Secrets Manager Interface Endpoint (for secrets retrieval)
resource "aws_vpc_endpoint" "secretsmanager" {
  count = var.enable_vpc_endpoints ? 1 : 0

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private_app[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-secretsmanager-endpoint"
    }
  )
}

# Systems Manager Interface Endpoint (for parameter store)
resource "aws_vpc_endpoint" "ssm" {
  count = var.enable_vpc_endpoints ? 1 : 0

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private_app[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-ssm-endpoint"
    }
  )
}

# ==============================================================================
# Security Group for VPC Endpoints
# ==============================================================================

# Security group for VPC endpoints
resource "aws_security_group" "vpc_endpoints" {
  count = var.enable_vpc_endpoints ? 1 : 0

  name_prefix = "${var.project_name}-${var.environment}-vpc-endpoints-"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-vpc-endpoints-sg"
    }
  )

  lifecycle {
    create_before_destroy = true
  }
}

# ==============================================================================
# VPC Flow Logs (Security Monitoring)
# ==============================================================================

# CloudWatch Log Group for VPC Flow Logs
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name              = "/aws/vpc/${var.project_name}-${var.environment}"
  retention_in_days = var.flow_logs_retention_days
  kms_key_id        = var.flow_logs_kms_key_arn

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-vpc-flow-logs"
    }
  )
}

# IAM Role for VPC Flow Logs
resource "aws_iam_role" "vpc_flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name_prefix = "${var.project_name}-${var.environment}-vpc-flow-logs-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

# IAM Policy for VPC Flow Logs
resource "aws_iam_role_policy" "vpc_flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name_prefix = "vpc-flow-logs-"
  role        = aws_iam_role.vpc_flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

# VPC Flow Logs
resource "aws_flow_log" "main" {
  count = var.enable_flow_logs ? 1 : 0

  iam_role_arn    = aws_iam_role.vpc_flow_logs[0].arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs[0].arn
  traffic_type    = var.flow_logs_traffic_type
  vpc_id          = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-vpc-flow-logs"
    }
  )
}

