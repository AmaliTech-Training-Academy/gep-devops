# Database Connection Verification Checklist

## ✅ Infrastructure Configuration Status

### RDS Module Configuration

**✅ Single Database Resource**
- Database: `authdb` (existing)
- Instance: `event-planner-dev-auth-db`
- All services connect to this database

**✅ Schema Mapping Configured**
```hcl
schemas = {
  auth    = "public"
  event   = "event_schema"
  payment = "payment_schema"
}
```

**✅ Secrets Created for All Services**
- `event-planner/dev/auth-db-*` → Auth service
- `event-planner/dev/event-db-*` → Event service
- `event-planner/dev/payment-db-*` → Payment service

**✅ Secret Content Includes Schema Info**
Each secret contains:
- `host`: Database endpoint
- `port`: 5432
- `dbname`: authdb
- `schema`: Service-specific schema
- `url`: JDBC URL with schema parameter
- `username`: dbadmin
- `password`: Database password

### ECS Module Configuration

**✅ Auth Service**
```hcl
Environment variables from secret:auth
- AUTH_SERVICE_DB_URL
- AUTH_SERVICE_DB_USER
- AUTH_SERVICE_DB_PASSWORD
```

**✅ Event Service**
```hcl
Environment variables from secret:event
- SPRING_DATASOURCE_URL
- SPRING_DATASOURCE_USERNAME
- SPRING_DATASOURCE_PASSWORD
- EVENT_SERVICE_DB_URL
```

**✅ Payment Service**
```hcl
Environment variables from secret:payment
- SPRING_DATASOURCE_URL
- SPRING_DATASOURCE_USERNAME
- SPRING_DATASOURCE_PASSWORD
```

## Connection Flow

```
┌─────────────────┐
│  Auth Service   │──→ authdb (public schema)
└─────────────────┘

┌─────────────────┐
│  Event Service  │──→ authdb (event_schema)
└─────────────────┘

┌─────────────────┐
│ Payment Service │──→ authdb (payment_schema)
└─────────────────┘

All connect to: event-planner-dev-auth-db.xxx.rds.amazonaws.com:5432/authdb
```

## Verification Steps

### 1. Verify Terraform Configuration

```bash
cd terraform/environments/dev

# Check RDS outputs
terraform output -json | jq '.rds'

# Should show:
# - primary_endpoint
# - schemas (auth, event, payment)
# - secret_arns (auth, event, payment)
```

### 2. Verify Secrets Exist

```bash
# List all database secrets
aws secretsmanager list-secrets \
  --filters Key=name,Values=event-planner/dev \
  --profile gtp-cletus \
  --region eu-west-1 \
  --query 'SecretList[?contains(Name, `db`)].Name' \
  --output table

# Expected output:
# event-planner/dev/auth-db-xxx
# event-planner/dev/event-db-xxx
# event-planner/dev/payment-db-xxx
```

### 3. Verify Secret Content

```bash
# Check auth secret has correct schema
aws secretsmanager get-secret-value \
  --secret-id $(aws secretsmanager list-secrets --query 'SecretList[?contains(Name, `auth-db`)].ARN' --output text) \
  --profile gtp-cletus \
  --region eu-west-1 \
  --query SecretString \
  --output text | jq '.schema'
# Expected: "public"

# Check event secret has correct schema
aws secretsmanager get-secret-value \
  --secret-id $(aws secretsmanager list-secrets --query 'SecretList[?contains(Name, `event-db`)].ARN' --output text) \
  --profile gtp-cletus \
  --region eu-west-1 \
  --query SecretString \
  --output text | jq '.schema'
# Expected: "event_schema"

# Check payment secret has correct schema
aws secretsmanager get-secret-value \
  --secret-id $(aws secretsmanager list-secrets --query 'SecretList[?contains(Name, `payment-db`)].ARN' --output text) \
  --profile gtp-cletus \
  --region eu-west-1 \
  --query SecretString \
  --output text | jq '.schema'
# Expected: "payment_schema"
```

### 4. Verify Database Schemas Exist

```bash
# Connect to database and list schemas
psql -h event-planner-dev-auth-db.xxx.rds.amazonaws.com \
     -U dbadmin \
     -d authdb \
     -c "\dn"

# Expected output:
#   Name        | Owner
# --------------+--------
#  public       | dbadmin
#  event_schema | dbadmin
#  payment_schema | dbadmin (if created)
```

### 5. Verify ECS Task Definitions

```bash
# Check auth service task definition
aws ecs describe-task-definition \
  --task-definition event-planner-dev-auth-service \
  --profile gtp-cletus \
  --region eu-west-1 \
  --query 'taskDefinition.containerDefinitions[0].secrets[?name==`AUTH_SERVICE_DB_URL`]'

# Check event service task definition
aws ecs describe-task-definition \
  --task-definition event-planner-dev-event-service \
  --profile gtp-cletus \
  --region eu-west-1 \
  --query 'taskDefinition.containerDefinitions[0].secrets[?name==`SPRING_DATASOURCE_URL`]'
```

### 6. Test Service Connections

```bash
# Check auth service logs for successful connection
aws logs tail /ecs/event-planner-dev-auth-service \
  --since 10m \
  --profile gtp-cletus \
  --region eu-west-1 \
  --filter-pattern "Connected to database"

# Check event service logs for successful connection
aws logs tail /ecs/event-planner-dev-event-service \
  --since 10m \
  --profile gtp-cletus \
  --region eu-west-1 \
  --filter-pattern "HikariPool.*started"
```

## Pre-Deployment Checklist

Before deploying payment service:

- [ ] Create `payment_schema` in authdb database
- [ ] Grant permissions to dbadmin user
- [ ] Verify payment secret exists in Secrets Manager
- [ ] Verify payment secret contains correct schema info
- [ ] Update payment service application.yml with schema configuration
- [ ] Test connection from local environment
- [ ] Deploy payment service to ECS
- [ ] Verify payment service logs show successful connection

## Post-Deployment Verification

After applying Terraform changes:

- [ ] All three secrets exist (auth, event, payment)
- [ ] Each secret contains correct schema information
- [ ] Auth service still connects successfully
- [ ] Event service still connects successfully
- [ ] No service disruption occurred
- [ ] Database endpoint unchanged
- [ ] All schemas accessible

## Rollback Plan

If any service cannot connect:

1. **Check secret content** - Verify schema information is correct
2. **Check ECS task definition** - Verify secret ARN is correct
3. **Check service logs** - Identify connection error
4. **Verify schema exists** - Create if missing
5. **Restart service** - Force new deployment
6. **Revert Terraform** - If needed, revert to previous state

## Success Criteria

✅ All services can connect to authdb  
✅ Each service uses its designated schema  
✅ No cross-schema data access  
✅ No service disruption  
✅ All existing data intact  
✅ Secrets properly configured  
✅ ECS tasks have correct environment variables

## Documentation

- 📄 `SERVICE-DATABASE-CONNECTION-GUIDE.md` - Detailed connection guide
- 📄 `RDS-MULTI-SCHEMA-CONFIGURATION.md` - Schema configuration
- 📄 `RDS-CODE-CLEANUP-SUMMARY.md` - Code changes summary

## Support

If verification fails:
1. Review service logs in CloudWatch
2. Check Secrets Manager for correct values
3. Verify schema exists in database
4. Test connection manually
5. Review security group rules
6. Confirm IAM permissions
