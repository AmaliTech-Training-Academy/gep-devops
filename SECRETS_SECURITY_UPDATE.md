# Secrets Security Update - October 29, 2025

## Summary

Moved sensitive credentials from hardcoded environment variables to AWS Secrets Manager for secure storage and retrieval.

## Changes Implemented

### 1. Created Google Credentials Secret in Secrets Manager

**Secret Name:** `event-planner/dev/google-credentials`

**Secret ARN:** `arn:aws:secretsmanager:eu-west-1:904570587823:secret:event-planner/dev/google-credentials-y9gEoP`

**Secret Structure:**
```json
{
  "user": "noreply@sankofagrid.com",
  "password": "REPLACE_WITH_ACTUAL_PASSWORD"
}
```

### 2. Updated ECS Task Definitions

**Before (Hardcoded - INSECURE):**
```hcl
environment = [
  {
    name  = "GOOGLE_USER"
    value = "noreply@sankofagrid.com"
  },
  {
    name  = "GOOGLE_PASSWORD"
    value = "placeholder-password"
  }
]
```

**After (Secrets Manager - SECURE):**
```hcl
secrets = [
  {
    name      = "GOOGLE_USER"
    valueFrom = "arn:aws:secretsmanager:eu-west-1:904570587823:secret:event-planner/dev/google-credentials-y9gEoP:user::"
  },
  {
    name      = "GOOGLE_PASSWORD"
    valueFrom = "arn:aws:secretsmanager:eu-west-1:904570587823:secret:event-planner/dev/google-credentials-y9gEoP:password::"
  }
]
```

### 3. Updated Service Configuration

**Dev Environment Task Limits:**
- Auth Service: desired=1, min=1, max=1
- Notification Service: desired=1, min=1, max=1

## Security Benefits

✅ **No Hardcoded Credentials:** Sensitive data removed from Terraform code  
✅ **Encrypted at Rest:** Secrets Manager encrypts data using AWS KMS  
✅ **Encrypted in Transit:** ECS retrieves secrets over TLS  
✅ **Access Control:** IAM policies control who can read secrets  
✅ **Audit Trail:** CloudTrail logs all secret access  
✅ **Rotation Support:** Secrets can be rotated without code changes  
✅ **Version Control Safe:** No credentials in Git history

## IAM Permissions

The ECS task execution role already has permissions to read secrets:

```json
{
  "Effect": "Allow",
  "Action": ["secretsmanager:GetSecretValue"],
  "Resource": "arn:aws:secretsmanager:*:*:secret:event-planner/*/google-credentials-*"
}
```

## Update Actual Credentials

### Option 1: AWS Console
1. Go to AWS Secrets Manager
2. Find secret: `event-planner/dev/google-credentials`
3. Click "Retrieve secret value"
4. Click "Edit"
5. Update the `password` field with actual Google App Password
6. Save

### Option 2: AWS CLI
```bash
export AWS_PROFILE=gtp-cletus

# Update the secret with actual password
aws secretsmanager put-secret-value \
  --secret-id event-planner/dev/google-credentials \
  --secret-string '{"user":"noreply@sankofagrid.com","password":"ACTUAL_GOOGLE_APP_PASSWORD"}' \
  --region eu-west-1
```

### Option 3: Terraform (Not Recommended for Passwords)
Update `terraform/modules/secrets-manager/main.tf` and run `terraform apply`.

## Generate Google App Password

1. Go to Google Account: https://myaccount.google.com/
2. Navigate to Security → 2-Step Verification
3. Scroll to "App passwords"
4. Generate new app password for "Mail"
5. Copy the 16-character password
6. Update the secret using Option 1 or 2 above

## Verification

After updating the secret, restart the notification service:

```bash
export AWS_PROFILE=gtp-cletus

# Force new deployment to pick up updated secret
aws ecs update-service \
  --cluster event-planner-dev-cluster \
  --service notification-service \
  --force-new-deployment \
  --region eu-west-1

# Monitor deployment
aws ecs describe-services \
  --cluster event-planner-dev-cluster \
  --services notification-service \
  --region eu-west-1 \
  --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount,Events:events[0:3]}'

# Check logs
aws logs tail /ecs/event-planner/dev/notification-service \
  --since 5m \
  --region eu-west-1 \
  --follow
```

## Deployment Status

✅ **Secrets Manager:** Google credentials secret created  
✅ **ECS Task Definition:** Updated to use Secrets Manager (revision 6)  
✅ **Notification Service:** Deployed with secure secret references  
✅ **Auth Service:** Running with 1 task  
✅ **Task Limits:** Set to 1 task per service in dev

## Files Modified

1. `terraform/modules/secrets-manager/main.tf` - Added Google credentials secret
2. `terraform/modules/secrets-manager/outputs.tf` - Added secret ARN output
3. `terraform/modules/ecs/main.tf` - Updated to use secrets instead of environment variables
4. `terraform/modules/ecs/variables.tf` - Added google_credentials_secret_arn variable
5. `terraform/environments/dev/main.tf` - Passed secret ARN to ECS module

## Next Steps

1. **Update Google Password:** Replace placeholder with actual Google App Password
2. **Test Email Functionality:** Verify notification service can send emails
3. **Monitor Logs:** Check for any authentication errors
4. **Document Password Rotation:** Set up process for rotating credentials

---

**Security Note:** Never commit actual passwords to Git. Always use Secrets Manager or similar secure storage for sensitive data.

**Applied:** October 29, 2025  
**Terraform Version:** 1.5.0+  
**AWS Account:** 904570587823
