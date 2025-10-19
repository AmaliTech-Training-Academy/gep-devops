# terraform/environments/dev/outputs.tf
# ==============================================================================
# Development Environment Outputs
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

output "vpc_arn" {
  description = "ARN of the VPC"
  value       = module.vpc.vpc_arn
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

output "vpc_endpoints" {
  description = "VPC endpoints information"
  value = {
    s3_endpoint_id             = module.vpc.vpc_endpoint_s3_id
    ecr_api_endpoint_id        = module.vpc.vpc_endpoint_ecr_api_id
    ecr_dkr_endpoint_id        = module.vpc.vpc_endpoint_ecr_dkr_id
    logs_endpoint_id           = module.vpc.vpc_endpoint_logs_id
    secretsmanager_endpoint_id = module.vpc.vpc_endpoint_secretsmanager_id
    ssm_endpoint_id            = module.vpc.vpc_endpoint_ssm_id
  }
}

# ==============================================================================
# Security Group Outputs
# ==============================================================================

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

output "documentdb_security_group_id" {
  description = "ID of the DocumentDB security group"
  value       = module.security_groups.documentdb_security_group_id
}

output "elasticache_security_group_id" {
  description = "ID of the ElastiCache security group"
  value       = module.security_groups.elasticache_security_group_id
}

# ==============================================================================
# S3 Outputs
# ==============================================================================

output "assets_bucket_id" {
  description = "S3 assets bucket ID"
  value       = module.s3.assets_bucket_id
}

output "assets_bucket_arn" {
  description = "S3 assets bucket ARN"
  value       = module.s3.assets_bucket_arn
}

output "assets_bucket_domain_name" {
  description = "S3 assets bucket domain name"
  value       = module.s3.assets_bucket_domain_name
}

output "backups_bucket_id" {
  description = "S3 backups bucket ID"
  value       = module.s3.backups_bucket_id
}

output "backups_bucket_arn" {
  description = "S3 backups bucket ARN"
  value       = module.s3.backups_bucket_arn
}

output "logs_bucket_id" {
  description = "S3 logs bucket ID"
  value       = module.s3.logs_bucket_id
}

# ==============================================================================
# ACM Outputs - COMMENTED OUT FOR PHASE 1
# ==============================================================================
# UNCOMMENT THESE FOR PHASE 2

# output "alb_certificate_arn" {
#   description = "ARN of the ALB SSL certificate"
#   value       = module.acm.alb_certificate_arn
# }

# output "alb_certificate_status" {
#   description = "Status of the ALB SSL certificate"
#   value       = module.acm.alb_certificate_status
# }

# output "cloudfront_certificate_arn" {
#   description = "ARN of the CloudFront SSL certificate"
#   value       = module.acm.cloudfront_certificate_arn
# }

# output "cloudfront_certificate_status" {
#   description = "Status of the CloudFront SSL certificate"
#   value       = module.acm.cloudfront_certificate_status
# }

# ==============================================================================
# CloudFront Outputs
# ==============================================================================

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = module.cloudfront.distribution_id
}

output "cloudfront_distribution_arn" {
  description = "CloudFront distribution ARN"
  value       = module.cloudfront.distribution_arn
}

output "cloudfront_distribution_domain_name" {
  description = "CloudFront distribution domain name"
  value       = module.cloudfront.distribution_domain_name
}

output "cloudfront_distribution_hosted_zone_id" {
  description = "CloudFront distribution hosted zone ID"
  value       = module.cloudfront.distribution_hosted_zone_id
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

output "cloudwatch_log_groups" {
  description = "CloudWatch log group names"
  value = {
    application = module.cloudwatch.application_log_group_name
    lambda      = module.cloudwatch.lambda_log_group_name
  }
}

# ==============================================================================
# IAM Outputs
# ==============================================================================

output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = module.iam.ecs_task_execution_role_arn
}

output "ecs_task_role_arns" {
  description = "ARNs of the ECS task roles"
  value       = module.iam.ecs_task_role_arns
}

# ==============================================================================
# Application URLs - PHASE 1 VERSION
# ==============================================================================

output "frontend_url" {
  description = "Frontend application URL (CloudFront direct URL for Phase 1)"
  value       = "https://${module.cloudfront.distribution_domain_name}"
}

