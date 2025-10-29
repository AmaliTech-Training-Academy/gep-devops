# SQS Configuration Updated - October 29, 2025

## Summary

Updated auth-service SQS configuration from dummy local development values to actual AWS SQS queue URLs.

## Changes Applied

### Auth Service Environment Variables

**Before (Dummy Values):**
```
SQS_ENDPOINT: http://localhost:4566
USER_LOGIN_QUEUE: https://sqs.eu-west-1.amazonaws.com/123456789012/user-login-queue
USER_REGISTRATION_QUEUE: https://sqs.eu-west-1.amazonaws.com/123456789012/user-registration-queue
PASSWORD_RESET_QUEUE: (empty)
```

**After (Actual AWS Values):**
```
SQS_ENDPOINT: https://sqs.eu-west-1.amazonaws.com
USER_LOGIN_QUEUE: https://sqs.eu-west-1.amazonaws.com/904570587823/event-planner-dev-user-login-queue
USER_REGISTRATION_QUEUE: https://sqs.eu-west-1.amazonaws.com/904570587823/event-planner-dev-user-registration-queue
PASSWORD_RESET_QUEUE: https://sqs.eu-west-1.amazonaws.com/904570587823/event-planner-dev-password-reset-queue
```

## Deployment Status

✅ **Auth Service:**
- Status: ACTIVE
- Running tasks: 2
- Task definition: Revision 29
- SQS configuration: Updated with actual queue URLs

✅ **Notification Service:**
- Status: ACTIVE  
- Task definition: Revision 5
- Environment variables: GOOGLE_USER and GOOGLE_PASSWORD added
- Note: Needs actual Google credentials to start successfully

## Verification

```bash
export AWS_PROFILE=gtp-cletus

# Check services
aws ecs describe-services \
  --cluster event-planner-dev-cluster \
  --services auth-service notification-service \
  --region eu-west-1

# Verify SQS queues exist
aws sqs list-queues --region eu-west-1 --queue-name-prefix event-planner-dev
```

## Next Steps

1. **For Notification Service:** Replace placeholder Google credentials with actual values
2. **Test SQS Integration:** Verify auth-service can send/receive messages from queues
3. **Monitor Logs:** Check CloudWatch logs for any SQS-related errors

---
**Applied:** October 29, 2025  
**Terraform Version:** 1.5.0+  
**AWS Account:** 904570587823
