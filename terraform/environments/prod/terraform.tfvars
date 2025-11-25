# terraform/environments/prod/terraform.tfvars
# ==============================================================================
# Production Environment Configuration
# ==============================================================================

# Project Configuration
project_name = "event-planner"
environment  = "prod"

# Network Configuration - Multi-AZ for High Availability
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["eu-west-1a", "eu-west-1b"]

# Domain Configuration
domain_name = "sankofagrid.com"

# Feature Flags
enable_flow_logs = true

# Monitoring Configuration
alert_email_addresses = [
  "devops@sankofagrid.com",
  "alerts@sankofagrid.com"
]

# Tags
tags = {
  CostCenter  = "Engineering"
  Owner       = "DevOps Team"
  Terraform   = "true"
  Environment = "prod"
}

