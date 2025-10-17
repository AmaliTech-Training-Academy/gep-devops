
# ==============================================================================
# terraform/environments/dev/terraform.tfvars
# ==============================================================================

# AWS Configuration
aws_region = "us-east-1"

# Project Configuration
project_name = "event-planner"
environment  = "dev"

# Network Configuration
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["us-east-1a"]

# Domain Configuration
domain_name     = "sankofagrid.com"
frontend_domain = "www.sankofagrid.com"
backend_domain  = "api.sankofagrid.com"

# Feature Flags
enable_flow_logs = true

# Tags
tags = {
  CostCenter  = "Engineering"
  Owner       = "DevOps Team"
  Terraform   = "true"
  Environment = "dev"
}