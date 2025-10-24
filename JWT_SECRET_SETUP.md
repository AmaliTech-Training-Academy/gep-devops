# JWT Secret Configuration Complete

## What Was Configured

### 1. JWT Secret in Secrets Manager
**File:** `terraform/environments/dev/jwt-secret.tf`
- Creates random 64-character JWT secret
- Stores in AWS Secrets Manager as `event-planner-dev-jwt-secret`
- Format: `{"JWT_SECRET": "random-64-char-string"}`

### 2. ECS Task Definition Updated
**File:** `terraform/modules/ecs/main.tf`
- Added JWT_SECRET to auth-service secrets
- Pulls from Secrets Manager at runtime
- Format: `JWT_SECRET` environment variable

### 3. IAM Permissions Updated
**File:** `terraform/modules/iam/main.tf`
- ECS Task Execution Role can now read JWT secret
- Added to existing Secrets Manager permissions

### 4. Module Variables Added
**Files:**
- `terraform/modules/ecs/variables.tf` - Added `jwt_secret_arn`
- `terraform/modules/iam/variables.tf` - Added `jwt_secret_arn`

### 5. Environment Configuration
**File:** `terraform/environments/dev/main.tf`
- Passes JWT secret ARN to ECS module
- Passes JWT secret ARN to IAM module

## How It Works

```
1. Terraform creates JWT secret
   ↓
2. Stores in Secrets Manager
   ↓
3. ECS Task Definition references secret ARN
   ↓
4. IAM role grants read permission
   ↓
5. ECS injects JWT_SECRET as environment variable
   ↓
6. Auth service reads JWT_SECRET on startup
```

## Deploy Instructions

```bash
cd terraform/environments/dev

# Initialize (if needed)
terraform init

# Plan changes
terraform plan

# Apply changes
terraform apply
```

## What Will Be Created

1. **AWS Secrets Manager Secret:**
   - Name: `event-planner-dev-jwt-secret`
   - Value: Random 64-character string
   - Cost: $0.40/month

2. **Updated ECS Task Definition:**
   - auth-service will have JWT_SECRET injected
   - No changes to event-service

3. **Updated IAM Policy:**
   - Task execution role can read JWT secret

## Verify After Deployment

```bash
# Check secret exists
aws secretsmanager describe-secret \
  --secret-id event-planner-dev-jwt-secret \
  --region eu-west-1

# Check secret value (for testing only)
aws secretsmanager get-secret-value \
  --secret-id event-planner-dev-jwt-secret \
  --region eu-west-1 \
  --query 'SecretString' \
  --output text | jq .

# Check ECS task definition
aws ecs describe-task-definition \
  --task-definition event-planner-dev-auth-service \
  --region eu-west-1 \
  --query 'taskDefinition.containerDefinitions[0].secrets'

# Force new deployment to pick up changes
aws ecs update-service \
  --cluster event-planner-dev-cluster \
  --service auth-service \
  --force-new-deployment \
  --region eu-west-1

# Check logs
aws logs tail /ecs/event-planner/dev/auth-service \
  --follow \
  --region eu-west-1
```

## Expected Result

After deployment:
1. ✅ JWT secret created in Secrets Manager
2. ✅ ECS task definition updated with secret reference
3. ✅ IAM permissions granted
4. ✅ Auth service starts successfully
5. ✅ No more "Could not resolve placeholder 'JWT_SECRET'" error
6. ✅ Service becomes healthy
7. ✅ ALB returns 200 instead of 503

## Troubleshooting

### If service still fails:

**Check IAM permissions:**
```bash
aws iam get-role-policy \
  --role-name $(aws iam list-roles --query 'Roles[?contains(RoleName, `ecs-execution`)].RoleName' --output text) \
  --policy-name secrets-access
```

**Check task definition:**
```bash
aws ecs describe-task-definition \
  --task-definition event-planner-dev-auth-service \
  --query 'taskDefinition.containerDefinitions[0].secrets' \
  --output table
```

**Check logs for JWT_SECRET:**
```bash
# Should NOT see "Could not resolve placeholder 'JWT_SECRET'"
aws logs filter-log-events \
  --log-group-name /ecs/event-planner/dev/auth-service \
  --filter-pattern "JWT_SECRET" \
  --region eu-west-1
```

## Security Notes

- ✅ Secret is encrypted at rest in Secrets Manager
- ✅ Secret is encrypted in transit (TLS)
- ✅ Secret is never logged or exposed
- ✅ IAM permissions follow least privilege
- ✅ Secret can be rotated without code changes

## Cost Impact

- JWT Secret: $0.40/month
- API calls: ~$0.05/month (10,000 calls free tier)
- **Total:** ~$0.45/month

## Next Steps

1. Run `terraform apply`
2. Wait for deployment to complete
3. Test endpoint: `https://api.sankofagrid.com/api/v1/auth/login`
4. Should get proper response (not 503)
