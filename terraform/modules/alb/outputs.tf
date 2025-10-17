# # terraform/modules/alb/outputs.tf
# output "alb_id" {
#   description = "ALB ID"
#   value       = aws_lb.main.id
# }

# output "alb_arn" {
#   description = "ALB ARN"
#   value       = aws_lb.main.arn
# }

# output "alb_dns_name" {
#   description = "ALB DNS name"
#   value       = aws_lb.main.dns_name
# }

# output "alb_zone_id" {
#   description = "ALB hosted zone ID"
#   value       = aws_lb.main.zone_id
# }

# output "alb_security_group_id" {
#   description = "ALB security group ID"
#   value       = aws_security_group.alb.id
# }

# output "http_listener_arn" {
#   description = "HTTP listener ARN"
#   value       = aws_lb_listener.http.arn
# }

# output "https_listener_arn" {
#   description = "HTTPS listener ARN"
#   value       = var.certificate_arn != "" ? aws_lb_listener.https[0].arn : null
# }

# output "booking_service_target_group_arn" {
#   description = "Booking service target group ARN"
#   value       = aws_lb_target_group.booking_service.arn
# }

# output "notification_service_target_group_arn" {
#   description = "Notification service target group ARN"
#   value       = aws_lb_target_group.notification_service.arn
# }

# output "payment_service_target_group_arn" {
#   description = "Payment service target group ARN"
#   value       = aws_lb_target_group.payment_service.arn
# }