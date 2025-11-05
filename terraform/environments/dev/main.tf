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
  region  = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      CostCenter  = "Engineering"
    }
  }
}

provider "aws" {
  alias   = "eu_west_1"
  region  = "eu-west-1"

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      CostCenter  = "Engineering"
    }
  }
}

provider "aws" {
  alias   = "us_east_1"
  region  = "us-east-1"

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
      Repository  = "get-devops"
      Team        = "DevOps"
      CostCenter  = "Engineering"
      Compliance  = "Standard"
      Backup      = "Daily"
      Monitoring  = "Enabled"
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

  # NAT Gateway enabled for all external connectivity (SMTP, AWS services, etc.)
  # Cost: ~$32/month (NAT Gateway hourly charge) + ~$10-30/month (data transfer)
  # Required for notification service to send emails via Gmail SMTP
  # ECS will pull images via NAT Gateway (no VPC endpoints)
  # Services will access Secrets Manager, CloudWatch, S3 via NAT Gateway
  enable_nat_gateway = true  # Required for external SMTP and AWS service access
  single_nat_gateway = true  # Single NAT for cost optimization

  # COST OPTIMIZATION: VPC Endpoints disabled - all AWS traffic routes through NAT Gateway
  # Saves ~$88-176/month in VPC endpoint costs with minimal latency impact
  enable_vpc_endpoints = false # Route all AWS service traffic through NAT Gateway

  enable_flow_logs         = var.enable_flow_logs
  flow_logs_retention_days = 3
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
# ACM Module - SSL/TLS Certificates
# ==============================================================================

module "acm" {
  source = "../../modules/acm"

  project_name = var.project_name
  environment  = var.environment

  # ALB Certificate (eu-west-1)
  create_alb_certificate        = true
  alb_domain_name               = "api.sankofagrid.com"
  alb_subject_alternative_names = []

  # CloudFront certificate already exists manually, skip creation
  create_cloudfront_certificate        = false
  cloudfront_domain_name               = "events.sankofagrid.com"
  cloudfront_subject_alternative_names = []

  common_tags = local.common_tags

  providers = {
    aws.us_east_1 = aws.us_east_1
  }
}

# ==============================================================================
# S3 Module
# ==============================================================================

module "s3" {
  source = "../../modules/s3"

  project_name = var.project_name
  environment  = var.environment
  account_id   = data.aws_caller_identity.current.account_id

  # Leave empty - bucket policy created separately below to avoid circular dependency
  cloudfront_distribution_arn = ""

  enable_versioning      = false
  enable_lifecycle_rules = true

  transition_to_ia_days      = 90
  transition_to_glacier_days = 180

  enable_cors          = true
  cors_allowed_origins = ["https://events.sankofagrid.com", "https://www.sankofagrid.com", "http://localhost:4200"]

  enable_access_logging = true
  logs_expiration_days  = 3

  backup_retention_days = 3

  kms_key_arn = null

  common_tags = local.common_tags
}

# ==============================================================================
# Secrets Manager Module - JWT Secret
# ==============================================================================

module "secrets_manager" {
  source = "../../modules/secrets-manager"

  project_name            = var.project_name
  environment             = var.environment
  recovery_window_in_days = 7

  tags = local.common_tags
}

# ==============================================================================
# IAM Module
# ==============================================================================

module "iam" {
  source = "../../modules/iam"

  project_name        = var.project_name
  environment         = var.environment
  frontend_bucket_arn = module.s3.assets_bucket_arn

  # Use wildcard for flexibility - actual secrets created by RDS modules
  db_secrets_arns = [
    "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/${var.environment}/*"
  ]

  jwt_secret_arn = module.secrets_manager.jwt_secret_arn

  tags = local.common_tags
}

# ==============================================================================
# CloudFront Module
# ==============================================================================

module "cloudfront" {
  source = "../../modules/cloudfront"

  project_name                   = var.project_name
  environment                    = var.environment
  s3_bucket_id                   = module.s3.assets_bucket_id
  s3_bucket_regional_domain_name = module.s3.assets_bucket_regional_domain_name

  alb_domain_name = "api.sankofagrid.com" # Backend API domain

  domain_aliases      = ["events.sankofagrid.com"]
  acm_certificate_arn = "arn:aws:acm:us-east-1:904570587823:certificate/fa496bd5-865f-4b1e-a189-f30245b0373b"

  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  # Low TTL for dev - users get fresh content quickly (5 minutes)
  default_ttl = 300
  max_ttl     = 3600
  min_ttl     = 0

  forward_cookies         = false
  forward_query_strings   = true
  forward_headers_enabled = false

  enable_origin_shield = false
  origin_shield_region = var.aws_region

  geo_restriction_type      = "none"
  geo_restriction_locations = []

  waf_web_acl_arn = ""

  enable_logging = true
  logging_bucket = module.s3.logs_bucket_id != null ? "${module.s3.logs_bucket_id}.s3.amazonaws.com" : ""
  logging_prefix = "cloudfront/"

  cors_allowed_origins = ["https://events.sankofagrid.com", "https://www.sankofagrid.com", "http://localhost:4200"]

  content_security_policy = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; img-src 'self' data: https:; font-src 'self' data: https://fonts.gstatic.com https://fonts.googleapis.com; connect-src 'self' https: https://api.sankofagrid.com;"

  enable_url_rewrite = true

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
# CRITICAL: S3 Bucket Policy for CloudFront OAC Access
# ==============================================================================
# This must be created AFTER CloudFront to avoid circular dependency.
# This policy allows CloudFront to access S3 objects via Origin Access Control.

resource "aws_s3_bucket_policy" "cloudfront_access" {
  bucket = module.s3.assets_bucket_id

  depends_on = [
    module.cloudfront,
    module.s3
  ]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${module.s3.assets_bucket_arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = module.cloudfront.distribution_arn
          }
        }
      }
    ]
  })
}

