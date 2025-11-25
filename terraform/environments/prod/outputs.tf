# terraform/environments/prod/outputs.tf
# ==============================================================================
# Production Environment Outputs
# ==============================================================================

# ==============================================================================
# VPC Outputs
# ==============================================================================

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_app_subnet_ids" {
  description = "IDs of private application subnets"
  value       = module.vpc.private_app_subnet_ids
}

output "private_data_subnet_ids" {
  description = "IDs of private data subnets"
  value       = module.vpc.private_data_subnet_ids
}

output "nat_gateway_public_ips" {
  description = "Public IPs of NAT Gateways"
  value       = module.vpc.nat_gateway_public_ips
}

# ==============================================================================
# Security Group Outputs
# ==============================================================================

output "security_groups" {
  description = "Security group IDs"
  value = {
    alb         = module.security_groups.alb_security_group_id
    ecs         = module.security_groups.ecs_security_group_id
    rds         = module.security_groups.rds_security_group_id
    elasticache = module.security_groups.elasticache_security_group_id
  }
}

# ==============================================================================
# S3 Outputs
# ==============================================================================

output "s3_buckets" {
  description = "S3 bucket information"
  value = {
    assets_id  = module.s3.assets_bucket_id
    assets_arn = module.s3.assets_bucket_arn
    backups_id = module.s3.backups_bucket_id
    logs_id    = module.s3.logs_bucket_id
  }
}

# ==============================================================================
# CloudFront Outputs
# ==============================================================================

output "cloudfront" {
  description = "CloudFront distribution information"
  value = {
    distribution_id          = module.cloudfront.distribution_id
    distribution_arn         = module.cloudfront.distribution_arn
    distribution_domain_name = module.cloudfront.distribution_domain_name
  }
}

# ==============================================================================
# Route53 Outputs - DNS managed by Cloudflare
# ==============================================================================

# ==============================================================================
# ECR Outputs
# ==============================================================================

output "ecr_repository_urls" {
  description = "ECR repository URLs"
  value       = module.ecr.repository_urls
  sensitive   = true
}

# ==============================================================================
# RDS Outputs
# ==============================================================================

output "rds_endpoint" {
  description = "RDS database endpoint"
  value       = module.rds.primary_endpoint
  sensitive   = true
}

output "rds_secret_arns" {
  description = "RDS secrets ARNs"
  value       = module.rds.secret_arns
  sensitive   = true
}



# ==============================================================================
# ElastiCache Outputs
# ==============================================================================

output "elasticache_endpoint" {
  description = "ElastiCache primary endpoint"
  value       = module.elasticache.primary_endpoint_address
  sensitive   = true
}

# ==============================================================================
# ALB Outputs
# ==============================================================================

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.alb.alb_dns_name
}

output "alb_arn" {
  description = "ALB ARN"
  value       = module.alb.alb_arn
}

# ==============================================================================
# ECS Outputs
# ==============================================================================

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}

output "ecs_cluster_arn" {
  description = "ECS cluster ARN"
  value       = module.ecs.cluster_arn
}

output "ecs_service_names" {
  description = "ECS service names"
  value       = module.ecs.service_names
}

# ==============================================================================
# SQS-SNS Outputs
# ==============================================================================

output "sns_topic_arns" {
  description = "SNS topic ARNs"
  value       = module.sqs-sns.topic_arns
}

output "sqs_queue_urls" {
  description = "SQS queue URLs"
  value       = module.sqs-sns.queue_urls
  sensitive   = true
}

# ==============================================================================
# CloudWatch Outputs
# ==============================================================================

output "cloudwatch_sns_topic_arn" {
  description = "CloudWatch SNS topic ARN for alerts"
  value       = module.cloudwatch.sns_topic_arn
}

output "cloudwatch_dashboard_name" {
  description = "CloudWatch dashboard name"
  value       = module.cloudwatch.dashboard_name
}

# ==============================================================================
# Application URLs
# ==============================================================================

output "frontend_url" {
  description = "Frontend application URL"
  value       = "https://${module.cloudfront.distribution_domain_name}"
}

