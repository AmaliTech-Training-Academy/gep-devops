# # terraform/environments/dev/main.tf
# # ==============================================================================
# # Development Environment - Main Configuration
# # ==============================================================================
# # This is the main entry point for the development environment infrastructure.
# # It orchestrates all modules to deploy a cost-optimized, single-AZ environment.
# #
# # Environment Characteristics:
# # - Single AZ deployment for cost optimization
# # - Minimal resource allocation
# # - No read replicas for databases
# # - Single ElastiCache node
# # - 1 ECS task per microservice
# # - Estimated cost: ~$248/month (24/7) or ~$75-95/month (weekday-only)
# # ==============================================================================

# terraform {
#   required_version = ">= 1.5.0"

#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = "~> 5.0"
#     }
#   }
# }

# # ==============================================================================
# # Provider Configuration
# # ==============================================================================

# provider "aws" {
#   region = var.aws_region

#   default_tags {
#     tags = {
#       Project     = var.project_name
#       Environment = var.environment
#       ManagedBy   = "Terraform"
#       CostCenter  = "Engineering"
#     }
#   }
# }

# # ==============================================================================
# # Data Sources
# # ==============================================================================

# data "aws_caller_identity" "current" {}

# data "aws_region" "current" {}

# # ==============================================================================
# # VPC Module
# # ==============================================================================

# module "vpc" {
#   source = "../../modules/vpc"

#   project_name       = var.project_name
#   environment        = var.environment
#   vpc_cidr           = var.vpc_cidr
#   availability_zones = var.availability_zones
#   aws_region         = var.aws_region

#   # Cost optimization: Single NAT Gateway for dev
#   enable_nat_gateway = true
#   single_nat_gateway = true

#   # Enable VPC endpoints to reduce NAT Gateway costs
#   enable_vpc_endpoints = true

#   # Enable flow logs for security monitoring
#   enable_flow_logs          = var.enable_flow_logs
#   flow_logs_retention_days  = 7  # Shorter retention for dev
#   flow_logs_traffic_type    = "ALL"

#   tags = var.tags
# }

# # ==============================================================================
# # Security Groups Module
# # ==============================================================================

# module "security_groups" {
#   source = "../../modules/security-groups"

#   project_name = var.project_name
#   environment  = var.environment
#   vpc_id       = module.vpc.vpc_id

#   tags = var.tags
# }

# # ==============================================================================
# # IAM Module
# # ==============================================================================

# module "iam" {
#   source = "../../modules/iam"

#   project_name = var.project_name
#   environment  = var.environment

#   # S3 buckets for IAM policies
#   frontend_bucket_arn = module.s3.frontend_bucket_arn
#   logs_bucket_arn     = module.s3.logs_bucket_arn

#   # Secrets Manager ARNs
#   db_secrets_arns = [
#     "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/${var.environment}/rds/*",
#     "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/${var.environment}/documentdb/*",
#     "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/${var.environment}/jwt/*"
#   ]

#   tags = var.tags
# }

# # ==============================================================================
# # RDS Module - Auth Database
# # ==============================================================================

# module "rds_auth" {
#   source = "../../modules/rds"

#   project_name    = var.project_name
#   environment     = var.environment
#   database_name   = "auth"

#   # Instance configuration (cost-optimized)
#   instance_class       = "db.t4g.micro"
#   allocated_storage    = 20
#   max_allocated_storage = 100

#   # Single-AZ for dev
#   multi_az             = false
#   create_read_replicas = false

#   # Network configuration
#   vpc_id                 = module.vpc.vpc_id
#   subnet_ids             = module.vpc.private_data_subnet_ids
#   vpc_security_group_ids = [module.security_groups.rds_security_group_id]

#   # Backup configuration
#   backup_retention_period = 7
#   backup_window           = "03:00-04:00"
#   maintenance_window      = "sun:04:00-sun:05:00"

#   # Monitoring
#   enabled_cloudwatch_logs_exports = ["postgresql"]
#   performance_insights_enabled    = false  # Disabled for cost

#   # Secrets
#   master_password_secret_arn = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/${var.environment}/rds/auth-db/master-password"

#   tags = var.tags
# }

# # ==============================================================================
# # RDS Module - Event Database
# # ==============================================================================

# module "rds_event" {
#   source = "../../modules/rds"

