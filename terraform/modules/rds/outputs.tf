# ==============================================================================
# Outputs
# ==============================================================================

output "primary_endpoints" {
  description = "Map of database names to primary instance endpoints"
  value = {
    for db, config in local.databases :
    db => {
      address = aws_db_instance.primary[db].address
      port    = aws_db_instance.primary[db].port
      endpoint = aws_db_instance.primary[db].endpoint
    }
  }
}

output "primary_instance_ids" {
  description = "Map of database names to primary instance identifiers"
  value = {
    for db in keys(local.databases) :
    db => aws_db_instance.primary[db].identifier
  }
}

output "read_replica_endpoints" {
  description = "Map of database names to read replica endpoints"
  value = var.create_read_replicas ? {
    for db in keys(local.databases) :
    db => {
      replica_1 = {
        address = aws_db_instance.read_replica_1[db].address
        port    = aws_db_instance.read_replica_1[db].port
      }
      replica_2 = {
        address = aws_db_instance.read_replica_2[db].address
        port    = aws_db_instance.read_replica_2[db].port
      }
    }
  } : {}
}

output "secret_arns" {
  description = "Map of database names to Secrets Manager secret ARNs"
  value = {
    for db in keys(local.databases) :
    db => aws_secretsmanager_secret.db_credentials[db].arn
  }
}

output "db_subnet_group_name" {
  description = "Name of the DB subnet group"
  value       = aws_db_subnet_group.main.name
}

output "parameter_group_name" {
  description = "Name of the DB parameter group"
  value       = aws_db_parameter_group.postgres.name
}