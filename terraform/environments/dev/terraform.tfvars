# terraform/environments/dev/terraform.tfvars
# ==============================================================================
# Development Environment Configuration
# ==============================================================================



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

# Route53 Configuration
# If you have an existing hosted zone, provide its ID here
# Otherwise, set create_hosted_zone = true in Route53 module
#route53_zone_id = ""  # Example: "Z1234567890ABC"

# Feature Flags
enable_flow_logs = true

# Monitoring Configuration
# Add email addresses for CloudWatch alerts
alert_email_addresses = [
  # "devops@sankofagrid.com",
  # "alerts@sankofagrid.com"
]


# Tags
tags = {
  CostCenter  = "Engineering"
  Owner       = "DevOps Team"
  Terraform   = "true"
  Environment = "dev"
}

# ==============================================================================
# Secrets (DO NOT COMMIT TO VERSION CONTROL)
# ==============================================================================
# These should be provided via environment variables or AWS Secrets Manager
# 
# export TF_VAR_db_master_password="your-secure-password"
# export TF_VAR_docdb_master_password="your-secure-password"
# export TF_VAR_jwt_secret_key="your-jwt-secret-key"
# 
# Or create a separate terraform.tfvars.secret file (add to .gitignore)