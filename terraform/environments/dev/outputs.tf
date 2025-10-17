

# ==============================================================================
# terraform/environments/dev/outputs.tf
# ==============================================================================

# VPC Outputs
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

# Security Group Outputs
output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = module.security_groups.alb_security_group_id
}

output "ecs_security_group_id" {
  description = "ID of the ECS security group"
  value       = module.security_groups.ecs_security_group_id
}

output "rds_security_group_id" {
  description = "ID of the RDS security group"
  value       = module.security_groups.rds_security_group_id
}

# Database Outputs
output "rds_auth_endpoint" {
  description = "Endpoint of Auth RDS instance"
  value       = module.rds_auth.endpoint
  sensitive   = true
}

output "rds_event_endpoint" {
  description = "Endpoint of Event RDS instance"
  value       = module.rds_event.endpoint
  sensitive   = true
}

output "rds_booking_endpoint" {
  description = "Endpoint of Booking RDS instance"
  value       = module.rds_booking.endpoint
  sensitive   = true
}

output "rds_payment_endpoint" {
  description = "Endpoint of Payment RDS instance"
  value       = module.rds_payment.endpoint
  sensitive   = true
}

output "documentdb_endpoint" {
  description = "Endpoint of DocumentDB cluster"
  value       = module.documentdb.endpoint
  sensitive   = true
}

output "elasticache_endpoint" {
  description = "Endpoint of ElastiCache cluster"
  value       = module.elasticache.cache_nodes[0].address
  sensitive   = true
}

# ECS Outputs
output "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  value       = module.ecs.cluster_id
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = module.ecs.cluster_arn
}

# CloudMap Outputs
output "cloudmap_namespace_id" {
  description = "ID of the CloudMap namespace"
  value       = module.cloudmap.namespace_id
}

output "cloudmap_namespace_name" {
  description = "Name of the CloudMap namespace"
  value       = module.cloudmap.namespace_name
}

# Frontend Outputs
output "frontend_bucket_name" {
  description = "Name of the frontend S3 bucket"
  value       = module.s3.frontend_bucket_id
}

output "frontend_bucket_website_endpoint" {
  description = "Website endpoint of the frontend S3 bucket"
  value       = module.s3.frontend_bucket_website_endpoint
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = module.cloudfront.distribution_id
}

output "cloudfront_distribution_domain" {
  description = "Domain name of the CloudFront distribution"
  value       = module.cloudfront.distribution_domain_name
}

output "frontend_url" {
  description = "Frontend application URL"
  value       = "https://${var.frontend_domain}"
}

# Backend Outputs
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = module.alb.zone_id
}

output "backend_url" {
  description = "Backend API URL"
  value       = "https://${var.backend_domain}"
}

# Route53 Outputs
output "route53_zone_id" {
  description = "ID of the Route53 hosted zone"
  value       = module.route53.zone_id
}

output "route53_nameservers" {
  description = "Nameservers for the Route53 hosted zone"
  value       = module.route53.nameservers
}

# IAM Outputs
output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = module.iam.ecs_task_execution_role_arn
}

output "ecs_task_role_arns" {
  description = "ARNs of the ECS task roles"
  value       = module.iam.ecs_task_role_arns
}

# Certificate Outputs
output "acm_certificate_arn" {
  description = "ARN of the ACM certificate"
  value       = module.acm.certificate_arn
}

output "acm_certificate_status" {
  description = "Status of the ACM certificate"
  value       = module.acm.certificate_status
}

# Connection Strings (for application configuration)
output "database_connection_strings" {
  description = "Database connection strings for microservices"
  value = {
    auth_db = "postgresql://postgres:${module.rds_auth.endpoint}/auth"
    event_db = "postgresql://postgres:${module.rds_event.endpoint}/event"
    booking_db = "postgresql://postgres:${module.rds_booking.endpoint}/booking"
    payment_db = "postgresql://postgres:${module.rds_payment.endpoint}/payment"
    documentdb = "mongodb://${module.documentdb.endpoint}:27017/audit_logs"
    redis = "redis://${module.elasticache.cache_nodes[0].address}:6379"
  }
  sensitive = true
}

# Service Discovery
output "service_discovery_endpoints" {
  description = "Service discovery endpoints for microservices"
  value = {
    auth_service         = "auth-service.eventplanner.local:8081"
    event_service        = "event-service.eventplanner.local:8082"
    booking_service      = "booking-service.eventplanner.local:8083"
    payment_service      = "payment-service.eventplanner.local:8084"
    notification_service = "notification-service.eventplanner.local:8085"
  }
}

# Cost Optimization Information
output "cost_optimization_tips" {
  description = "Tips for reducing costs in development environment"
  value = <<-EOT
    Development Environment Cost Optimization:
    
    1. Stop ECS services when not in use:
       aws ecs update-service --cluster ${module.ecs.cluster_name} --service <service-name> --desired-count 0
    
    2. Stop RDS instances during off-hours:
       aws rds stop-db-instance --db-instance-identifier <db-identifier>
    
    3. Remove NAT Gateway when not needed (requires Terraform apply):
       Set enable_nat_gateway = false in terraform.tfvars
    
    4. Estimated monthly cost (24/7): ~$248
    5. Estimated monthly cost (weekday-only): ~$75-95
    
    Current Configuration:
    - Single AZ deployment
    - No read replicas
    - Minimal instance sizes
    - Single NAT Gateway
  EOT
}

# Deployment Instructions
output "deployment_instructions" {
  description = "Instructions for deploying applications"
  value = <<-EOT
    Deployment Instructions:
    
    FRONTEND DEPLOYMENT:
    1. Build Angular application: npm run build --prod
    2. Upload to S3: aws s3 sync dist/ s3://${module.s3.frontend_bucket_id}/
    3. Invalidate CloudFront cache: aws cloudfront create-invalidation --distribution-id ${module.cloudfront.distribution_id} --paths "/*"
    4. Access frontend: https://${var.frontend_domain}
    
    BACKEND DEPLOYMENT:
    1. Build Docker images for each microservice
    2. Push to ECR (create ECR repositories first)
    3. Update ECS task definitions with new image tags
    4. Update ECS services to use new task definitions
    5. Access backend: https://${var.backend_domain}
    
    DATABASE ACCESS:
    - RDS instances are in private subnets (no direct internet access)
    - Use AWS Systems Manager Session Manager or bastion host
    - Connection strings are available in Secrets Manager
    
    SERVICE DISCOVERY:
    - Services communicate via CloudMap DNS
    - Internal domain: eventplanner.local
    - Example: auth-service.eventplanner.local:8081
  EOT
}