#   project_name    = var.project_name
#   environment     = var.environment
#   database_name   = "event"

#   instance_class       = "db.t4g.small"
#   allocated_storage    = 20
#   max_allocated_storage = 100

#   multi_az             = false
#   create_read_replicas = false

#   vpc_id                 = module.vpc.vpc_id
#   subnet_ids             = module.vpc.private_data_subnet_ids
#   vpc_security_group_ids = [module.security_groups.rds_security_group_id]

#   backup_retention_period = 7
#   backup_window           = "03:00-04:00"
#   maintenance_window      = "sun:04:00-sun:05:00"

#   enabled_cloudwatch_logs_exports = ["postgresql"]
#   performance_insights_enabled    = false

#   master_password_secret_arn = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/${var.environment}/rds/event-db/master-password"

#   tags = var.tags
# }

# # ==============================================================================
# # RDS Module - Booking Database
# # ==============================================================================

# module "rds_booking" {
#   source = "../../modules/rds"

#   project_name    = var.project_name
#   environment     = var.environment
#   database_name   = "booking"

#   instance_class       = "db.t4g.small"
#   allocated_storage    = 20
#   max_allocated_storage = 100

#   multi_az             = false
#   create_read_replicas = false

#   vpc_id                 = module.vpc.vpc_id
#   subnet_ids             = module.vpc.private_data_subnet_ids
#   vpc_security_group_ids = [module.security_groups.rds_security_group_id]

#   backup_retention_period = 7
#   backup_window           = "03:00-04:00"
#   maintenance_window      = "sun:04:00-sun:05:00"

#   enabled_cloudwatch_logs_exports = ["postgresql"]
#   performance_insights_enabled    = false

#   master_password_secret_arn = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/${var.environment}/rds/booking-db/master-password"

#   tags = var.tags
# }

# # ==============================================================================
# # RDS Module - Payment Database
# # ==============================================================================

# module "rds_payment" {
#   source = "../../modules/rds"

#   project_name    = var.project_name
#   environment     = var.environment
#   database_name   = "payment"

#   instance_class       = "db.t4g.micro"
#   allocated_storage    = 20
#   max_allocated_storage = 100

#   multi_az             = false
#   create_read_replicas = false

#   vpc_id                 = module.vpc.vpc_id
#   subnet_ids             = module.vpc.private_data_subnet_ids
#   vpc_security_group_ids = [module.security_groups.rds_security_group_id]

#   backup_retention_period = 7
#   backup_window           = "03:00-04:00"
#   maintenance_window      = "sun:04:00-sun:05:00"

#   enabled_cloudwatch_logs_exports = ["postgresql"]
#   performance_insights_enabled    = false

#   master_password_secret_arn = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/${var.environment}/rds/payment-db/master-password"

#   tags = var.tags
# }

# # ==============================================================================
# # DocumentDB Module
# # ==============================================================================

# module "documentdb" {
#   source = "../../modules/documentdb"

#   project_name        = var.project_name
#   environment         = var.environment
#   cluster_identifier  = "${var.project_name}-${var.environment}-audit-logs"

#   # Single instance for dev
#   instance_class  = "db.t3.medium"
#   instance_count  = 1

#   # Network configuration
#   vpc_id                 = module.vpc.vpc_id
#   subnet_ids             = module.vpc.private_data_subnet_ids
#   vpc_security_group_ids = [module.security_groups.documentdb_security_group_id]

#   # Backup configuration
#   backup_retention_period = 7
#   preferred_backup_window = "03:00-04:00"

#   # Secrets
#   master_password_secret_arn = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}/${var.environment}/documentdb/master-password"

#   tags = var.tags
# }

# # ==============================================================================
# # ElastiCache Module
# # ==============================================================================

# module "elasticache" {
#   source = "../../modules/elasticache"

#   project_name      = var.project_name
#   environment       = var.environment
#   cluster_id        = "${var.project_name}-${var.environment}-redis"

#   # Single node for dev
#   node_type         = "cache.t3.micro"
#   num_cache_nodes   = 1
#   engine_version    = "7.0"

#   # Network configuration
#   vpc_id                 = module.vpc.vpc_id
#   subnet_ids             = module.vpc.private_data_subnet_ids
#   vpc_security_group_ids = [module.security_groups.elasticache_security_group_id]

