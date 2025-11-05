
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

  vpc_id                = module.vpc.vpc_id
  private_subnet_id     = module.vpc.private_app_subnet_ids[0]
  alb_security_group_id = module.security_groups.alb_security_group_id
  rds_security_group_id = module.security_groups.rds_security_group_id

  alb_listener_arn = module.alb.https_listener_arn
  alb_arn_suffix   = module.alb.alb_arn_suffix
  alb_domain_name  = "api.sankofagrid.com"

  grafana_admin_password = var.grafana_admin_password
  listener_rule_priority = 1 # Higher priority than service routes

  instance_type = "t3.micro"
  volume_size   = 30

  alarm_actions = [module.cloudwatch.sns_topic_arn]
  tags          = local.common_tags
}