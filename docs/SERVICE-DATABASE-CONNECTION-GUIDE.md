# Service Database Connection Guide

## Overview

All services connect to the **existing authdb** database using their specific schemas. This guide ensures proper configuration for each service.

## Database Configuration

**Database Name:** `authdb`  
**Instance:** `event-planner-dev-auth-db`  
**Endpoint:** Retrieved from Secrets Manager

## Schema Mapping

| Service | Schema | Secret Key | Status |
|---------|--------|------------|--------|
| **Auth Service** | `public` | `auth` | ✅ Working |
| **Event Service** | `event_schema` | `event` | ✅ Working |
| **Payment Service** | `payment_schema` | `payment` | ⏳ Ready |
| **Notification Service** | N/A | N/A | ℹ️ No database needed |

## Current ECS Configuration

### Auth Service
**Environment Variables (from Secrets Manager):**
```
AUTH_SERVICE_DB_URL      → secret:auth:url
AUTH_SERVICE_DB_USER     → secret:auth:username
AUTH_SERVICE_DB_PASSWORD → secret:auth:password
```

**Connection String:**
```
jdbc:postgresql://event-planner-dev-auth-db.xxx.rds.amazonaws.com:5432/authdb
```
Uses default `public` schema.

### Event Service
**Environment Variables (from Secrets Manager):**
```
SPRING_DATASOURCE_URL      → secret:event:url
SPRING_DATASOURCE_USERNAME → secret:event:username
SPRING_DATASOURCE_PASSWORD → secret:event:password
EVENT_SERVICE_DB_URL       → secret:event:url
```

**Connection String:**
```
jdbc:postgresql://event-planner-dev-auth-db.xxx.rds.amazonaws.com:5432/authdb?currentSchema=event_schema
```
Uses `event_schema` schema.

### Payment Service (When Deployed)
**Environment Variables (from Secrets Manager):**
```
SPRING_DATASOURCE_URL      → secret:payment:url
SPRING_DATASOURCE_USERNAME → secret:payment:username
SPRING_DATASOURCE_PASSWORD → secret:payment:password
```

**Connection String:**
```
jdbc:postgresql://event-planner-dev-auth-db.xxx.rds.amazonaws.com:5432/authdb?currentSchema=payment_schema
```
Uses `payment_schema` schema.

## Secrets Manager Configuration

Each service has its own secret with schema-specific connection information:

### Auth Service Secret
**Secret Name:** `event-planner/dev/auth-db-*`

```json
{
  "username": "dbadmin",
  "password": "existing-password",
  "engine": "postgres",
  "host": "event-planner-dev-auth-db.xxx.rds.amazonaws.com",
  "port": 5432,
  "dbname": "authdb",
  "schema": "public",
  "url": "jdbc:postgresql://host:5432/authdb"
}
```

### Event Service Secret
**Secret Name:** `event-planner/dev/event-db-*`

```json
{
  "username": "dbadmin",
  "password": "existing-password",
  "engine": "postgres",
  "host": "event-planner-dev-auth-db.xxx.rds.amazonaws.com",
  "port": 5432,
  "dbname": "authdb",
  "schema": "event_schema",
  "url": "jdbc:postgresql://host:5432/authdb?currentSchema=event_schema"
}
```

### Payment Service Secret
**Secret Name:** `event-planner/dev/payment-db-*`

```json
{
  "username": "dbadmin",
  "password": "existing-password",
  "engine": "postgres",
  "host": "event-planner-dev-auth-db.xxx.rds.amazonaws.com",
  "port": 5432,
  "dbname": "authdb",
  "schema": "payment_schema",
  "url": "jdbc:postgresql://host:5432/authdb?currentSchema=payment_schema"
}
```

## Backend Service Configuration

### Spring Boot Configuration

Each service should configure their datasource:

**Auth Service (application.yml):**
```yaml
spring:
  datasource:
    url: ${AUTH_SERVICE_DB_URL}
    username: ${AUTH_SERVICE_DB_USER}
    password: ${AUTH_SERVICE_DB_PASSWORD}
  jpa:
    properties:
      hibernate:
        default_schema: public  # Optional, public is default
```

**Event Service (application.yml):**
```yaml
spring:
  datasource:
    url: ${SPRING_DATASOURCE_URL}
    username: ${SPRING_DATASOURCE_USERNAME}
    password: ${SPRING_DATASOURCE_PASSWORD}
  jpa:
    properties:
      hibernate:
        default_schema: event_schema
```

