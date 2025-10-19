# terraform/environments/dev/main.tf
# ==============================================================================
# Development Environment - Main Configuration
# ==============================================================================
# This is the main entry point for the development environment infrastructure.
# It orchestrates all modules to deploy a cost-optimized, single-AZ environment.
#
# Environment Characteristics:
# - Single AZ deployment for cost optimization
# - Minimal resource allocation
# - No read replicas for databases
# - Single ElastiCache node
# - 1 ECS task per microservice
# - Estimated cost: ~$248/month (24/7) or ~$75-95/month (weekday-only)
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
# Provider Configuration
# ==============================================================================

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      CostCenter  = "Engineering"
    }
  }
}

# Additional provider for ACM certificates (CloudFront requires us-east-1)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      CostCenter  = "Engineering"
    }
  }
}

# ==============================================================================
# Data Sources
# ==============================================================================

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# ==============================================================================
# Local Variables
# ==============================================================================

locals {
  common_tags = merge(
    var.tags,
    {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

# ==============================================================================
# VPC Module
# ==============================================================================

module "vpc" {
  source = "../../modules/vpc"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
  aws_region         = var.aws_region

  # Cost optimization: Single NAT Gateway for dev
  enable_nat_gateway = true
  single_nat_gateway = true

  # Enable VPC endpoints to reduce NAT Gateway costs
  enable_vpc_endpoints = true

  # Enable flow logs for security monitoring
  enable_flow_logs         = var.enable_flow_logs
  flow_logs_retention_days = 7 # Shorter retention for dev
  flow_logs_traffic_type   = "ALL"

  tags = local.common_tags
}

# ==============================================================================
# Security Groups Module
# ==============================================================================

module "security_groups" {
  source = "../../modules/security-groups"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id

  tags = local.common_tags
}

# ==============================================================================
# S3 Module
# ==============================================================================

module "s3" {
  source = "../../modules/s3"

  project_name = var.project_name
  environment  = var.environment
  account_id   = data.aws_caller_identity.current.account_id

  # CloudFront distribution ARN (will be updated after CloudFront is created)
  cloudfront_distribution_arn = "" # Initial deployment

  # Versioning (disabled for dev to save costs)
  enable_versioning = false

  # Lifecycle rules
  enable_lifecycle_rules     = true
  transition_to_ia_days      = 90
  transition_to_glacier_days = 180

  # CORS configuration
  enable_cors          = true
  cors_allowed_origins = ["https://${var.frontend_domain}"]

  # Access logging
  enable_access_logging = true
  logs_expiration_days  = 90

  # Backup retention
  backup_retention_days = 365

  # Encryption
  kms_key_arn = null # Use AWS managed keys for dev

  common_tags = local.common_tags
}

# After initial S3 creation, update CloudFront distribution ARN
# This will be done in a second apply after CloudFront is created

# ==============================================================================
# ACM Module (SSL/TLS Certificates)
# ==============================================================================

# module "acm" {
#   source = "../../modules/acm"

#   providers = {
#     aws           = aws
#     aws.us_east_1 = aws.us_east_1
#   }

#   project_name = var.project_name
#   environment  = var.environment

#   # ALB Certificate (regional)
#   create_alb_certificate    = true
#   domain_name               = var.backend_domain
#   subject_alternative_names = ["*.${var.domain_name}"]

#   # CloudFront Certificate (us-east-1)
#   create_cloudfront_certificate        = true
#   cloudfront_domain_name               = var.frontend_domain
#   cloudfront_subject_alternative_names = []

#   # DNS validation
#   validation_method = "DNS"
#   route53_zone_id   = module.route53.hosted_zone_id # Use zone from Route53 module

#   # Certificate expiration monitoring
#   enable_expiration_alarms  = true
#   expiration_days_threshold = 30
#   alarm_actions             = [] # Add SNS topic ARN if you have one

#   common_tags = local.common_tags
# }

# ==============================================================================
# CloudFront Module
# ==============================================================================

module "cloudfront" {
  source = "../../modules/cloudfront"

  project_name = var.project_name
  environment  = var.environment

  # S3 origin configuration
  s3_bucket_id                   = module.s3.assets_bucket_id
  s3_bucket_regional_domain_name = module.s3.assets_bucket_regional_domain_name

  # ALB origin configuration (optional - add when ALB is created)
  alb_domain_name = "" # Will be populated when ALB module is added

  # Domain configuration
  # domain_aliases      = [var.frontend_domain]
  # acm_certificate_arn = module.acm.cloudfront_certificate_arn

  # PHASE 1: Use these instead
  domain_aliases      = []
  acm_certificate_arn = ""

  # CloudFront settings
  default_root_object = "index.html"
  price_class         = "PriceClass_100" # US, Canada, Europe

  # Cache settings
  default_ttl = 86400    # 1 day
  max_ttl     = 31536000 # 1 year
  min_ttl     = 0

  # Request forwarding
  forward_cookies         = false
  forward_query_strings   = true
  forward_headers_enabled = false

  # Origin Shield (disabled for dev to save costs)
  enable_origin_shield = false
  origin_shield_region = var.aws_region

  # Geo restrictions
  geo_restriction_type      = "none"
  geo_restriction_locations = []

  # WAF (disabled for dev to save costs)
  waf_web_acl_arn = ""

  # Logging
  enable_logging = true
  logging_bucket = module.s3.logs_bucket_id != null ? "${module.s3.logs_bucket_id}.s3.amazonaws.com" : ""
  logging_prefix = "cloudfront/"

  # CORS
  #cors_allowed_origins = ["https://${var.frontend_domain}"]
  # PHASE 1: Open CORS - change this line
  # cors_allowed_origins = ["https://${var.frontend_domain}"]
  cors_allowed_origins = ["*"]


  # Content Security Policy
  content_security_policy = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https://${var.backend_domain};"

  # URL rewriting for SPA
  enable_url_rewrite = true

  # Custom error responses
  custom_error_responses = [
    {
      error_code            = 403
      response_code         = 200
      response_page_path    = "/index.html"
      error_caching_min_ttl = 300
    },
    {
      error_code            = 404
      response_code         = 200
      response_page_path    = "/index.html"
      error_caching_min_ttl = 300
    }
  ]

  common_tags = local.common_tags
}

# ==============================================================================
# Route53 Module
# ==============================================================================

module "route53" {
  source = "../../modules/route53"

  project_name = var.project_name
  environment  = var.environment

  # Domain configuration
  domain_name        = var.domain_name
  create_hosted_zone = true # Set to true if creating new zone

  # Frontend (CloudFront)
  # PHASE 1: Don't create DNS records yet
  # frontend_subdomain     = "www" # Results in www.sankofagrid.com
  # cloudfront_domain_name = module.cloudfront.distribution_domain_name
  # cloudfront_zone_id     = module.cloudfront.distribution_hosted_zone_id
  # PHASE 1: Use empty values
  create_cloudfront_records = false
  frontend_subdomain        = ""
  cloudfront_domain_name    = ""
  cloudfront_zone_id        = ""

  # Backend (ALB) - will be configured after ALB is created
  api_subdomain = "api" # Results in api.sankofagrid.com
  alb_dns_name  = ""    # Will be populated when ALB module is added
  alb_zone_id   = ""    # Will be populated when ALB module is added

  # IPv6 support
  enable_ipv6 = true

  # WWW redirect
  create_www_record = false # We're already using www as primary

  # Health checks
  enable_health_checks           = false # Will enable when ALB is added
  health_check_path              = "/health"
  health_check_failure_threshold = 3
  health_check_interval          = 30

  # Alarms
  alarm_actions = [] # Add SNS topic ARN if you have one

  # DNS records for verification (e.g., Google, etc.)
  verification_records = {}

  # Email configuration
  mx_records   = []
  spf_record   = ""
  dkim_records = {}
  dmarc_record = ""

  # CAA records
  caa_records = [
    "0 issue \"amazon.com\"",
    "0 issue \"letsencrypt.org\""
  ]

  common_tags = local.common_tags
}

# ==============================================================================
# CloudWatch Module
# ==============================================================================

module "cloudwatch" {
  source = "../../modules/cloudwatch"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  # Alert configuration
  alert_email_addresses = var.alert_email_addresses

  # Resource identifiers (will be populated as resources are created)
  ecs_cluster_name       = "" # Will be populated when ECS module is added
  alb_arn                = "" # Will be populated when ALB module is added
  alb_arn_suffix         = "" # Will be populated when ALB module is added
  rds_instance_id        = "" # Will be populated when RDS module is added
  elasticache_cluster_id = "" # Will be populated when ElastiCache module is added

  # Alarm thresholds
  ecs_cpu_threshold               = 80
  ecs_memory_threshold            = 80
  alb_5xx_threshold               = 10
  alb_response_time_threshold     = 2
  rds_cpu_threshold               = 80
  rds_storage_threshold_bytes     = 5368709120 # 5 GB
  rds_connections_threshold       = 80
  elasticache_cpu_threshold       = 75
  elasticache_memory_threshold    = 90
  elasticache_evictions_threshold = 1000

  # Log retention
  log_retention_days = 30

  # Encryption
  kms_key_arn = null # Use AWS managed keys for dev

  common_tags = local.common_tags
}

# ==============================================================================
# IAM Module
# ==============================================================================

module "iam" {
  source = "../../modules/iam"

  project_name = var.project_name
  environment  = var.environment

  # S3 buckets for IAM policies
  frontend_bucket_arn = module.s3.assets_bucket_arn

  # Secrets Manager ARNs (using wildcard for flexibility)
  db_secrets_arns = [
    "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/${var.environment}/*"
  ]

  tags = local.common_tags
}