# ==============================================================================
# Route53 Module
# ==============================================================================

module "route53" {
  source = "../../modules/route53"

  project_name       = var.project_name
  environment        = var.environment
  domain_name        = var.domain_name
  create_hosted_zone = true

  # Phase 1: CloudFront not configured yet
  create_cloudfront_records = false
  frontend_subdomain        = ""
  cloudfront_domain_name    = ""
  cloudfront_zone_id        = ""

  # Backend ALB - will be configured when ALB is ready
  create_alb_records = false
  api_subdomain      = "api"
  alb_dns_name       = ""
  alb_zone_id        = ""

  enable_ipv6       = true
  create_www_record = false

  enable_health_checks           = false
  health_check_path              = "/health"
  health_check_failure_threshold = 3
  health_check_interval          = 30

  alarm_actions        = []
  verification_records = {}
  mx_records           = []
  spf_record           = ""
  dkim_records         = {}
  dmarc_record         = ""

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

  project_name          = var.project_name
  environment           = var.environment
  aws_region            = var.aws_region
  alert_email_addresses = var.alert_email_addresses

  # Resource identifiers - populated as resources are created
  ecs_cluster_name          = module.ecs.cluster_name
  alb_arn                   = module.alb.alb_arn
  alb_arn_suffix            = module.alb.alb_arn_suffix
  rds_instance_id           = module.rds.primary_instance_ids["auth"]
  elasticache_cluster_id    = module.elasticache.replication_group_id
  cloudfront_distribution_id = module.cloudfront.distribution_id

  # Control alarm creation with boolean flags
  create_ecs_alarms         = true
  create_alb_alarms         = true
  create_rds_alarms         = true
  create_elasticache_alarms = true

  # Alarm thresholds
  ecs_cpu_threshold               = 80
  ecs_memory_threshold            = 80
  alb_5xx_threshold               = 10
  alb_response_time_threshold     = 2
  rds_cpu_threshold               = 80
  rds_storage_threshold_bytes     = 5368709120
  rds_connections_threshold       = 80
  elasticache_cpu_threshold       = 75
  elasticache_memory_threshold    = 90
  elasticache_evictions_threshold = 1000

