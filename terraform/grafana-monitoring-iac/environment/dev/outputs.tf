# ==============================================================================
# Grafana Monitoring Outputs
# ==============================================================================

output "grafana_url" {
  description = "Grafana monitoring dashboard URL"
  value       = module.grafana_monitor.grafana_url
}

output "grafana_instance_id" {
  description = "Grafana EC2 instance ID"
  value       = module.grafana_monitor.grafana_instance_id
}

output "grafana_instance_private_ip" {
  description = "Grafana EC2 instance private IP"
  value       = module.grafana_monitor.grafana_instance_private_ip
  sensitive   = true
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
    
     Services Deployed (Cost-Optimized):
    - VPC with networking
    - ECS Fargate cluster with 1 microservice (auth only)
    - RDS PostgreSQL database (1: auth only)
    - ElastiCache Redis
    - Application Load Balancer
    - S3 + CloudFront
    - Route53 DNS
    - SQS/SNS messaging
    - CloudWatch monitoring
    
     Services Temporarily Disabled (Cost Savings: ~$108/month):
    - ECS: event, booking, payment, notification services
    - RDS: event, booking, payment databases

        Grafana Monitoring
    
     Access Points:
    Grafana Monitoring: ${module.grafana_monitor.grafana_url}
    
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