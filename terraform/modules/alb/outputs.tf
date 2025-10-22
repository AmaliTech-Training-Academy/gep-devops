# ==============================================================================
# Outputs
# ==============================================================================

output "alb_id" {
  description = "ID of the load balancer"
  value       = aws_lb.main.id
}

output "alb_arn" {
  description = "ARN of the load balancer"
  value       = aws_lb.main.arn
}

output "alb_arn_suffix" {
  description = "ARN suffix of the load balancer"
  value       = aws_lb.main.arn_suffix
}

output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the load balancer"
  value       = aws_lb.main.zone_id
}

output "https_listener_arn" {
  description = "ARN of the HTTPS listener"
  value       = length(aws_lb_listener.https) > 0 ? aws_lb_listener.https[0].arn : null
}

output "http_listener_arn" {
  description = "ARN of the HTTP listener"
  value       = aws_lb_listener.http.arn
}

output "target_group_arns" {
  description = "Map of service names to target group ARNs"
  value = {
    for service, config in local.services :
    service => aws_lb_target_group.services[service].arn
  }
}

output "target_group_names" {
  description = "Map of service names to target group names"
  value = {
    for service, config in local.services :
    service => aws_lb_target_group.services[service].name
  }
}

output "target_group_arn_suffixes" {
  description = "Map of service names to target group ARN suffixes"
  value = {
    for service, config in local.services :
    service => aws_lb_target_group.services[service].arn_suffix
  }
}