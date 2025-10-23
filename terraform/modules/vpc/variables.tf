# ==============================================================================
# terraform/modules/vpc/variables.tf
# ==============================================================================
# VPC Module Input Variables
# ==============================================================================
# This module creates a complete VPC infrastructure with:
# - Public subnets (for ALB, NAT Gateways)
# - Private application subnets (for ECS tasks)
# - Private data subnets (for RDS, DocumentDB, ElastiCache)
# - Internet Gateway for public internet access
# - NAT Gateways for private subnet internet access
# - VPC Endpoints for AWS services (reduces NAT Gateway costs)
# - VPC Flow Logs for network monitoring
# ==============================================================================

# ==============================================================================
# Required Variables (must be provided by caller)
# ==============================================================================

variable "project_name" {
  description = "Project name used as prefix for all VPC resources (e.g., event-planner-dev-vpc)"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod) - affects resource sizing and redundancy"
  type        = string
}

variable "availability_zones" {
  description = "List of AWS availability zones for subnet distribution. Dev: 1 AZ, Prod: 2+ AZs for high availability"
  type        = list(string)
  # Example: ["eu-west-1a", "eu-west-1b"] for multi-AZ deployment
}

# ==============================================================================
# Network Configuration
# ==============================================================================

variable "vpc_cidr" {
  description = "CIDR block for VPC. Default 10.0.0.0/16 provides 65,536 IP addresses. Subnets are automatically calculated from this range"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block (e.g., 10.0.0.0/16)."
  }
}

variable "aws_region" {
  description = "AWS region for VPC deployment. Must match the region in provider configuration"
  type        = string
  default     = "eu-west-1"
}

# ==============================================================================
# NAT Gateway Configuration
# ==============================================================================

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway to allow private subnets to access the internet (required for ECS to pull images, access AWS APIs)"
  type        = bool
  default     = true
  # Set to false only for testing/cost savings - will break ECS, RDS updates, etc.
}

variable "single_nat_gateway" {
  description = "Use single NAT Gateway for all AZs instead of one per AZ. Saves ~$32/month per NAT Gateway but reduces availability. Recommended: true for dev, false for prod"
  type        = bool
  default     = false
  # Cost comparison:
  # - Single NAT: ~$32/month (1 NAT Gateway)
  # - Multi-AZ NAT: ~$64/month (2 NAT Gateways) but survives AZ failure
}

# ==============================================================================
# VPC Endpoints Configuration
# ==============================================================================

variable "enable_vpc_endpoints" {
  description = "Enable VPC endpoints for AWS services (S3, ECR, Secrets Manager, etc.). Reduces NAT Gateway data transfer costs and improves security by keeping traffic within AWS network"
  type        = bool
  default     = true
  # Cost savings: ~$0.01/GB for data transfer vs $0.045/GB through NAT Gateway
  # Services with endpoints: S3, ECR (API & Docker), CloudWatch Logs, Secrets Manager, SSM
}

# ==============================================================================
# VPC Flow Logs Configuration
# ==============================================================================

variable "enable_flow_logs" {
  description = "Enable VPC Flow Logs for network traffic analysis, security monitoring, and troubleshooting. Logs are sent to CloudWatch Logs"
  type        = bool
  default     = true
  # Use cases:
  # - Security: Detect unusual traffic patterns, potential attacks
  # - Troubleshooting: Debug connectivity issues between services
  # - Compliance: Network activity audit trail
}

variable "flow_logs_retention_days" {
  description = "Number of days to retain VPC Flow Logs in CloudWatch. Longer retention = higher costs but better historical analysis"
  type        = number
  default     = 30
  # Common values: 7 (dev), 30 (staging), 90 (prod), 365 (compliance)
}

variable "flow_logs_traffic_type" {
  description = "Type of traffic to capture in Flow Logs: ACCEPT (successful connections), REJECT (blocked by security groups), ALL (both)"
  type        = string
  default     = "ALL"

  validation {
    condition     = contains(["ACCEPT", "REJECT", "ALL"], var.flow_logs_traffic_type)
    error_message = "Flow logs traffic type must be ACCEPT, REJECT, or ALL."
  }
  # Recommendation: ALL for comprehensive monitoring, REJECT for security-focused logging
}

variable "flow_logs_kms_key_arn" {
  description = "Optional KMS key ARN for encrypting VPC Flow Logs at rest in CloudWatch. If null, uses AWS-managed encryption"
  type        = string
  default     = null
  # Provide KMS key ARN for compliance requirements (e.g., HIPAA, PCI-DSS)
}

# ==============================================================================
# Resource Tagging
# ==============================================================================

variable "tags" {
  description = "Additional tags to apply to all VPC resources for organization, cost tracking, and automation"
  type        = map(string)
  default     = {}
  # Example: { CostCenter = "Engineering", Team = "Platform", Compliance = "PCI-DSS" }
}

