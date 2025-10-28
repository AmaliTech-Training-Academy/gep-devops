# ==============================================================================
# CloudWatch Dashboards Module Outputs
# ==============================================================================

output "auth_service_dashboard_name" {
  description = "Name of the auth service CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.auth_service.dashboard_name
}

output "auth_service_dashboard_arn" {
  description = "ARN of the auth service CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.auth_service.dashboard_arn
}