output "backend_url" {
  description = "Backend API URL (will be active once ALB is deployed)"
  value       = "https://${var.backend_domain} (not yet configured)"
}

# ==============================================================================
# Resource Summary - PHASE 1 VERSION
# ==============================================================================

output "resource_summary" {
  description = "Summary of deployed resources"
  value = {
    vpc = {
      id                 = module.vpc.vpc_id
      cidr               = module.vpc.vpc_cidr
      availability_zones = var.availability_zones
      nat_gateways       = length(module.vpc.nat_gateway_ids)
    }
    s3 = {
      assets_bucket  = module.s3.assets_bucket_id
      backups_bucket = module.s3.backups_bucket_id
      logs_bucket    = module.s3.logs_bucket_id
    }
    cloudfront = {
      distribution_id = module.cloudfront.distribution_id
      domain_name     = module.cloudfront.distribution_domain_name
    }
    route53 = {
      hosted_zone_id = module.route53.hosted_zone_id
    }
    # Certificates section commented out for Phase 1
    # certificates = {
    #   alb_arn        = module.acm.alb_certificate_arn
    #   cloudfront_arn = module.acm.cloudfront_certificate_arn
    # }
  }
}

# ==============================================================================
# Deployment Instructions Output - PHASE 1 VERSION
# ==============================================================================

output "deployment_instructions" {
  description = "Quick deployment guide"
  value       = <<-EOT
    ========================================
    PHASE 1 DEPLOYMENT COMPLETE!
    ========================================
    
    Core Infrastructure Deployed:
    ----------------------------------
    - VPC and Networking
    - S3 Buckets (with CloudFront ACL configured)
    - CloudFront Distribution
    - Route53 Hosted Zone
    - CloudWatch Monitoring
    - IAM Roles
    
     NEXT STEPS - DNS CONFIGURATION:
    ----------------------------------
    1. Get your Route53 nameservers:
       terraform output route53_nameservers
    
    2. Update nameservers at your domain registrar:
       Log into your registrar (where you bought sankofagrid.com)
       Find "Nameservers" or "DNS" settings
       Replace Cloudflare nameservers with the 4 AWS Route53 nameservers shown above
    
    3. Monitor DNS propagation (1-24 hours):
       dig NS sankofagrid.com +short
       
       When you see AWS nameservers (ns-xxxx.awsdns-xx.xxx), proceed to Phase 2!
    
    4. Use these online tools to check propagation globally:
       - https://www.whatsmydns.net/#NS/sankofagrid.com
       - https://dnschecker.org/#NS/sankofagrid.com
    
     CURRENT ACCESS (Phase 1):
    -----------------------------
    CloudFront Direct URL: ${module.cloudfront.distribution_domain_name}
    Access your site at:   https://${module.cloudfront.distribution_domain_name}
    
    Custom domains (www.sankofagrid.com) will be configured in Phase 2
    after DNS propagation is complete.
    
     UPLOAD FRONTEND (Optional - Test Now):
    ------------------------------------------
    1. Build: npm run build --prod
    2. Upload: aws s3 sync dist/ s3://${module.s3.assets_bucket_id}/ --delete
    3. Test: curl https://${module.cloudfront.distribution_domain_name}
    
     PHASE 2 DEPLOYMENT:
    ----------------------
    After DNS is fully propagated:
    1. Edit main.tf: Uncomment ACM module
    2. Edit main.tf: Update CloudFront and Route53 modules
    3. Edit outputs.tf: Uncomment ACM outputs
    4. Run: terraform plan -out=phase2.tfplan
    5. Run: terraform apply phase2.tfplan
    6. Wait 5-45 minutes for ACM validation
    7. Access: https://www.sankofagrid.com
    
  EOT
}

# ==============================================================================
# Phase 1 Specific Outputs
# ==============================================================================

output "phase_1_status" {
  description = "Phase 1 deployment status"
  value = {
    status              = "COMPLETE"
    cloudfront_url      = "https://${module.cloudfront.distribution_domain_name}"
    route53_zone_id     = module.route53.hosted_zone_id
    next_step           = "Update nameservers at your domain registrar"
    nameservers_command = "terraform output route53_nameservers"
  }
}