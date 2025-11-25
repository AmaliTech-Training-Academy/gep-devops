# ==============================================================================
# AWS Budgets Module - Outputs
# ==============================================================================

output "budget_name" {
  description = "Name of the created budget"
  value       = aws_budgets_budget.monthly_cost.name
}

output "budget_id" {
  description = "ID of the created budget"
  value       = aws_budgets_budget.monthly_cost.id
}

output "anomaly_monitor_arn" {
  description = "ARN of the cost anomaly monitor"
  value       = aws_ce_anomaly_monitor.service_monitor.arn
}

output "anomaly_subscription_arn" {
  description = "ARN of the cost anomaly subscription"
  value       = aws_ce_anomaly_subscription.anomaly_alerts.arn
}
