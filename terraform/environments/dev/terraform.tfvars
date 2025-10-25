# terraform/environments/dev/terraform.tfvars
# ==============================================================================
# Development Environment Configuration
# ==============================================================================



# Project Configuration
project_name = "event-planner"
environment  = "dev"

# Network Configuration
vpc_cidr           = "10.0.0.0/16"
availability_zones = ["eu-west-1a", "eu-west-1b"] # 2 AZs required by AWS for RDS, ALB

# Domain Configuration
domain_name = "sankofagrid.com"
#frontend_domain = "www.sankofagrid.com"
#backend_domain  = "api.sankofagrid.com"

# Route53 Configuration
# If you have an existing hosted zone, provide its ID here
# Otherwise, set create_hosted_zone = true in Route53 module
#route53_zone_id = ""  # Example: "Z1234567890ABC"

# Feature Flags
enable_flow_logs = true

# Monitoring Configuration
# Add email addresses for CloudWatch alerts
alert_email_addresses = [
  "devops@sankofagrid.com",
  # "alerts@sankofagrid.com"
]
#alert_email_addresses = ["mangucletus@gmail.com"]

# JWT Configuration (Auth Service)
jwt_access_expiration  = 3600000  # 1 hour in milliseconds
jwt_refresh_expiration = 86400000 # 24 hours in milliseconds

# Tags
tags = {
  CostCenter  = "Engineering"
  Owner       = "DevOps Team"
  Terraform   = "true"
  Environment = "dev"
}

# AWS Credentials for ECS Services
# Set via environment variables:
# export TF_VAR_aws_access_key_id="your-key"
# export TF_VAR_aws_secret_access_key="your-secret"
# Or in CI/CD via GitHub Actions secrets
