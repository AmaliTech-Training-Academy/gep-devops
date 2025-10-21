# terraform/modules/security-groups/outputs.tf

output "alb_sg_id" {
  description = "ID of ALB security group"
  value       = aws_security_group.alb.id
}

output "alb_sg_arn" {
  description = "ARN of ALB security group"
  value       = aws_security_group.alb.arn
}

output "ecs_sg_id" {
  description = "ID of ECS security group"
  value       = aws_security_group.ecs.id
}

output "ecs_sg_arn" {
  description = "ARN of ECS security group"
  value       = aws_security_group.ecs.arn
}

output "rds_sg_id" {
  description = "ID of RDS security group"
  value       = aws_security_group.rds.id
}

output "rds_sg_arn" {
  description = "ARN of RDS security group"
  value       = aws_security_group.rds.arn
}

output "redis_sg_id" {
  description = "ID of Redis security group"
  value       = aws_security_group.redis.id
}

output "redis_sg_arn" {
  description = "ARN of Redis security group"
  value       = aws_security_group.redis.arn
}

output "docdb_sg_id" {
  description = "ID of DocumentDB security group"
  value       = var.enable_docdb ? aws_security_group.docdb[0].id : null
}

output "docdb_sg_arn" {
  description = "ARN of DocumentDB security group"
  value       = var.enable_docdb ? aws_security_group.docdb[0].arn : null
}

output "all_security_group_ids" {
  description = "Map of all security group IDs"
  value = {
    alb   = aws_security_group.alb.id
    ecs   = aws_security_group.ecs.id
    rds   = aws_security_group.rds.id
    redis = aws_security_group.redis.id
    docdb = var.enable_docdb ? aws_security_group.docdb[0].id : null
  }
}