**Payment Service (application.yml):**
```yaml
spring:
  datasource:
    url: ${SPRING_DATASOURCE_URL}
    username: ${SPRING_DATASOURCE_USERNAME}
    password: ${SPRING_DATASOURCE_PASSWORD}
  jpa:
    properties:
      hibernate:
        default_schema: payment_schema
```

## Schema Creation

Schemas must exist in the database before services can use them:

```sql
-- Connect to authdb as dbadmin
\c authdb

-- Create schemas (if not exists)
CREATE SCHEMA IF NOT EXISTS event_schema;
CREATE SCHEMA IF NOT EXISTS payment_schema;

-- Grant permissions
GRANT ALL ON SCHEMA public TO dbadmin;
GRANT ALL ON SCHEMA event_schema TO dbadmin;
GRANT ALL ON SCHEMA payment_schema TO dbadmin;

-- Verify schemas
\dn
```

## Verification Steps

### 1. Check Secrets Exist

```bash
# List all database secrets
aws secretsmanager list-secrets \
  --filters Key=name,Values=event-planner/dev \
  --profile gtp-cletus \
  --region eu-west-1 \
  --query 'SecretList[?contains(Name, `db`)].Name'
```

### 2. Verify Secret Content

```bash
# Check auth secret
aws secretsmanager get-secret-value \
  --secret-id event-planner/dev/auth-db-xxx \
  --profile gtp-cletus \
  --region eu-west-1 \
  --query SecretString \
  --output text | jq

# Check event secret
aws secretsmanager get-secret-value \
  --secret-id event-planner/dev/event-db-xxx \
  --profile gtp-cletus \
  --region eu-west-1 \
  --query SecretString \
  --output text | jq
```

### 3. Test Database Connection

```bash
# Connect to authdb
psql -h event-planner-dev-auth-db.xxx.rds.amazonaws.com \
     -U dbadmin \
     -d authdb \
     -c "\dn"  # List schemas
```

### 4. Verify Service Connections

```bash
# Check auth service logs
aws logs tail /ecs/event-planner-dev-auth-service \
  --follow \
  --profile gtp-cletus \
  --region eu-west-1

# Check event service logs
aws logs tail /ecs/event-planner-dev-event-service \
  --follow \
  --profile gtp-cletus \
  --region eu-west-1
```

## Troubleshooting

### Issue: Service Cannot Connect to Database

**Check:**
1. Secret exists and contains correct values
2. Schema exists in database
3. ECS task has correct IAM permissions
4. Security group allows connection from ECS to RDS
5. Connection string includes schema parameter

**Solution:**
```bash
# Verify secret
aws secretsmanager get-secret-value --secret-id <secret-arn>

# Check security group
aws ec2 describe-security-groups --group-ids <rds-sg-id>

# Verify schema exists
psql -h <host> -U dbadmin -d authdb -c "\dn"
```

### Issue: Wrong Schema Being Used

**Check:**
1. Connection URL includes `?currentSchema=<schema_name>`
2. Hibernate default_schema is set correctly
3. Secret contains correct schema information

**Solution:**
Update connection string to include schema:
```
jdbc:postgresql://host:5432/authdb?currentSchema=event_schema
```

### Issue: Permission Denied on Schema

**Check:**
1. User has permissions on schema
2. Schema ownership is correct

**Solution:**
```sql
GRANT ALL ON SCHEMA event_schema TO dbadmin;
GRANT ALL ON ALL TABLES IN SCHEMA event_schema TO dbadmin;
```

## Migration Checklist

When deploying a new service:

- [ ] Create schema in authdb database
- [ ] Grant permissions to dbadmin user
- [ ] Create Secrets Manager secret with schema info
- [ ] Update ECS task definition with secret ARN
- [ ] Configure service application.yml with schema
- [ ] Test database connection
- [ ] Verify schema isolation
- [ ] Check service logs for connection success

## Security Notes

1. **Same Password:** All services use the same database password (stored in separate secrets)
2. **Schema Isolation:** Each service can only see its own schema tables
3. **IAM Authentication:** Can be enabled for additional security
4. **Encryption:** All connections use SSL/TLS
5. **Secrets Rotation:** Can be configured in Secrets Manager

## Benefits of Multi-Schema Approach

1. ✅ **Cost Savings:** Single RDS instance (~60% cheaper)
2. ✅ **Simplified Management:** One database to backup/monitor
3. ✅ **Data Isolation:** Schemas provide logical separation
4. ✅ **Easy Migrations:** Can query across schemas if needed
5. ✅ **Shared Resources:** Connection pooling benefits all services

## Support

For database connection issues:
- Check service logs in CloudWatch
- Verify secrets in Secrets Manager
- Test connection from ECS task
- Review security group rules
- Confirm schema exists in database