output "backend_alb_url" {
  description = "Backend ALB URL (internal)"
  value       = "http://${module.alb.alb_dns_name}"
}

# ==============================================================================
# Deployment Summary
# ==============================================================================

output "deployment_summary" {
  description = "Summary of deployed resources"
  value = {
    environment        = "production"
    vpc_id             = module.vpc.vpc_id
    availability_zones = var.availability_zones
    ecs_cluster        = module.ecs.cluster_name
    alb_dns            = module.alb.alb_dns_name
    cloudfront_domain  = module.cloudfront.distribution_domain_name
    services_deployed  = keys(module.ecs.service_names)
    multi_az_enabled   = true
    read_replicas      = true
  }
}

# ==============================================================================
# Disaster Recovery Information
# ==============================================================================

output "disaster_recovery_info" {
  description = "Disaster recovery configuration"
  value = {
    strategy               = "Backup and Restore"
    rto                    = "< 15 minutes"
    rpo                    = "< 24 hours"
    rds_backup_retention   = "30 days"
    redis_backup_retention = "7 days"
    multi_az_enabled       = true
    read_replicas_enabled  = true
    automated_backups      = "Daily"
    manual_snapshots       = "Before deployments"
  }
}

# ==============================================================================
# Production Configuration Summary
# ==============================================================================

output "production_config" {
  description = "Production environment configuration summary"
  value = {
    environment           = "production"
    region                = var.aws_region
    availability_zones    = var.availability_zones
    multi_az              = true
    auto_scaling          = true
    fargate_spot_enabled  = true
    deletion_protection   = true
    enhanced_monitoring   = true
    performance_insights  = true
    log_retention_days    = 30
    backup_retention_days = 30
  }
}

# ==============================================================================
# Next Steps Instructions
# ==============================================================================

output "next_steps" {
  description = "Production deployment next steps"
  value       = <<-EOT
    ========================================
    PRODUCTION INFRASTRUCTURE DEPLOYED!
    ========================================
    
    ✅ Services Deployed:
    - Multi-AZ VPC (${join(", ", var.availability_zones)})
    - ECS Fargate cluster with 4 microservices
    - RDS PostgreSQL (Multi-AZ + Read Replicas)
    - ElastiCache Redis (Cluster Mode, 6 nodes)
    - Application Load Balancer (Multi-AZ)
    - S3 + CloudFront
    - DNS (Cloudflare)
    - SQS/SNS messaging
    - CloudWatch monitoring
    
    🌐 Access Points:
    Frontend: https://events.sankofagrid.com
    Backend API: https://api.sankofagrid.com
    ALB (internal): http://${module.alb.alb_dns_name}
    
    📋 Next Steps:
    
    1. Configure DNS (Cloudflare):
       - events.sankofagrid.com → ${module.cloudfront.distribution_domain_name}
       - api.sankofagrid.com → ${module.alb.alb_dns_name}
    
    2. Deploy application containers:
       - Build and push images to ECR
       - Update ECS task definitions
       - ECS will auto-deploy with blue-green strategy
    
    3. Verify deployment:
       - Check ECS service health
       - Test API endpoints
       - Verify database connectivity
       - Test frontend application
    
    4. Configure monitoring:
       - Set up alert routing (email, Slack, PagerDuty)
       - Configure Grafana dashboards
       - Test alarm notifications
    
    5. Backup verification:
       - Verify RDS automated backups
       - Verify ElastiCache snapshots
       - Test restore procedure
    
    📊 Monitoring:
    CloudWatch: AWS Console > CloudWatch > Dashboards > ${module.cloudwatch.dashboard_name}
    Grafana: https://api.sankofagrid.com/monitoring/
    
    💰 Estimated Monthly Cost: $800-1200
    
    📖 Documentation:
    - Architecture: docs/architecture/AWS_INFRASTRUCTURE_ARCHITECTURE-PROD.md
    - Deployment: terraform/environments/prod/DEPLOYMENT_CHECKLIST.md
    - Operations: terraform/environments/prod/QUICK_REFERENCE.md
  EOT
}