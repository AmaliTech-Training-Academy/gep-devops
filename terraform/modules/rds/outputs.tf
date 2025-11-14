# ==============================================================================
# RDS Module Outputs - Database Connection Information
# ==============================================================================
# WHAT THIS FILE PROVIDES:
# Connection details and identifiers for our business databases that applications
# need to store and retrieve customer data. Like providing office addresses and
# phone numbers so different departments can communicate with each other.
#
# INFORMATION CATEGORIES:
# - Database Endpoints: Network addresses where applications connect to databases
# - Security Credentials: Secure storage locations for database passwords
# - Instance Identifiers: Unique names for monitoring and operations
# - Network Configuration: Subnet and security group information
#
# WHO USES THIS INFORMATION:
# - Applications: Need endpoints and credentials to store/retrieve business data
# - Monitoring Systems: Need instance IDs to track database health and performance
# - Operations Team: Need identifiers for troubleshooting and maintenance
# - Security Systems: Need credential locations for access management
#
# BUSINESS IMPACT:
# - Enables secure application-to-database communication
# - Supports monitoring and alerting for business continuity
# - Facilitates troubleshooting to minimize downtime
# - Maintains security through proper credential management
# ==============================================================================

# ==============================================================================
# Database Connection Information
# ==============================================================================

output "primary_endpoint" {
  description = "Network address where all services connect to the database. Each service uses its own schema."
  value = {
    address  = aws_db_instance.primary.address
    port     = aws_db_instance.primary.port
    endpoint = aws_db_instance.primary.endpoint
    database = local.db_name
  }
}

output "primary_instance_id" {
  description = "Unique identifier for the database instance. Used for monitoring, backups, and troubleshooting."
  value       = aws_db_instance.primary.identifier
}

output "schemas" {
  description = "Schema mapping for each service. Services use these schemas to isolate their data."
  value       = local.schemas
}

# ==============================================================================
# Performance Enhancement Information
# ==============================================================================

output "read_replica_endpoints" {
  description = "Network addresses for read-only database copies that improve performance."
  value = var.create_read_replicas ? {
    replica_1 = {
      address = aws_db_instance.read_replica_1[0].address
      port    = aws_db_instance.read_replica_1[0].port
    }
    replica_2 = {
      address = aws_db_instance.read_replica_2[0].address
      port    = aws_db_instance.read_replica_2[0].port
    }
  } : {}
}

# ==============================================================================
# Security and Configuration Information
# ==============================================================================

output "secret_arns" {
  description = "Secure storage locations for database credentials per service. Each secret contains schema information."
  value = {
    for service in keys(local.schemas) :
    service => aws_secretsmanager_secret.db_credentials[service].arn
  }
}

output "db_subnet_group_name" {
  description = "Name of the network group that defines which secure subnets databases can use. Ensures databases stay in protected network areas."
  value       = aws_db_subnet_group.main.name
}

output "parameter_group_name" {
  description = "Name of the configuration template that defines database performance and security settings. Ensures consistent configuration across all databases."
  value       = aws_db_parameter_group.postgres.name
}