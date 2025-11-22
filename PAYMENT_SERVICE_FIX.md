# Payment Service Rollback Fix

## Root Cause Analysis

The payment service container rolled back due to a **Spring Boot dependency injection failure** in the `messagePublisherImpl` bean, which prevented the application from starting.

### Error Chain
```
messagePublisherImpl (failed to autowire)
  ↓
transactionServiceImpl (constructor parameter 3)
  ↓
paymentController (constructor parameter 1)
  ↓
Application startup failed
  ↓
ECS health checks failed
  ↓
Automatic rollback triggered
```

### Why It Failed
The `messagePublisherImpl` bean requires SNS configuration to publish payment events, but the following were missing:
1. SNS endpoint URL environment variable
2. SNS topic ARN environment variables (PAYMENT_TOPIC_ARN, EVENT_TOPIC_ARN)
3. SNS topic ARNs not passed from sqs-sns module to ECS module

## Changes Made

### 1. ECS Module - Task Definition (terraform/modules/ecs/main.tf)
**Added SNS configuration for payment service:**
```hcl
{
  name  = "SNS_ENDPOINT"
  value = "https://sns.${var.aws_region}.amazonaws.com"
},
{
  name  = "PAYMENT_TOPIC_ARN"
  value = lookup(var.sns_topic_arns, "payment", "")
},
{
  name  = "EVENT_TOPIC_ARN"
  value = lookup(var.sns_topic_arns, "event", "")
}
```

**Added SNS configuration for notification service:**
```hcl
{
  name  = "SNS_ENDPOINT"
  value = "https://sns.${var.aws_region}.amazonaws.com"
}
```

### 2. ECS Module Variables (terraform/modules/ecs/variables.tf)
**Added new variable:**
```hcl
variable "sns_topic_arns" {
  description = "Map of SNS topic ARNs for event publishing"
  type        = map(string)
  default     = {}
}
```

### 3. Dev Environment (terraform/environments/dev/main.tf)
**Passed SNS topic ARNs to ECS module:**
```hcl
module "ecs" {
  # ... existing config ...
  sns_topic_arns  = module.sqs-sns.topic_arns
  # ... rest of config ...
}
```

### 4. IAM Module - Notification Service (terraform/modules/iam/main.tf)
**Removed excessive SQS permissions (security improvement):**
- Removed: `sqs:CreateQueue`, `sqs:PurgeQueue`, `sqs:SetQueueAttributes`, `sqs:ListQueues`
- Kept only necessary permissions: `SendMessage`, `ReceiveMessage`, `DeleteMessage`, `GetQueueAttributes`, `GetQueueUrl`, `ChangeMessageVisibility`

## Verification Checklist

After applying these changes:

- [ ] Run `terraform plan` to verify changes
- [ ] Run `terraform apply` to deploy updates
- [ ] Wait for ECS service to update (5-10 minutes)
- [ ] Check payment service logs: `/ecs/event-planner/dev/payment-service`
- [ ] Verify application starts successfully
- [ ] Check health endpoint: `https://api.sankofagrid.com/api/v1/payments/actuator/health`
- [ ] Verify no rollback occurs
- [ ] Test payment flow end-to-end

## Expected Behavior After Fix

1. Payment service container starts successfully
2. `messagePublisherImpl` bean initializes with SNS configuration
3. Health checks pass at `/actuator/health`
4. ECS deployment completes without rollback
5. Payment service can publish events to SNS topics

## Deployment Commands

```bash
# Navigate to dev environment
cd terraform/environments/dev

# Review changes
terraform plan

# Apply changes
terraform apply

# Monitor deployment
aws ecs describe-services \
  --cluster event-planner-dev-cluster \
  --services payment-service \
  --query 'services[0].deployments'

# Check logs
aws logs tail /ecs/event-planner/dev/payment-service --follow
```

## Rollback Plan (if needed)

If issues persist:
```bash
# Revert to previous task definition
aws ecs update-service \
  --cluster event-planner-dev-cluster \
  --service payment-service \
  --task-definition event-planner-dev-payment-service:39
```

## Additional Notes

- Payment service IAM role already has SNS publish permissions ✓
- SNS topics (event, payment) already exist in sqs-sns module ✓
- Only missing piece was environment variable configuration ✓
- Notification service also benefits from SNS endpoint configuration ✓
- Security improved by removing unnecessary SQS permissions ✓
