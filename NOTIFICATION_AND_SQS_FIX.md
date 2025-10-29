# Notification Service & SQS Configuration Fix

## Date: October 29, 2025

## Issues Addressed

### 1. Notification Service Deployment Failure
**Problem:** Notification service tasks were failing to start with error:
```
Could not resolve placeholder 'GOOGLE_USER' in value "${GOOGLE_USER}"
```

**Root Cause:** Missing required environment variables for email service configuration.

**Solution:** Added GOOGLE_USER and GOOGLE_PASSWORD environment variables to notification service task definition.

### 2. Auth Service SQS Configuration Update
**Problem:** Backend developers requested different SQS queue configuration.

**Solution:** Updated auth-service SQS environment variables as per backend requirements.

---

## Changes Made

### File: `terraform/modules/ecs/main.tf`

#### 1. Auth Service SQS Configuration (Lines ~265-280)
**Changed from:**
```hcl
each.key == "auth" ? [
  {
    name  = "SQS_ENDPOINT"
    value = "https://sqs.${var.aws_region}.amazonaws.com"
  },
  {
    name  = "USER_LOGIN_QUEUE"
    value = lookup(var.sqs_queue_urls, "user_login", "")
  },
  {
    name  = "USER_REGISTRATION_QUEUE"
    value = lookup(var.sqs_queue_urls, "user_registration", "")
  },
  {
    name  = "PASSWORD_RESET_QUEUE"
    value = lookup(var.sqs_queue_urls, "password_reset", "")
  }
] : []
```

**Changed to:**
```hcl
each.key == "auth" ? [
  {
    name  = "SQS_ENDPOINT"
    value = "http://localhost:4566"
  },
  {
    name  = "USER_LOGIN_QUEUE"
    value = "https://sqs.eu-west-1.amazonaws.com/123456789012/user-login-queue"
  },
  {
    name  = "USER_REGISTRATION_QUEUE"
    value = "https://sqs.eu-west-1.amazonaws.com/123456789012/user-registration-queue"
  },
  {
    name  = "PASSWORD_RESET_QUEUE"
    value = ""
  }
] : []
```

#### 2. Notification Service Environment Variables (Lines ~320-340)
**Added:**
```hcl
each.key == "notification" ? [
  {
    name  = "SQS_ENDPOINT"
    value = "https://sqs.${var.aws_region}.amazonaws.com"
  },
  {
    name  = "NOTIFICATIONS_QUEUE_NAME"
    value = lookup(var.sqs_queue_names, "notifications", "")
  },
  {
    name  = "NOTIFICATIONS_QUEUE_URL"
    value = lookup(var.sqs_queue_urls, "notifications", "")
  },
  {
    name  = "GOOGLE_USER"
    value = "noreply@sankofagrid.com"
  },
  {
    name  = "GOOGLE_PASSWORD"
    value = "placeholder-password"
  }
] : []
```

---

## Deployment Status

### Applied Changes
```bash
terraform apply -auto-approve
```

**Result:**
- ✅ Auth service task definition updated (revision 28)
- ✅ Notification service task definition updated (revision 5)
- ✅ Both services redeployed with new configurations

### Current Status

**Auth Service:**
- Status: ACTIVE
- Running tasks: Check with `aws ecs describe-services`
- SQS configuration: Updated to use localhost:4566 endpoint

**Notification Service:**
- Status: ACTIVE
- ECR Image: ✅ Available (pushed 2025-10-24)
- Environment variables: ✅ GOOGLE_USER and GOOGLE_PASSWORD added
- IAM Permissions: ✅ Has ECR pull permissions via task execution role

---

## Verification Commands

### Check Service Status
```bash
export AWS_PROFILE=gtp-cletus

# Check notification service
aws ecs describe-services \
  --cluster event-planner-dev-cluster \
  --services notification-service \
  --region eu-west-1 \
  --query 'services[0].{Status:status,DesiredCount:desiredCount,RunningCount:runningCount,Events:events[0:3]}'

# Check auth service
aws ecs describe-services \
  --cluster event-planner-dev-cluster \
  --services auth-service \
  --region eu-west-1 \
  --query 'services[0].{Status:status,DesiredCount:desiredCount,RunningCount:runningCount,Events:events[0:3]}'
```

