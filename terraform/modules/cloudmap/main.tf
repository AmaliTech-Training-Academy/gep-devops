# # terraform/modules/cloudmap/main.tf
# # ==============================================================================
# # CloudMap Module - Service Discovery for Microservices
# # ==============================================================================

# # Private DNS Namespace
# resource "aws_service_discovery_private_dns_namespace" "main" {
#   name        = var.namespace_name
#   description = "Service discovery namespace for ${var.project_name}"
#   vpc         = var.vpc_id

#   tags = merge(
#     var.tags,
#     {
#       Name = "${var.project_name}-${var.environment}-service-discovery"
#     }
#   )
# }

# # Service Discovery Services
# resource "aws_service_discovery_service" "auth" {
#   name = "auth-service"

#   dns_config {
#     namespace_id = aws_service_discovery_private_dns_namespace.main.id

#     dns_records {
#       ttl  = 10
#       type = "A"
#     }

#     routing_policy = "MULTIVALUE"
#   }

#   health_check_custom_config {
#     failure_threshold = 1
#   }

#   tags = merge(
#     var.tags,
#     {
#       Name    = "auth-service"
#       Service = "auth"
#     }
#   )
# }

# resource "aws_service_discovery_service" "event" {
#   name = "event-service"

#   dns_config {
#     namespace_id = aws_service_discovery_private_dns_namespace.main.id

#     dns_records {
#       ttl  = 10
#       type = "A"
#     }

#     routing_policy = "MULTIVALUE"
#   }

#   health_check_custom_config {
#     failure_threshold = 1
#   }

#   tags = merge(
#     var.tags,
#     {
#       Name    = "event-service"
#       Service = "event"
#     }
#   )
# }

# resource "aws_service_discovery_service" "booking" {
#   name = "booking-service"

#   dns_config {
#     namespace_id = aws_service_discovery_private_dns_namespace.main.id

#     dns_records {
#       ttl  = 10
#       type = "A"
#     }

#     routing_policy = "MULTIVALUE"
#   }

#   health_check_custom_config {
#     failure_threshold = 1
#   }

#   tags = merge(
#     var.tags,
#     {
#       Name    = "booking-service"
#       Service = "booking"
#     }
#   )
# }

# resource "aws_service_discovery_service" "payment" {
#   name = "payment-service"

#   dns_config {
#     namespace_id = aws_service_discovery_private_dns_namespace.main.id

#     dns_records {
#       ttl  = 10
#       type = "A"
#     }

#     routing_policy = "MULTIVALUE"
#   }

#   health_check_custom_config {
#     failure_threshold = 1
#   }

#   tags = merge(
#     var.tags,
#     {
#       Name    = "payment-service"
#       Service = "payment"
#     }
#   )
# }

# resource "aws_service_discovery_service" "notification" {
#   name = "notification-service"

#   dns_config {
#     namespace_id = aws_service_discovery_private_dns_namespace.main.id

#     dns_records {
#       ttl  = 10
#       type = "A"
#     }

#     routing_policy = "MULTIVALUE"
#   }

#   health_check_custom_config {
#     failure_threshold = 1
#   }

#   tags = merge(
#     var.tags,
#     {
#       Name    = "notification-service"
#       Service = "notification"
#     }
#   )
# }

# # terraform/modules/cloudmap/variables.tf
# variable "project_name" {
#   description = "Project name"
#   type        = string
# }

# variable "environment" {
#   description = "Environment name"
#   type        = string
# }

# variable "vpc_id" {
#   description = "VPC ID"
#   type        = string
# }

# variable "namespace_name" {
#   description = "CloudMap namespace name"
#   type        = string
# }

# variable "tags" {
#   description = "Tags to apply to resources"
#   type        = map(string)
#   default     = {}
# }

# # terraform/modules/cloudmap/outputs.tf
# output "namespace_id" {
#   description = "CloudMap namespace ID"
#   value       = aws_service_discovery_private_dns_namespace.main.id
# }

# output "namespace_name" {
#   description = "CloudMap namespace name"
#   value       = aws_service_discovery_private_dns_namespace.main.name
# }

# output "namespace_arn" {
#   description = "CloudMap namespace ARN"
#   value       = aws_service_discovery_private_dns_namespace.main.arn
# }

# output "service_ids" {
#   description = "Map of service discovery service IDs"
#   value = {
#     auth         = aws_service_discovery_service.auth.id
#     event        = aws_service_discovery_service.event.id
#     booking      = aws_service_discovery_service.booking.id
#     payment      = aws_service_discovery_service.payment.id
#     notification = aws_service_discovery_service.notification.id
#   }
# }