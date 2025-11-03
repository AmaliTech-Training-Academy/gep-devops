# terraform/modules/vpc/main.tf
# ==============================================================================
# VPC Module - Network Infrastructure (Virtual Private Cloud)
# ==============================================================================
# WHAT THIS MODULE DOES:
# This module creates a secure, isolated network in AWS where our applications run.
# Think of it like creating a private office building with different floors and rooms.
#
# COMPONENTS CREATED:
# 1. VPC (Virtual Private Cloud) - The main building/network container
# 2. Subnets - Different floors/rooms for different purposes:
#    - Public subnets: Ground floor with direct street access (internet)
#    - Private app subnets: Secure floors for our applications
#    - Private data subnets: Vault floors for our databases
# 3. Internet Gateway - Main entrance/exit to the internet
# 4. NAT Gateways - Secure back doors for private rooms to access internet
# 5. Route Tables - Directions telling traffic where to go
# 6. VPC Endpoints - Private tunnels to AWS services (saves money)
# 7. Flow Logs - Security cameras recording all network traffic
#
# BUSINESS VALUE:
# - Security: Applications are isolated from direct internet access
# - Reliability: Multiple availability zones prevent single points of failure
# - Cost Optimization: VPC endpoints reduce data transfer costs
# - Compliance: Network monitoring and access controls
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
# Local Variables - Calculated Values
# ==============================================================================
# WHAT THIS SECTION DOES:
# Automatically calculates IP address ranges for different subnet types.
# Like dividing a large office building into specific floor numbers.
#
# IP ADDRESS ALLOCATION STRATEGY:
# - Main VPC: 10.0.0.0/16 (65,536 total IP addresses)
# - Public subnets: 10.0.1.0/24, 10.0.2.0/24 (256 IPs each)
# - Private app subnets: 10.0.10.0/24, 10.0.11.0/24 (256 IPs each)
# - Private data subnets: 10.0.20.0/24, 10.0.21.0/24 (256 IPs each)
#
# WHY THIS MATTERS:
# - Organized IP ranges make troubleshooting easier
# - Prevents IP conflicts between different services
# - Allows for future expansion without redesign

locals {

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
# VPC - Virtual Private Cloud (The Main Network Container)
# ==============================================================================
# WHAT THIS CREATES:
# The main network container that holds all our infrastructure.
# Like constructing the outer walls and foundation of our office building.
#
# KEY FEATURES:
# - Isolated network space in AWS cloud
# - Custom IP address range (10.0.0.0/16)
# - DNS resolution enabled for service communication
# - Foundation for all other network components
#
# BUSINESS IMPACT:
# - Complete network isolation from other AWS customers
# - Full control over network security and routing
# - Enables secure communication between services

# Create the main VPC (Virtual Private Cloud)
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true # Allows services to have friendly names (e.g., database.internal)
  enable_dns_support   = true # Enables name resolution within the network

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-vpc"
    }
  )
}

# ==============================================================================
# Internet Gateway - Main Entrance to the Internet
# ==============================================================================
# WHAT THIS CREATES:
# The main entrance/exit point for internet traffic to our network.
# Like the main lobby entrance of our office building.
#
# PURPOSE:
# - Allows public subnets to communicate with the internet
# - Enables users to access our web applications
# - Required for load balancers to receive external traffic
#
# SECURITY NOTE:
# Only public subnets use this gateway directly.
# Private subnets use NAT Gateways for secure internet access.

# Create Internet Gateway for public internet access
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
# Public Subnets - Ground Floor with Street Access
# ==============================================================================
# WHAT THESE CREATE:
# Network segments with direct internet access.
# Like ground floor offices with street-facing windows and doors.
#
# WHAT GOES HERE:
# - Application Load Balancer (receives user requests)
# - NAT Gateways (secure internet access for private subnets)
# - Bastion hosts (secure admin access points)
#
# SECURITY CONSIDERATIONS:
# - Direct internet access (both inbound and outbound)
# - Protected by security groups (firewall rules)
# - Only infrastructure components, not application servers
#
# HIGH AVAILABILITY:
# - Created in multiple availability zones
# - If one zone fails, others continue operating

# Create public subnets (for load balancers and NAT gateways)
resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true # Automatically assign public IP addresses

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-public-${var.availability_zones[count.index]}"
      Tier = "Public"
    }
  )
}

# ==============================================================================
# Private Application Subnets - Secure Office Floors
# ==============================================================================
# WHAT THESE CREATE:
# Secure network segments for running our applications.
# Like secure office floors accessible only through controlled entrances.
#
# WHAT GOES HERE:
# - ECS containers (our microservices: auth, event, notification)
# - Application servers and business logic
# - Services that need internet access but shouldn't be directly accessible
#
# SECURITY FEATURES:
# - No direct internet access (inbound blocked)
# - Outbound internet access through NAT Gateway
# - Protected by multiple layers of security groups
# - Can communicate with other private subnets
#
# BUSINESS BENEFITS:
# - Applications are protected from direct internet attacks
# - Can still download updates and access external APIs
# - Isolated from database layer for additional security

# Create private application subnets for our microservices
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
# Private Data Subnets - Maximum Security Vault Floors
# ==============================================================================
# WHAT THESE CREATE:
# Ultra-secure network segments for our databases and sensitive data.
# Like bank vault floors with no external access whatsoever.
#
# WHAT GOES HERE:
# - RDS PostgreSQL databases (user data, events, bookings)
# - ElastiCache Redis (session storage, caching)
# - Any service storing sensitive customer information
#
# MAXIMUM SECURITY FEATURES:
# - No internet access at all (inbound or outbound)
# - Only accessible from application subnets
# - Separate from application layer for defense in depth
# - Encrypted storage and network traffic
#
# COMPLIANCE BENEFITS:
# - Meets strict data protection requirements
# - Isolates sensitive data from application logic
# - Provides audit trail for data access
# - Supports regulatory compliance (GDPR, PCI-DSS)

# Create private data subnets for databases and sensitive storage
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
  count  = length(var.availability_zones)
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
  route_table_id = aws_route_table.private_app[count.index].id
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
  subnet_ids          = [aws_subnet.private_app[0].id]
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
  subnet_ids          = [aws_subnet.private_app[0].id]
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
  subnet_ids          = [aws_subnet.private_app[0].id]
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
  subnet_ids          = [aws_subnet.private_app[0].id]
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
  subnet_ids          = [aws_subnet.private_app[0].id]
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-ssm-endpoint"
    }
  )
}

# SQS Interface Endpoint (for message queues)
resource "aws_vpc_endpoint" "sqs" {
  count = var.enable_vpc_endpoints ? 1 : 0

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.sqs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_app[0].id]
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-sqs-endpoint"
    }
  )
}

# SNS Interface Endpoint (for pub/sub messaging)
resource "aws_vpc_endpoint" "sns" {
  count = var.enable_vpc_endpoints ? 1 : 0

  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.sns"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_app[0].id]
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-${var.environment}-sns-endpoint"
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

