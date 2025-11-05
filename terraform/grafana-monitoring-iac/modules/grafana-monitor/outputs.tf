# ==============================================================================
# Grafana Monitoring Module - Outputs
# ==============================================================================

output "grafana_instance_id" {
  description = "ID of the Grafana EC2 instance"
  value       = aws_instance.grafana.id
}

output "grafana_instance_private_ip" {
  description = "Private IP address of the Grafana instance"
  value       = aws_instance.grafana.private_ip
}

output "grafana_security_group_id" {
  description = "ID of the Grafana security group"
  value       = aws_security_group.grafana.id
}

output "grafana_iam_role_arn" {
  description = "ARN of the Grafana IAM role"
  value       = aws_iam_role.grafana.arn
}

output "grafana_target_group_arn" {
  description = "ARN of the Grafana target group"
  value       = aws_lb_target_group.grafana.arn
}

output "grafana_target_group_name" {
  description = "Name of the Grafana target group"
  value       = aws_lb_target_group.grafana.name
}

output "grafana_url" {
  description = "URL to access Grafana"
  value       = "https://${var.alb_domain_name}/monitoring/"
}

output "grafana_health_check_path" {
  description = "Health check path for Grafana"
  value       = "/api/health"
}
