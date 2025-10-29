# Notification Service Fix - October 29, 2025

## Issue Identified

**Error:** `Could not resolve placeholder 'PASSWORD_RESET_QUEUE_NAME' in value "${PASSWORD_RESET_QUEUE_NAME}"`

**Root Cause:** The notification service requires `PASSWORD_RESET_QUEUE_NAME` and `PASSWORD_RESET_QUEUE_URL` environment variables to listen to the password reset SQS queue, but they were not configured in the ECS task definition.

## Fixes Applied

### 1. ✅ Google Credentials Updated in Secrets Manager
```bash
Secret: event-planner/dev/google-credentials
User: noreply.event.planner.amalitech@gmail.com
Password: vsvaczkvogxczmhl (actual Google App Password)
```

### 2. ✅ Health Checks Enabled
Container health check is properly configured:
```json
{
  "command": ["CMD-SHELL", "curl -f http://localhost:8085/actuator/health || exit 1"],
  "interval": 30,
  "timeout": 5,
  "retries": 3,
  "startPeriod": 60
}
```

### 3. ✅ Secrets Manager Integration
Google credentials are fetched from Secrets Manager:
```json
{
  "name": "GOOGLE_USER",
  "valueFrom": "arn:aws:secretsmanager:eu-west-1:904570587823:secret:event-planner/dev/google-credentials-y9gEoP:user::"
},
{
  "name": "GOOGLE_PASSWORD",
  "valueFrom": "arn:aws:secretsmanager:eu-west-1:904570587823:secret:event-planner/dev/google-credentials-y9gEoP:password::"
}
```

### 4. 🔧 Missing Environment Variables Added

**Added to notification service:**
- `PASSWORD_RESET_QUEUE_NAME` - Queue name for password reset notifications
- `PASSWORD_RESET_QUEUE_URL` - Full SQS queue URL for password reset

**Updated ECS Module:** `terraform/modules/ecs/main.tf`

## Complete Notification Service Configuration

### Environment Variables:
```
SQS_ENDPOINT=https://sqs.eu-west-1.amazonaws.com
NOTIFICATIONS_QUEUE_NAME=event-planner-dev-notifications-queue
NOTIFICATIONS_QUEUE_URL=https://sqs.eu-west-1.amazonaws.com/904570587823/event-planner-dev-notifications-queue
PASSWORD_RESET_QUEUE_NAME=event-planner-dev-password-reset-queue
PASSWORD_RESET_QUEUE_URL=https://sqs.eu-west-1.amazonaws.com/904570587823/event-planner-dev-password-reset-queue
```

### Secrets (from Secrets Manager):
```
GOOGLE_USER=noreply.event.planner.amalitech@gmail.com
GOOGLE_PASSWORD=vsvaczkvogxczmhl
SPRING_CLOUD_AWS_CREDENTIALS_ACCESS_KEY=(from aws-credentials secret)
SPRING_CLOUD_AWS_CREDENTIALS_SECRET_KEY=(from aws-credentials secret)
```

## SQS Queues Available

1. **notifications** - Main notifications queue
   - URL: `https://sqs.eu-west-1.amazonaws.com/904570587823/event-planner-dev-notifications-queue`
   - Name: `event-planner-dev-notifications-queue`

2. **password_reset** - Password reset notifications
   - URL: `https://sqs.eu-west-1.amazonaws.com/904570587823/event-planner-dev-password-reset-queue`
   - Name: `event-planner-dev-password-reset-queue`

3. **user_login** - User login events
   - URL: `https://sqs.eu-west-1.amazonaws.com/904570587823/event-planner-dev-user-login-queue`
   - Name: `event-planner-dev-user-login-queue`

4. **user_registration** - User registration events
   - URL: `https://sqs.eu-west-1.amazonaws.com/904570587823/event-planner-dev-user-registration-queue`
   - Name: `event-planner-dev-user-registration-queue`

5. **event_created_notification** - Event creation notifications
   - URL: `https://sqs.eu-west-1.amazonaws.com/904570587823/event-planner-dev-event-created-notification-queue`
   - Name: `event-planner-dev-event-created-notification-queue`

## IAM Permissions

### Task Execution Role
✅ Has permissions to:
- Read from Secrets Manager (`secretsmanager:GetSecretValue`)
- Pull images from ECR
- Write logs to CloudWatch

### Task Role (notification-service)
✅ Has permissions to:
- Send emails via SES (`ses:SendEmail`, `ses:SendRawEmail`, `ses:SendTemplatedEmail`)
- Publish to SNS (`sns:Publish`)
- Access SQS queues (`sqs:SendMessage`, `sqs:ReceiveMessage`, `sqs:DeleteMessage`, `sqs:GetQueueAttributes`)
- Write logs to CloudWatch

## Next Steps

### Apply Terraform Changes
```bash
cd terraform/environments/dev
export AWS_PROFILE=gtp-cletus
terraform apply
```

### Verify Deployment
```bash
# Check service status
aws ecs describe-services \
  --cluster event-planner-dev-cluster \
  --services notification-service \
  --region eu-west-1 \
  --profile gtp-cletus

# Monitor logs
aws logs tail /ecs/event-planner/dev/notification-service \
  --since 5m \
  --region eu-west-1 \
  --profile gtp-cletus \
  --follow
```

### Test Email Functionality
Once the service is running, test email sending:
```bash
# Send a test message to the notifications queue
aws sqs send-message \
  --queue-url https://sqs.eu-west-1.amazonaws.com/904570587823/event-planner-dev-notifications-queue \
  --message-body '{"type":"test","email":"test@example.com","subject":"Test","body":"Test email"}' \
  --region eu-west-1 \
  --profile gtp-cletus
```

## Summary

✅ **Google Credentials:** Updated with actual values in Secrets Manager  
✅ **Health Checks:** Enabled and configured  
✅ **Secrets Integration:** Properly configured to fetch from Secrets Manager  
✅ **SQS Queues:** All queues created and accessible  
✅ **IAM Permissions:** Task execution and task roles have correct permissions  
🔧 **Missing Variables:** Added PASSWORD_RESET_QUEUE_NAME and PASSWORD_RESET_QUEUE_URL  

**Status:** Ready to deploy after applying Terraform changes

---

**Last Updated:** October 29, 2025  
**Issue:** Missing PASSWORD_RESET_QUEUE_NAME environment variable  
**Resolution:** Added missing SQS queue environment variables to notification service
