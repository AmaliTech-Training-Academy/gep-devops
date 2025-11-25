# terraform/environments/prod/main.tf
# ==============================================================================
# Production Environment - Main Configuration
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

  enable_nat_gateway = true
  single_nat_gateway = false # Production: NAT Gateway per AZ

  enable_vpc_endpoints = true

  enable_flow_logs         = var.enable_flow_logs
  flow_logs_retention_days = 30
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
# ACM Module
# ==============================================================================

module "acm" {
  source = "../../modules/acm"

  project_name = var.project_name
  environment  = var.environment

  create_alb_certificate        = true
  alb_domain_name               = "api.sankofagrid.com"
  alb_subject_alternative_names = []

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

  cloudfront_distribution_arn = ""

  enable_versioning      = true # Production: Enable versioning
  enable_lifecycle_rules = true

  transition_to_ia_days      = 30
  transition_to_glacier_days = 90

  enable_cors          = true
  cors_allowed_origins = ["https://events.sankofagrid.com", "https://www.sankofagrid.com"]

  enable_access_logging = true
  logs_expiration_days  = 365

  backup_retention_days = 365

  kms_key_arn = null

  common_tags = local.common_tags
}

# ==============================================================================
# Secrets Manager Module
# ==============================================================================

module "secrets_manager" {
  source = "../../modules/secrets-manager"

  project_name            = var.project_name
  environment             = var.environment
  recovery_window_in_days = 30 # Production: Extended recovery window

  tags = local.common_tags
}

# ==============================================================================
# IAM Module
# ==============================================================================

module "iam" {
  source = "../../modules/iam"

  project_name             = var.project_name
  environment              = var.environment
  frontend_bucket_arn      = module.s3.assets_bucket_arn
  backend_files_bucket_arn = module.s3.backend_files_bucket_arn

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

  alb_domain_name = "api.sankofagrid.com"

  domain_aliases      = ["events.sankofagrid.com"]
  acm_certificate_arn = "arn:aws:acm:us-east-1:904570587823:certificate/fa496bd5-865f-4b1e-a189-f30245b0373b"

  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  default_ttl = 86400
  max_ttl     = 31536000
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

  cors_allowed_origins = ["https://events.sankofagrid.com", "https://www.sankofagrid.com"]

  content_security_policy = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; img-src 'self' data: https: blob:; font-src 'self' data: https://fonts.gstatic.com https://fonts.googleapis.com; connect-src 'self' https: https://api.sankofagrid.com;"

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
# S3 Bucket Policy for CloudFront
# ==============================================================================

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
# CloudWatch Module
# ==============================================================================

module "cloudwatch" {
  source = "../../modules/cloudwatch"

  project_name          = var.project_name
  environment           = var.environment
  aws_region            = var.aws_region
  alert_email_addresses = var.alert_email_addresses

  ecs_cluster_name           = module.ecs.cluster_name
  alb_arn                    = module.alb.alb_arn
  alb_arn_suffix             = module.alb.alb_arn_suffix
  rds_instance_id            = module.rds.primary_instance_id
  elasticache_cluster_id     = module.elasticache.replication_group_id
  cloudfront_distribution_id = module.cloudfront.distribution_id

  create_ecs_alarms         = true
  create_alb_alarms         = true
  create_rds_alarms         = true
  create_elasticache_alarms = true

  ecs_cpu_threshold               = 80
  ecs_memory_threshold            = 85
  alb_5xx_threshold               = 10
  alb_response_time_threshold     = 2
  rds_cpu_threshold               = 80
  rds_storage_threshold_bytes     = 10737418240 # 10 GB
  rds_connections_threshold       = 80
  elasticache_cpu_threshold       = 75
  elasticache_memory_threshold    = 90
  elasticache_evictions_threshold = 1000

  log_retention_days = 30
  kms_key_arn        = null

  common_tags = local.common_tags
}

# ==============================================================================
# CloudWatch Dashboards Module
# ==============================================================================

module "cloudwatch_dashboards" {
  source = "../../modules/cloudwatch-dashboards"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  ecs_cluster_name              = module.ecs.cluster_name
  auth_target_group_arn_suffix  = module.alb.target_group_arn_suffixes["auth"]
  event_target_group_arn_suffix = lookup(module.alb.target_group_arn_suffixes, "event", "")
  auth_db_instance_id           = module.rds.primary_instance_id
  elasticache_cluster_id        = module.elasticache.replication_group_id
  cloudfront_distribution_id    = module.cloudfront.distribution_id
  s3_bucket_name                = module.s3.assets_bucket_id

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
  max_image_count               = 50 # Production: More images
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

  db_instance_class        = "db.t4g.large"
  db_allocated_storage     = 100
  db_max_allocated_storage = 1000

  postgres_version = "15.12"
  postgres_family  = "postgres15"
  master_username  = "dbadmin"
  max_connections  = "200"

  storage_type     = "gp3"
  provisioned_iops = null

  multi_az             = true
  create_read_replicas = true

  backup_retention_days = 30
  backup_window         = "03:00-04:00"
  maintenance_window    = "sun:04:00-sun:05:00"
  skip_final_snapshot   = false

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  kms_key_arn = null

  enable_enhanced_monitoring  = true
  enable_performance_insights = true

  deletion_protection        = true
  auto_minor_version_upgrade = true
  apply_immediately          = false

  secret_recovery_window_days = 30

  cpu_alarm_threshold           = 80
  storage_alarm_threshold_bytes = 10737418240
  connections_alarm_threshold   = 160
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
  node_type     = "cache.t4g.medium"

  cluster_mode_enabled    = true
  num_cache_nodes         = 1
  num_node_groups         = 3
  replicas_per_node_group = 1

  automatic_failover_enabled = true
  multi_az_enabled           = true

  maintenance_window         = "sun:05:00-sun:06:00"
  snapshot_window            = "03:00-04:00"
  snapshot_retention_limit   = 7
  auto_minor_version_upgrade = true
  apply_immediately          = false

  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = module.secrets_manager.redis_auth_token

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

  enable_deletion_protection = true

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
  jwt_access_expiration  = 3600000
  jwt_refresh_expiration = 86400000

  google_credentials_secret_arn   = module.secrets_manager.google_credentials_secret_arn
  paystack_credentials_secret_arn = module.secrets_manager.paystack_credentials_secret_arn
  redis_credentials_secret_arn    = module.secrets_manager.redis_credentials_secret_arn

  sqs_queue_urls               = module.sqs-sns.queue_urls
  sqs_queue_names              = module.sqs-sns.queue_names
  sns_topic_arns               = module.sqs-sns.topic_arns
  s3_bucket_name               = module.s3.assets_bucket_id
  s3_backend_files_bucket_name = module.s3.backend_files_bucket_id
  alb_dns_name                 = module.alb.alb_dns_name

  target_group_arns = module.alb.target_group_arns
  alb_listener_arn  = module.alb.http_listener_arn

  enable_container_insights = true
  enable_fargate_spot       = true

  log_retention_days = 30
  kms_key_arn        = null

  cpu_target_value    = 70
  memory_target_value = 75
  scale_in_cooldown   = 300
  scale_out_cooldown  = 60

  payment_service_url = "https://api.sankofagrid.com"

  tags = local.common_tags
}
