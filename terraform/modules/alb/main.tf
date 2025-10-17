# # terraform/modules/alb/main.tf
# # ==============================================================================
# # ALB Module - Application Load Balancer for ECS Services
# # ==============================================================================

# # Security Group for ALB
# resource "aws_security_group" "alb" {
#   name        = "${var.project_name}-${var.environment}-alb-sg"
#   description = "Security group for Application Load Balancer"
#   vpc_id      = var.vpc_id

#   ingress {
#     description = "HTTP from anywhere"
#     from_port   = 80
#     to_port     = 80
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   ingress {
#     description = "HTTPS from anywhere"
#     from_port   = 443
#     to_port     = 443
#     protocol    = "tcp"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   egress {
#     description = "Allow all outbound traffic"
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = merge(
#     var.common_tags,
#     {
#       Name = "${var.project_name}-${var.environment}-alb-sg"
#     }
#   )
# }

# # Application Load Balancer
# resource "aws_lb" "main" {
#   name               = "${var.project_name}-${var.environment}-alb"
#   internal           = var.internal
#   load_balancer_type = "application"
#   security_groups    = [aws_security_group.alb.id]
#   subnets            = var.subnet_ids

#   enable_deletion_protection = var.enable_deletion_protection
#   enable_http2               = true
#   enable_cross_zone_load_balancing = true
#   idle_timeout               = var.idle_timeout

#   dynamic "access_logs" {
#     for_each = var.enable_access_logs ? [1] : []
#     content {
#       bucket  = var.access_logs_bucket
#       prefix  = var.access_logs_prefix
#       enabled = true
#     }
#   }

#   tags = merge(
#     var.common_tags,
#     {
#       Name        = "${var.project_name}-${var.environment}-alb"
#       Environment = var.environment
#     }
#   )
# }

# # HTTP Listener (redirect to HTTPS)
# resource "aws_lb_listener" "http" {
#   load_balancer_arn = aws_lb.main.arn
#   port              = 80
#   protocol          = "HTTP"

#   default_action {
#     type = "redirect"

#     redirect {
#       port        = "443"
#       protocol    = "HTTPS"
#       status_code = "HTTP_301"
#     }
#   }

#   tags = var.common_tags
# }

# # HTTPS Listener
# resource "aws_lb_listener" "https" {
#   count = var.certificate_arn != "" ? 1 : 0

#   load_balancer_arn = aws_lb.main.arn
#   port              = 443
#   protocol          = "HTTPS"
#   ssl_policy        = var.ssl_policy
#   certificate_arn   = var.certificate_arn

#   default_action {
#     type = "fixed-response"

#     fixed_response {
#       content_type = "text/plain"
#       message_body = "Service not found"
#       status_code  = "404"
#     }
#   }

#   tags = var.common_tags
# }

# # Target Group for Booking Service
# resource "aws_lb_target_group" "booking_service" {
#   name        = "${var.project_name}-${var.environment}-booking-tg"
#   port        = 3000
#   protocol    = "HTTP"
#   vpc_id      = var.vpc_id
#   target_type = "ip"

#   health_check {
#     enabled             = true
#     healthy_threshold   = var.health_check_healthy_threshold
#     interval            = var.health_check_interval
#     matcher             = var.health_check_matcher
#     path                = "/api/health"
#     port                = "traffic-port"
#     protocol            = "HTTP"
#     timeout             = var.health_check_timeout
#     unhealthy_threshold = var.health_check_unhealthy_threshold
#   }

#   deregistration_delay = var.deregistration_delay

#   stickiness {
#     type            = "lb_cookie"
#     cookie_duration = 86400
#     enabled         = var.enable_stickiness
#   }

#   tags = merge(
#     var.common_tags,
#     {
#       Name    = "${var.project_name}-${var.environment}-booking-tg"
#       Service = "booking"
#     }
#   )
# }

# # Target Group for Notification Service
# resource "aws_lb_target_group" "notification_service" {
#   name        = "${var.project_name}-${var.environment}-notification-tg"
#   port        = 3001
#   protocol    = "HTTP"
#   vpc_id      = var.vpc_id
#   target_type = "ip"

#   health_check {
#     enabled             = true
#     healthy_threshold   = var.health_check_healthy_threshold
#     interval            = var.health_check_interval
#     matcher             = var.health_check_matcher
#     path                = "/api/health"
#     port                = "traffic-port"
#     protocol            = "HTTP"
#     timeout             = var.health_check_timeout
#     unhealthy_threshold = var.health_check_unhealthy_threshold
#   }

#   deregistration_delay = var.deregistration_delay

#   tags = merge(
#     var.common_tags,
#     {
#       Name    = "${var.project_name}-${var.environment}-notification-tg"
#       Service = "notification"
#     }
#   )
# }

# # Target Group for Payment Service
# resource "aws_lb_target_group" "payment_service" {
#   name        = "${var.project_name}-${var.environment}-payment-tg"
#   port        = 3002
#   protocol    = "HTTP"
#   vpc_id      = var.vpc_id
#   target_type = "ip"

#   health_check {
#     enabled             = true
#     healthy_threshold   = var.health_check_healthy_threshold
#     interval            = var.health_check_interval
#     matcher             = var.health_check_matcher
#     path                = "/api/health"
#     port                = "traffic-port"
#     protocol            = "HTTP"
#     timeout             = var.health_check_timeout
#     unhealthy_threshold = var.health_check_unhealthy_threshold
#   }

#   deregistration_delay = var.deregistration_delay

#   tags = merge(
#     var.common_tags,
#     {
#       Name    = "${var.project_name}-${var.environment}-payment-tg"
#       Service = "payment"
#     }
#   )
# }

# # Listener Rules for Booking Service
# resource "aws_lb_listener_rule" "booking_service" {
#   count = var.certificate_arn != "" ? 1 : 0

#   listener_arn = aws_lb_listener.https[0].arn
#   priority     = 100

#   action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.booking_service.arn
#   }

#   condition {
#     path_pattern {
#       values = ["/api/bookings/*", "/api/events/*", "/api/venues/*"]
#     }
#   }

#   tags = var.common_tags
# }

# # Listener Rules for Notification Service
# resource "aws_lb_listener_rule" "notification_service" {
#   count = var.certificate_arn != "" ? 1 : 0

#   listener_arn = aws_lb_listener.https[0].arn
#   priority     = 200

#   action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.notification_service.arn
#   }

#   condition {
#     path_pattern {
#       values = ["/api/notifications/*", "/api/emails/*", "/api/sms/*"]
#     }
#   }

#   tags = var.common_tags
# }

# # Listener Rules for Payment Service
# resource "aws_lb_listener_rule" "payment_service" {
#   count = var.certificate_arn != "" ? 1 : 0

#   listener_arn = aws_lb_listener.https[0].arn
#   priority     = 300

#   action {
#     type             = "forward"
#     target_group_arn = aws_lb_target_group.payment_service.arn
#   }

#   condition {
#     path_pattern {
#       values = ["/api/payments/*", "/api/transactions/*", "/api/invoices/*"]
#     }
#   }

#   tags = var.common_tags
# }

# # WAF Association (optional)
# resource "aws_wafv2_web_acl_association" "alb" {
#   count = var.waf_web_acl_arn != "" ? 1 : 0

#   resource_arn = aws_lb.main.arn
#   web_acl_arn  = var.waf_web_acl_arn
# }

