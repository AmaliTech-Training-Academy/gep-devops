
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
# Grafana Monitoring Module
# ==============================================================================

module "grafana_monitor" {
  source = "../../modules/grafana-monitor"

  project_name = var.project_name
  environment  = var.environment

  vpc_id                = var.vpc_id
  private_subnet_id     = var.private_subnet_id
  alb_security_group_id = var.alb_security_group_id
  rds_security_group_id = var.rds_security_group_id

  alb_listener_arn = var.alb_listener_arn
  alb_arn_suffix   = var.alb_arn_suffix
  alb_domain_name  = "api.sankofagrid.com"

  grafana_admin_password = var.grafana_admin_password
  listener_rule_priority = 1 # Higher priority than service routes

  instance_type = "t3.micro"
  volume_size   = 20

  alarm_actions = [var.sns_topic_arn]
  tags          = local.common_tags
  ami_id = var.ami_id
}