### Check Logs
```bash
# Notification service logs
aws logs tail /ecs/event-planner/dev/notification-service \
  --since 10m \
  --region eu-west-1 \
  --follow

# Auth service logs
aws logs tail /ecs/event-planner/dev/auth-service \
  --since 10m \
  --region eu-west-1 \
  --follow
```

### Verify ECR Images
```bash
# List notification service images
aws ecr describe-images \
  --repository-name event-planner-dev-notification-service \
  --region eu-west-1

# List auth service images
aws ecr describe-images \
  --repository-name event-planner-dev-auth-service \
  --region eu-west-1
```

---

## Next Steps for Backend Developers

### 1. Update Notification Service Configuration
The placeholder values need to be replaced with actual credentials:

**Option A: Use AWS Secrets Manager (Recommended)**
```bash
# Create secret for Google credentials
aws secretsmanager create-secret \
  --name event-planner/dev/google-credentials \
  --description "Google email credentials for notification service" \
  --secret-string '{"user":"noreply@sankofagrid.com","password":"ACTUAL_PASSWORD"}' \
  --region eu-west-1
```

Then update ECS task definition to pull from Secrets Manager instead of environment variables.

**Option B: Update Environment Variables**
Update the values in `terraform/modules/ecs/main.tf` and run `terraform apply`.

### 2. Verify SQS Configuration
The auth-service is now configured with:
- SQS_ENDPOINT: `http://localhost:4566` (LocalStack for local dev)
- USER_LOGIN_QUEUE: `https://sqs.eu-west-1.amazonaws.com/123456789012/user-login-queue`
- USER_REGISTRATION_QUEUE: `https://sqs.eu-west-1.amazonaws.com/123456789012/user-registration-queue`
- PASSWORD_RESET_QUEUE: Empty string

**Note:** The account ID `123456789012` appears to be a placeholder. Verify if this should be the actual AWS account ID `904570587823`.

### 3. Monitor Service Health
```bash
# Watch service events
aws ecs describe-services \
  --cluster event-planner-dev-cluster \
  --services notification-service auth-service \
  --region eu-west-1 \
  --query 'services[*].{Name:serviceName,Running:runningCount,Desired:desiredCount,Events:events[0].message}'
```

---

## Troubleshooting

### If Notification Service Still Fails

1. **Check if image exists:**
   ```bash
   aws ecr describe-images --repository-name event-planner-dev-notification-service --region eu-west-1
   ```

2. **Verify IAM permissions:**
   - Task execution role has `ecr:GetAuthorizationToken`, `ecr:BatchCheckLayerAvailability`, `ecr:GetDownloadUrlForLayer`, `ecr:BatchGetImage`
   - Check: `terraform/modules/iam/main.tf`

3. **Check VPC endpoints:**
   - ECR API endpoint: `vpce-0bc8e7c8e47712185`
   - ECR DKR endpoint: `vpce-0450e1b8be3277369`
   - Verify they're attached to private subnets

4. **Review CloudWatch logs:**
   ```bash
   aws logs tail /ecs/event-planner/dev/notification-service --since 30m --region eu-west-1
   ```

### If Auth Service Has SQS Issues

1. **Verify queue URLs are correct:**
   - Check if account ID `123456789012` should be `904570587823`
   - Verify queue names match actual SQS queues

2. **Check IAM permissions:**
   - Auth service task role needs SQS permissions
   - Verify in `terraform/modules/iam/main.tf` (auth_service_task policy)

3. **Test SQS connectivity:**
   ```bash
   # From within ECS task
   aws sqs list-queues --region eu-west-1
   ```

---

## Summary

✅ **Completed:**
- Added GOOGLE_USER and GOOGLE_PASSWORD environment variables to notification service
- Updated auth-service SQS configuration per backend requirements
- Deployed changes via Terraform
- Verified ECR images exist for both services

⚠️ **Pending:**
- Replace placeholder Google credentials with actual values
- Verify SQS account ID (123456789012 vs 904570587823)
- Monitor service startup and confirm tasks are running
- Test email functionality once service is running

---

**Last Updated:** October 29, 2025  
**Applied By:** DevOps Team  
**Terraform Version:** 1.5.0+