  log_retention_days = 3
  kms_key_arn        = null

  common_tags = local.common_tags
}

# ==============================================================================
# CloudWatch Service Dashboards Module
# ==============================================================================

module "cloudwatch_dashboards" {
  source = "../../modules/cloudwatch-dashboards"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  ecs_cluster_name             = module.ecs.cluster_name
  auth_target_group_arn_suffix = module.alb.target_group_arn_suffixes["auth"]
  event_target_group_arn_suffix = lookup(module.alb.target_group_arn_suffixes, "event", "")
  auth_db_instance_id          = module.rds.primary_instance_ids["auth"]
  elasticache_cluster_id       = module.elasticache.replication_group_id
  cloudfront_distribution_id   = module.cloudfront.distribution_id
  s3_bucket_name               = module.s3.assets_bucket_id

  tags = local.common_tags
}

# ==============================================================================
# ECR Module
# ==============================================================================

module "ecr" {
  source = "../../modules/ecr"

  project_name = var.project_name
  environment  = var.environment

  image_tag_mutability          = "MUTABLE"
  enable_image_scanning         = true
  kms_key_arn                   = null
  max_image_count               = 30
  untagged_image_retention_days = 7

  enable_cross_account_access = false
  allowed_account_ids         = []

  enable_replication = false
  replication_region = "us-west-2"

  tags = local.common_tags
}

# ==============================================================================
# RDS Module
# ==============================================================================

module "rds" {
  source = "../../modules/rds"

  project_name      = var.project_name
  environment       = var.environment
  subnet_ids        = module.vpc.private_data_subnet_ids
  security_group_id = module.security_groups.rds_security_group_id

  # Auth DB - Currently running (upgraded to t3.medium)
  auth_db_instance_class        = "db.t3.medium"
  auth_db_allocated_storage     = 20
  auth_db_max_allocated_storage = 100

  # Event DB - Not created yet
  # event_db_instance_class        = "db.t3.micro"
  # event_db_allocated_storage     = 20
  # event_db_max_allocated_storage = 100

  # Booking DB - Not created yet
  # booking_db_instance_class        = "db.t3.micro"
  # booking_db_allocated_storage     = 20
  # booking_db_max_allocated_storage = 100

  # Payment DB - Not created yet
  # payment_db_instance_class        = "db.t3.micro"
  # payment_db_allocated_storage     = 20
  # payment_db_max_allocated_storage = 100

  postgres_version = "15.12"
  postgres_family  = "postgres15"
  master_username  = "dbadmin"
  max_connections  = "100"

  storage_type     = "gp3"
  provisioned_iops = null # Use gp3 default (3000 IOPS)

  # Dev: Single-AZ, no replicas
  multi_az             = false
  create_read_replicas = false

  backup_retention_days = 3
  backup_window         = "03:00-04:00"
  maintenance_window    = "sun:04:00-sun:05:00"
  skip_final_snapshot   = true

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  kms_key_arn = null

  enable_enhanced_monitoring  = false
  enable_performance_insights = false

  deletion_protection        = false
  auto_minor_version_upgrade = true
  apply_immediately          = true

  secret_recovery_window_days = 7

  cpu_alarm_threshold           = 80
  storage_alarm_threshold_bytes = 5368709120
  connections_alarm_threshold   = 80
  alarm_actions                 = [module.cloudwatch.sns_topic_arn]

  tags = local.common_tags
}



# ==============================================================================
# ElastiCache Module
# ==============================================================================

module "elasticache" {
  source = "../../modules/elasticache"

  project_name       = var.project_name
  environment        = var.environment
  subnet_ids         = module.vpc.private_data_subnet_ids
  security_group_ids = [module.security_groups.elasticache_security_group_id]

  redis_version = "7.1"
  redis_family  = "redis7"
  redis_port    = 6379
  node_type     = "cache.t3.micro"

  # Dev: Single node
  cluster_mode_enabled    = false
  num_cache_nodes         = 1
  num_node_groups         = 1 # Not used in single-node mode
  replicas_per_node_group = 0 # No replicas in dev

