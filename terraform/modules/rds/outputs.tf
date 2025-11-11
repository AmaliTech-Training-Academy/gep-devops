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

output "primary_endpoints" {
  description = "Network addresses where applications connect to each business database (auth, event, payment). Like office addresses for different departments."
  value = {
    for db, config in local.databases :
    db => {
      address  = aws_db_instance.primary[db].address  # Database server hostname
      port     = aws_db_instance.primary[db].port     # Network port (usually 5432 for PostgreSQL)
      endpoint = aws_db_instance.primary[db].endpoint # Complete connection string
    }
  }
}

output "primary_instance_ids" {
  description = "Unique identifiers for each database instance. Operations team uses these for monitoring, backups, and troubleshooting database issues."
  value = {
    for db in keys(local.databases) :
    db => aws_db_instance.primary[db].identifier
  }
}

# ==============================================================================
# Performance Enhancement Information
# ==============================================================================

output "read_replica_endpoints" {
  description = "Network addresses for read-only database copies that improve performance. Applications use these for data queries while main database handles updates."
  value = var.create_read_replicas ? {
    for db in keys(local.databases) :
    db => {
      replica_1 = {
        address = aws_db_instance.read_replica_1[db].address  # First read-only copy
        port    = aws_db_instance.read_replica_1[db].port
      }
      replica_2 = {
        address = aws_db_instance.read_replica_2[db].address  # Second read-only copy
        port    = aws_db_instance.read_replica_2[db].port
      }
    }
  } : {}
}

# ==============================================================================
# Security and Configuration Information
# ==============================================================================

output "secret_arns" {
  description = "Secure storage locations for database passwords and credentials. Applications retrieve these securely without hardcoding sensitive information."
  value = {
    for db in keys(local.databases) :
    db => aws_secretsmanager_secret.db_credentials[db].arn
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