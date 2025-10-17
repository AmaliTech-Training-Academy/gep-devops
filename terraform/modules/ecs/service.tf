# // ==============================================================================
# // ECS Service Definition Template (Terraform)
# // ==============================================================================
# // terraform/modules/ecs/service.tf
# // ==============================================================================


# resource "aws_ecs_service" "auth_service" {
#   name            = "${var.project_name}-${var.environment}-auth-service"
#   cluster         = aws_ecs_cluster.main.id
#   task_definition = aws_ecs_task_definition.auth_service.arn
#   desired_count   = var.auth_service_desired_count
#   launch_type     = "FARGATE"

#   platform_version = "1.4.0"

#   network_configuration {
#     subnets          = var.private_app_subnet_ids
#     security_groups  = [var.ecs_security_group_id]
#     assign_public_ip = false
#   }

#   load_balancer {
#     target_group_arn = aws_lb_target_group.auth_service.arn
#     container_name   = "auth-service"
#     container_port   = 8081
#   }

#   service_registries {
#     registry_arn = aws_service_discovery_service.auth_service.arn
#   }

#   deployment_configuration {
#     maximum_percent         = 200
#     minimum_healthy_percent = 100

#     deployment_circuit_breaker {
#       enable   = true
#       rollback = true
#     }
#   }

#   enable_execute_command = true

#   tags = {
#     Name        = "${var.project_name}-${var.environment}-auth-service"
#     Environment = var.environment
#     Service     = "auth-service"
#   }

#   depends_on = [
#     aws_lb_listener.https,
#     aws_service_discovery_service.auth_service
#   ]
# }

# resource "aws_appautoscaling_target" "auth_service" {
#   max_capacity       = var.auth_service_max_capacity
#   min_capacity       = var.auth_service_min_capacity
#   resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.auth_service.name}"
#   scalable_dimension = "ecs:service:DesiredCount"
#   service_namespace  = "ecs"
# }

# resource "aws_appautoscaling_policy" "auth_service_cpu" {
#   name               = "${var.project_name}-${var.environment}-auth-service-cpu-scaling"
#   policy_type        = "TargetTrackingScaling"
#   resource_id        = aws_appautoscaling_target.auth_service.resource_id
#   scalable_dimension = aws_appautoscaling_target.auth_service.scalable_dimension
#   service_namespace  = aws_appautoscaling_target.auth_service.service_namespace

#   target_tracking_scaling_policy_configuration {
#     target_value = 80.0

#     predefined_metric_specification {
#       predefined_metric_type = "ECSServiceAverageCPUUtilization"
#     }

#     scale_in_cooldown  = 300
#     scale_out_cooldown = 60
#   }
# }

# resource "aws_service_discovery_service" "auth_service" {
#   name = "auth-service"

#   dns_config {
#     namespace_id = var.cloudmap_namespace_id

#     dns_records {
#       ttl  = 60
#       type = "A"
#     }

#     routing_policy = "MULTIVALUE"
#   }

#   health_check_custom_config {
#     failure_threshold = 1
#   }
# }