  automatic_failover_enabled = false
  multi_az_enabled           = false

  maintenance_window         = "sun:05:00-sun:06:00"
  snapshot_window            = "03:00-04:00"
  snapshot_retention_limit   = 3
  auto_minor_version_upgrade = true
  apply_immediately          = true

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = null

  maxmemory_policy = "allkeys-lru"
  timeout          = "300"

  slow_log_destination        = null
  slow_log_destination_type   = "cloudwatch-logs"
  engine_log_destination      = null
  engine_log_destination_type = "cloudwatch-logs"
  log_format                  = "json"

  notification_topic_arn = module.cloudwatch.sns_topic_arn

  enable_cloudwatch_alarms     = true
  cpu_utilization_threshold    = 75
  memory_utilization_threshold = 90
  evictions_threshold          = 1000
  swap_usage_threshold         = 52428800
  alarm_actions                = [module.cloudwatch.sns_topic_arn]

  tags = local.common_tags
}

# ==============================================================================
# SQS-SNS Module
# ==============================================================================

module "sqs-sns" {
  source = "../../modules/sqs-sns"

  project_name  = var.project_name
  environment   = var.environment
  kms_key_arn   = null
  alarm_actions = [module.cloudwatch.sns_topic_arn]

  tags = local.common_tags
}

# ==============================================================================
# ALB Module
# ==============================================================================

module "alb" {
  source = "../../modules/alb"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  alb_security_group_id = module.security_groups.alb_security_group_id

  # Use regional certificate (once validated)
  certificate_arn = module.acm.alb_certificate_arn
  ssl_policy      = "ELBSecurityPolicy-TLS-1-2-2017-01"

  health_check_healthy_threshold   = 2
  health_check_unhealthy_threshold = 3
  health_check_timeout             = 5
  health_check_interval            = 30

  deregistration_delay = 30

  enable_access_logs = true
  access_logs_bucket = module.s3.logs_bucket_id
  access_logs_prefix = "alb"

  enable_deletion_protection = false

  response_time_alarm_threshold = 2
  error_5xx_alarm_threshold     = 10
  alarm_actions                 = [module.cloudwatch.sns_topic_arn]

  tags = local.common_tags
}

# ==============================================================================
# ECS Module
# ==============================================================================

module "ecs" {
  source = "../../modules/ecs"

  project_name          = var.project_name
  environment           = var.environment
  aws_region            = var.aws_region
  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_app_subnet_ids
  ecs_security_group_id = module.security_groups.ecs_security_group_id

  task_execution_role_arn = module.iam.ecs_task_execution_role_arn
  task_role_arns          = module.iam.ecs_task_role_arns

  service_discovery_namespace = "eventplanner.local"

  ecr_repository_urls = module.ecr.repository_urls
  image_tag           = "latest"

  db_secret_arns = module.rds.secret_arns
  redis_endpoint = module.elasticache.primary_endpoint_address

  jwt_secret_arn         = module.secrets_manager.jwt_secret_arn
  jwt_access_expiration  = var.jwt_access_expiration
  jwt_refresh_expiration = var.jwt_refresh_expiration

  aws_credentials_secret_arn = module.secrets_manager.aws_credentials_secret_arn
  google_credentials_secret_arn = module.secrets_manager.google_credentials_secret_arn

  sqs_queue_urls  = module.sqs-sns.queue_urls
  sqs_queue_names = module.sqs-sns.queue_names
  s3_bucket_name  = module.s3.assets_bucket_id
  alb_dns_name    = module.alb.alb_dns_name

  target_group_arns = module.alb.target_group_arns
  alb_listener_arn  = module.alb.http_listener_arn

  enable_container_insights = true
  enable_fargate_spot       = false

  log_retention_days = 3
  kms_key_arn        = null

  cpu_target_value    = 70
  memory_target_value = 75
  scale_in_cooldown   = 300
  scale_out_cooldown  = 60

  tags = local.common_tags
}
