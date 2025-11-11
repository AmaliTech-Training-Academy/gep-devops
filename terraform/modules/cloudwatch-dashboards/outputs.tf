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

output "frontend_cloudfront_dashboard_name" {
  description = "Name of the frontend CloudFront dashboard"
  value       = aws_cloudwatch_dashboard.frontend_cloudfront.dashboard_name
}

output "frontend_cloudfront_dashboard_arn" {
  description = "ARN of the frontend CloudFront dashboard"
  value       = aws_cloudwatch_dashboard.frontend_cloudfront.dashboard_arn
}

output "event_service_dashboard_name" {
  description = "Name of the event service CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.event_service.dashboard_name
}

output "notification_service_dashboard_name" {
  description = "Name of the notification service CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.notification_service.dashboard_name
}
