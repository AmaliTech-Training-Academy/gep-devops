# RDS Multi-Schema Configuration

## Overview

The infrastructure now uses a **single PostgreSQL database with multiple schemas** instead of separate databases for each service. This simplifies management and reduces costs.

## Database Configuration

**Database Name:** `authdb`  
**Instance:** `event-planner-dev-auth-db`  
**Endpoint:** Retrieved from Secrets Manager

## Schema Mapping

| Service | Schema | Description |
|---------|--------|-------------|
| **Auth Service** | `public` | Default PostgreSQL schema for user authentication |
| **Event Service** | `event_schema` | Dedicated schema for event management |
| **Payment Service** | `payment_schema` | Dedicated schema for payment processing |

## Connection Configuration

### Backend Services

Each service connects to the same database but uses a different schema:

**Auth Service:**
```yaml
spring:
  datasource:
    url: jdbc:postgresql://${DB_HOST}:5432/authdb
    # Uses default 'public' schema
```

**Event Service:**
```yaml
spring:
  datasource:
    url: jdbc:postgresql://${DB_HOST}:5432/authdb?currentSchema=event_schema
    # OR set in application properties:
  jpa:
    properties:
      hibernate:
        default_schema: event_schema
```

**Payment Service:**
```yaml
spring:
  datasource:
    url: jdbc:postgresql://${DB_HOST}:5432/authdb?currentSchema=payment_schema
    # OR set in application properties:
  jpa:
    properties:
      hibernate:
        default_schema: payment_schema
```

## Secrets Manager

Each service has its own secret with schema information:

**Auth Service Secret:**
```json
{
  "username": "dbadmin",
  "password": "...",
  "host": "event-planner-dev-auth-db.xxx.eu-west-1.rds.amazonaws.com",
  "port": 5432,
  "dbname": "authdb",
  "schema": "public",
  "url": "jdbc:postgresql://host:5432/authdb?currentSchema=public"
}
```

**Event Service Secret:**
```json
{
  "username": "dbadmin",
  "password": "...",
  "host": "event-planner-dev-auth-db.xxx.eu-west-1.rds.amazonaws.com",
  "port": 5432,
  "dbname": "authdb",
  "schema": "event_schema",
  "url": "jdbc:postgresql://host:5432/authdb?currentSchema=event_schema"
}
```

**Payment Service Secret:**
```json
{
  "username": "dbadmin",
  "password": "...",
  "host": "event-planner-dev-auth-db.xxx.eu-west-1.rds.amazonaws.com",
  "port": 5432,
  "dbname": "authdb",
  "schema": "payment_schema",
  "url": "jdbc:postgresql://host:5432/authdb?currentSchema=payment_schema"
}
```

## Schema Creation

Schemas must be created manually or via migration scripts:

```sql
-- Connect to authdb as dbadmin
CREATE SCHEMA IF NOT EXISTS event_schema;
CREATE SCHEMA IF NOT EXISTS payment_schema;

-- Grant permissions
GRANT ALL ON SCHEMA event_schema TO dbadmin;
GRANT ALL ON SCHEMA payment_schema TO dbadmin;
```

## Benefits

1. **Cost Savings:** Single RDS instance instead of 3 separate instances (~60% cost reduction)
2. **Simplified Management:** One database to backup, monitor, and maintain
3. **Data Isolation:** Schemas provide logical separation between services
4. **Easier Migrations:** Can move data between schemas without cross-database queries
5. **Shared Resources:** Connection pooling and memory shared across services

## Migration from Separate Databases

If you had separate databases before:

1. **Backup existing data** from each database
2. **Create schemas** in authdb
3. **Restore data** to respective schemas
4. **Update application configurations** to use new connection strings
5. **Test thoroughly** before decommissioning old databases

## Monitoring

All services share the same CloudWatch metrics:
- CPU Utilization
- Database Connections
- Storage Space
- Read/Write IOPS

Monitor connection counts per service using application-level metrics.

## Security

- Same password for all services (stored in separate secrets)
- Schema-level permissions can be configured for additional isolation
- Each service secret contains schema information for proper routing

## Terraform Changes

**Removed:**
- Individual database resources (`event-db`, `payment-db`)
- Per-database variables
- Per-database secrets
- Per-database CloudWatch alarms

**Added:**
- Single database resource
- Schema mapping in locals
- Per-service secrets with schema information
- Unified CloudWatch alarms

## Rollback Plan

If issues arise, you can:
1. Keep the single database approach
2. Create separate databases again (uncomment old code)
3. Migrate data back to separate databases

The Terraform code is designed to be reversible.