#   # Backup configuration
#   snapshot_retention_limit = 7
#   snapshot_window          = "03:00-05:00"

#   tags = var.tags
# }

# # ==============================================================================
# # ECS Cluster Module
# # ==============================================================================

# module "ecs" {
#   source = "../../modules/ecs"

#   project_name = var.project_name
#   environment  = var.environment

#   # Capacity providers
#   enable_fargate_spot = false  # Disabled for simplicity in dev

#   # Container Insights (disabled for cost)
#   enable_container_insights = false

#   tags = var.tags
# }

# # ==============================================================================
# # CloudMap Service Discovery
# # ==============================================================================

# module "cloudmap" {
#   source = "../../modules/cloudmap"

#   project_name = var.project_name
#   environment  = var.environment
#   vpc_id       = module.vpc.vpc_id

#   # Service discovery namespace
#   namespace_name = "eventplanner.local"

#   tags = var.tags
# }

# # ==============================================================================
# # S3 Module
# # ==============================================================================

# module "s3" {
#   source = "../../modules/s3"

#   project_name = var.project_name
#   environment  = var.environment

#   # Frontend hosting bucket
#   create_frontend_bucket = true
#   frontend_domain        = var.frontend_domain

#   # Logs bucket
#   create_logs_bucket = true

#   # Versioning (disabled for dev to save costs)
#   enable_versioning = false

#   # Lifecycle rules
#   enable_lifecycle_rules = true

#   tags = var.tags
# }

# # ==============================================================================
# # ACM Module (SSL/TLS Certificates)
# # ==============================================================================

# module "acm" {
#   source = "../../modules/acm"

#   project_name = var.project_name
#   environment  = var.environment

#   # Domain configuration
#   domain_name               = var.domain_name
#   subject_alternative_names = [
#     "*.${var.domain_name}",
#     var.frontend_domain,
#     var.backend_domain
#   ]

#   # Route53 zone for DNS validation
#   route53_zone_id = module.route53.zone_id

#   tags = var.tags
# }

# # ==============================================================================
# # CloudFront Module
# # ==============================================================================

# module "cloudfront" {
#   source = "../../modules/cloudfront"

#   project_name = var.project_name
#   environment  = var.environment

#   # S3 origin configuration
#   frontend_bucket_id                = module.s3.frontend_bucket_id
#   frontend_bucket_regional_domain   = module.s3.frontend_bucket_regional_domain_name
#   frontend_bucket_arn               = module.s3.frontend_bucket_arn

#   # Domain configuration
#   domain_name     = var.frontend_domain
#   acm_certificate_arn = module.acm.certificate_arn

#   # Logging
#   logging_bucket = module.s3.logs_bucket_domain_name
#   logging_prefix = "cloudfront/"

#   # WAF (disabled for dev)
#   enable_waf = false

#   tags = var.tags
# }

# # ==============================================================================
# # Route53 Module
# # ==============================================================================

# module "route53" {
#   source = "../../modules/route53"

#   project_name = var.project_name
#   environment  = var.environment

#   # Domain configuration
#   domain_name = var.domain_name

#   # Frontend (CloudFront)
#   create_frontend_record = true
#   frontend_domain        = var.frontend_domain
#   cloudfront_domain_name = module.cloudfront.distribution_domain_name
#   cloudfront_zone_id     = module.cloudfront.distribution_hosted_zone_id

#   # Backend (ALB) - will be configured after ALB is created
#   create_backend_record = true
#   backend_domain        = var.backend_domain
#   alb_domain_name       = module.alb.dns_name
#   alb_zone_id           = module.alb.zone_id

#   tags = var.tags
# }

# # ==============================================================================
# # ALB Module
# # ==============================================================================

# module "alb" {
#   source = "../../modules/alb"

#   project_name = var.project_name
#   environment  = var.environment

#   # Network configuration
#   vpc_id             = module.vpc.vpc_id
#   subnet_ids         = module.vpc.public_subnet_ids
#   security_group_ids = [module.security_groups.alb_security_group_id]

#   # SSL certificate
#   certificate_arn = module.acm.certificate_arn

#   # Logging
#   enable_access_logs = true
#   logs_bucket        = module.s3.logs_bucket_id
#   logs_prefix        = "alb/"

#   tags = var.tags
# }

# # ==============================================================================
# # Outputs
# # ==============================================================================

