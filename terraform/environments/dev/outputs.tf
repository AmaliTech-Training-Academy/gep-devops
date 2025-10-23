# terraform/environments/dev/outputs.tf
# ==============================================================================
# Development Environment Outputs - Complete
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
    documentdb  = module.security_groups.documentdb_security_group_id
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
# Route53 Outputs
# ==============================================================================

output "route53_hosted_zone_id" {
  description = "Route53 hosted zone ID"
  value       = module.route53.hosted_zone_id
}

output "route53_nameservers" {
  description = "Route53 nameservers"
  value       = module.route53.hosted_zone_name_servers
}

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

output "rds_endpoints" {
  description = "RDS database endpoints"
  value       = module.rds.primary_endpoints
  sensitive   = true
}

output "rds_secret_arns" {
  description = "RDS secrets ARNs"
  value       = module.rds.secret_arns
  sensitive   = true
}

# ==============================================================================
# DocumentDB Outputs
# ==============================================================================

output "documentdb_endpoint" {
  description = "DocumentDB cluster endpoint"
  value       = module.documentdb.cluster_endpoint
  sensitive   = true
}

output "documentdb_secret_arn" {
  description = "DocumentDB secret ARN"
  value       = module.documentdb.secret_arn
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
# ACM Certificate Outputs
# ==============================================================================

output "acm_alb_certificate_arn" {
  description = "ARN of ALB ACM certificate"
  value       = module.acm.alb_certificate_arn
}

output "acm_alb_certificate_status" {
  description = "Status of ALB certificate (check if ISSUED)"
  value       = module.acm.alb_certificate_status
}

output "acm_alb_validation_records" {
  description = "DNS validation records for ALB certificate - ADD THESE TO CLOUDFLARE"
  value       = module.acm.alb_validation_records
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
    vpc_id            = module.vpc.vpc_id
    ecs_cluster       = module.ecs.cluster_name
    alb_dns           = module.alb.alb_dns_name
    cloudfront_domain = module.cloudfront.distribution_domain_name
    route53_zone_id   = module.route53.hosted_zone_id
    services_deployed = keys(module.ecs.service_names)
    databases_created = keys(module.rds.primary_endpoints)
  }
}

# ==============================================================================
# Next Steps Instructions
# ==============================================================================

output "next_steps" {
  description = "Deployment next steps"
  value       = <<-EOT
    ========================================
    INFRASTRUCTURE DEPLOYMENT COMPLETE!
    ========================================
    
     Services Deployed:
    - VPC with networking
    - ECS Fargate cluster with 5 microservices
    - RDS PostgreSQL databases (4)
    - DocumentDB for audit logs
    - ElastiCache Redis
    - Application Load Balancer
    - S3 + CloudFront
    - Route53 DNS
    - SQS/SNS messaging
    - CloudWatch monitoring
    
     Access Points:
    Frontend: https://${module.cloudfront.distribution_domain_name}
    Backend ALB: http://${module.alb.alb_dns_name}
    
     Next Steps:
    1. Configure DNS nameservers:
       terraform output route53_nameservers
    
    2. Deploy application containers:
       - Build and push images to ECR
       - ECS will automatically pull and deploy
    
    3. Configure Phase 2 (SSL certificates):
       - Wait for DNS propagation (1-24 hours)
       - Uncomment ACM module in main.tf
       - Update CloudFront and ALB with certificates
    
    4. Access logs and monitoring:
       Dashboard: AWS Console > CloudWatch > Dashboards > ${module.cloudwatch.dashboard_name}
  EOT
}