# Database Schema Setup for Event Service

## Current Status

✅ **COMPLETED**: The event service is configured to connect to the auth database and use the `event_schema`. The schema has been created and is ready for use.

## Database Architecture

```
PostgreSQL Instance: event-planner-dev-auth-db
├── Database: authdb
│   ├── Schema: public (auth service tables)
│   ├── Schema: event_schema (event service tables) ✅ CREATED
│   └── Schema: audit_logs (shared audit tables)
```

## Schema Verification

### 1. Verify Schema Exists

```sql
-- Switch to event schema
SET search_path TO event_schema, public;

-- Create a test table to verify permissions
CREATE TABLE IF NOT EXISTS event_schema.connection_test (
    id SERIAL PRIMARY KEY,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert test data
INSERT INTO event_schema.connection_test DEFAULT VALUES;

-- Verify
SELECT * FROM event_schema.connection_test;

-- Clean up test table
DROP TABLE event_schema.connection_test;
```

## Spring Boot Configuration

The event service is configured with these environment variables:

```yaml
Environment Variables:
  SPRING_DATASOURCE_URL: jdbc:postgresql://auth-db:5432/authdb
  SPRING_DATASOURCE_USERNAME: dbadmin
  SPRING_DATASOURCE_PASSWORD: <from-secrets-manager>
  SPRING_JPA_PROPERTIES_HIBERNATE_DEFAULT_SCHEMA: event_schema
  SPRING_DATASOURCE_SCHEMA_SEARCH_PATH: event_schema,public
  DATABASE_SCHEMA: event_schema
  SPRING_JPA_HIBERNATE_DDL_AUTO: update
  SPRING_JPA_DATABASE_PLATFORM: org.hibernate.dialect.PostgreSQLDialect
```

## Application Properties

The event service should have these properties in `application.yml`:

```yaml
spring:
  datasource:
    url: ${SPRING_DATASOURCE_URL}
    username: ${SPRING_DATASOURCE_USERNAME}
    password: ${SPRING_DATASOURCE_PASSWORD}
    schema: ${DATABASE_SCHEMA}
  jpa:
    hibernate:
      ddl-auto: ${SPRING_JPA_HIBERNATE_DDL_AUTO:update}
    properties:
      hibernate:
        default_schema: ${SPRING_JPA_PROPERTIES_HIBERNATE_DEFAULT_SCHEMA}
        dialect: ${SPRING_JPA_DATABASE_PLATFORM}
    database-platform: ${SPRING_JPA_DATABASE_PLATFORM}
```

## Verification Steps

### 1. Check Schema Exists

```sql
SELECT schema_name 
FROM information_schema.schemata 
WHERE schema_name = 'event_schema';
```

### 2. Check Tables Created by Event Service

```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'event_schema';
```

### 3. Monitor Event Service Logs

```bash
# Check ECS logs for event service
aws logs tail /ecs/event-planner/dev/event-service --follow
```

## Troubleshooting

### Common Issues

1. **Schema Not Found Error**
   ```
   ERROR: schema "event_schema" does not exist
   ```
   **Solution:** Run the schema creation SQL above

2. **Permission Denied**
   ```
   ERROR: permission denied for schema event_schema
   ```
   **Solution:** Grant proper permissions to the database user

3. **Connection Refused**
   ```
   ERROR: could not connect to server
   ```
   **Solution:** Check security groups and network connectivity

### Debug Commands

```bash
# Check ECS task environment variables
aws ecs describe-tasks \
  --cluster event-planner-dev-cluster \
  --tasks $(aws ecs list-tasks \
    --cluster event-planner-dev-cluster \
    --service-name event-service \
    --query 'taskArns[0]' --output text) \
  --query 'tasks[0].containers[0].environment'

# Check database connectivity from ECS task
aws ecs execute-command \
  --cluster event-planner-dev-cluster \
  --task <TASK_ARN> \
  --container event-service \
  --interactive \
  --command "/bin/bash"

# Inside container:
# pg_isready -h $SPRING_DATASOURCE_URL -p 5432
# psql $SPRING_DATASOURCE_URL -c "SELECT current_schema();"
```

## ✅ Ready for Deployment

The event service is now properly configured to:
- Connect to the shared auth database
- Use the dedicated `event_schema` for data isolation
- Access the database with proper credentials from AWS Secrets Manager
- Create tables automatically via Hibernate DDL

## Future Improvements

### Option 1: Dedicated Event Database (Recommended for Production)

```hcl
# In terraform/modules/rds/main.tf
databases = {
  auth = { ... }
  event = {
    instance_class        = "db.t3.micro"
    allocated_storage     = 20
    max_allocated_storage = 100
    read_replica_count    = 0
    port                  = 5432
  }
}
```

### Option 2: Database Initialization Script

Create a Lambda function to automatically set up schemas:

```python
import psycopg2
import boto3

def lambda_handler(event, context):
    # Get database credentials from Secrets Manager
    # Connect to database
    # Create schemas if they don't exist
    # Set up permissions
    pass
```

### Option 3: Init Container

Add an init container to the ECS task definition that sets up the schema before the main container starts.

## Security Considerations

1. **Schema Isolation**: Each service uses its own schema for data isolation
2. **Least Privilege**: Each service should only access its own schema
3. **Audit Logging**: All schema changes should be logged
4. **Backup Strategy**: Ensure schemas are included in backup procedures

## Monitoring

Set up CloudWatch alarms for:
- Schema-specific table counts
- Connection errors by schema
- Query performance by schema
- Storage usage by schema

```sql
-- Monitor schema usage
SELECT 
    schemaname,
    COUNT(*) as table_count,
    pg_size_pretty(SUM(pg_total_relation_size(schemaname||'.'||tablename))) as total_size
FROM pg_tables 
WHERE schemaname IN ('public', 'event_schema')
GROUP BY schemaname;
```