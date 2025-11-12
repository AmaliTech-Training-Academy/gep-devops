# Import Existing authdb into Terraform

## Current Situation

- **authdb is already running** with all configurations
- Event service is already connected and using its schema
- We need to import it into Terraform without disrupting it

## Import Steps

### 1. Check Current Database Details

```bash
aws rds describe-db-instances \
  --db-instance-identifier event-planner-dev-auth-db \
  --profile gtp-cletus \
  --region eu-west-1 \
  --query 'DBInstances[0].[DBInstanceIdentifier,DBInstanceClass,AllocatedStorage,Engine,EngineVersion]' \
  --output table
```

### 2. Import Database into Terraform State

```bash
cd terraform/environments/dev

# Import the existing RDS instance
terraform import module.rds.aws_db_instance.primary event-planner-dev-auth-db

# Import existing secrets (if they exist)
terraform import 'module.rds.aws_secretsmanager_secret.db_credentials["auth"]' <secret-arn>
terraform import 'module.rds.aws_secretsmanager_secret.db_credentials["event"]' <secret-arn>
terraform import 'module.rds.aws_secretsmanager_secret.db_credentials["payment"]' <secret-arn>
```

### 3. Verify Import

```bash
terraform plan
# Should show no changes if import was successful
```

## What Terraform Will NOT Change

- ✅ Database name (authdb)
- ✅ Existing data
- ✅ Existing schemas
- ✅ Current connections
- ✅ Endpoint address
- ✅ Master password (managed separately)

## What Terraform WILL Manage

- ✅ Instance configuration (size, storage)
- ✅ Backup settings
- ✅ Monitoring settings
- ✅ Security groups
- ✅ Parameter groups
- ✅ CloudWatch alarms

## Schema Configuration

The existing schemas remain unchanged:
- `public` - Auth service (already configured)
- `event_schema` - Event service (already configured)
- `payment_schema` - Payment service (to be created when needed)

## Secrets Configuration

Each service will have its own secret pointing to the same database:

**Auth Service Secret:**
```json
{
  "host": "event-planner-dev-auth-db.xxx.rds.amazonaws.com",
  "port": 5432,
  "dbname": "authdb",
  "schema": "public",
  "username": "dbadmin",
  "password": "existing-password"
}
```

**Event Service Secret:**
```json
{
  "host": "event-planner-dev-auth-db.xxx.rds.amazonaws.com",
  "port": 5432,
  "dbname": "authdb",
  "schema": "event_schema",
  "username": "dbadmin",
  "password": "existing-password"
}
```

## Safety Measures

1. **Lifecycle Protection:**
```hcl
lifecycle {
  prevent_destroy = true  # Prevents accidental deletion
  ignore_changes = [
    password,  # Don't change existing password
    db_name,   # Don't change database name
  ]
}
```

2. **Backup Before Changes:**
```bash
aws rds create-db-snapshot \
  --db-instance-identifier event-planner-dev-auth-db \
  --db-snapshot-identifier authdb-before-terraform-$(date +%Y%m%d) \
  --profile gtp-cletus \
  --region eu-west-1
```

## Rollback Plan

If anything goes wrong:
1. Terraform state can be removed: `terraform state rm module.rds.aws_db_instance.primary`
2. Database continues running unchanged
3. No data loss - database is never destroyed

## Testing

After import:
1. Verify auth service still works
2. Verify event service still works
3. Check database connections
4. Review Terraform plan for any unexpected changes
