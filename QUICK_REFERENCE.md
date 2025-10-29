# Quick Reference Guide

## Notification Service

### Endpoints
```
Health Check: https://api.sankofagrid.com/api/v1/notifications/actuator/health
Internal DNS: http://notification-service.eventplanner.local:8085
```

### SQS Queue
```
Notifications Queue: event-planner-dev-notifications-queue
Notifications DLQ: event-planner-dev-notifications-queue-dlq
```

**Note**: Single queue handles all notification types (email, OTP, SMS) with message type routing in application code.

### Environment Variables
```
NOTIFICATION_SERVICE_URL=http://notification-service.eventplanner.local:8085
NOTIFICATIONS_QUEUE_NAME=event-planner-dev-notifications-queue
NOTIFICATIONS_QUEUE_URL=https://sqs.eu-west-1.amazonaws.com/...
SQS_ENDPOINT=https://sqs.eu-west-1.amazonaws.com
```

---

## Dashboards

### CloudWatch Dashboard URLs
```
Auth Service: 
https://console.aws.amazon.com/cloudwatch/home?region=eu-west-1#dashboards:name=event-planner-dev-auth-service

Notification Service:
https://console.aws.amazon.com/cloudwatch/home?region=eu-west-1#dashboards:name=event-planner-dev-notification-service

Frontend:
https://console.aws.amazon.com/cloudwatch/home?region=eu-west-1#dashboards:name=event-planner-dev-frontend
```

---

## Retention Periods (All 3 Days)

| Resource | Previous | Current | Savings |
|----------|----------|---------|---------|
| VPC Flow Logs | 7 days | 3 days | 57% |
| RDS Backups | 7 days | 3 days | 57% |
| ElastiCache Snapshots | 5 snapshots | 3 snapshots | 40% |
| ECS Logs | 7 days | 3 days | 57% |
| CloudWatch Logs | 30 days | 3 days | 90% |
| S3 Logs | 90 days | 3 days | 97% |
| S3 Backups | 365 days | 3 days | 99% |
| SQS Messages | 4 days | 3 days | 25% |
| SQS DLQ | 14 days | 3 days | 79% |

---

## Common Commands

### Check Notification Service Status
```bash
aws ecs describe-services \
  --cluster event-planner-dev-cluster \
  --services notification-service \
  --region eu-west-1
```

### View Service Logs
```bash
aws logs tail /ecs/event-planner/dev/notification-service \
  --follow \
  --region eu-west-1
```

### Check Queue Depth
```bash
aws sqs get-queue-attributes \
  --queue-url $(aws sqs get-queue-url --queue-name event-planner-dev-notifications-queue --query 'QueueUrl' --output text) \
  --attribute-names ApproximateNumberOfMessages \
  --region eu-west-1
```

### Check DLQ Messages
```bash
aws sqs get-queue-attributes \
  --queue-url $(aws sqs get-queue-url --queue-name event-planner-dev-notifications-queue-dlq --query 'QueueUrl' --output text) \
  --attribute-names ApproximateNumberOfMessages \
  --region eu-west-1
```

### Send Test Messages to Queue
```bash
# Test email notification
aws sqs send-message \
  --queue-url $(aws sqs get-queue-url --queue-name event-planner-dev-notifications-queue --query 'QueueUrl' --output text) \
  --message-body '{"type":"email","recipient":"test@example.com","subject":"Test"}' \
  --message-attributes '{"event_type":{"DataType":"String","StringValue":"notification.email"}}' \
  --region eu-west-1

# Test OTP notification
aws sqs send-message \
  --queue-url $(aws sqs get-queue-url --queue-name event-planner-dev-notifications-queue --query 'QueueUrl' --output text) \
  --message-body '{"type":"otp","phone":"+1234567890","code":"123456"}' \
  --message-attributes '{"event_type":{"DataType":"String","StringValue":"notification.otp"}}' \
  --region eu-west-1
```

### Scale Notification Service
```bash
# Scale up
aws ecs update-service \
  --cluster event-planner-dev-cluster \
  --service notification-service \
  --desired-count 2 \
  --region eu-west-1

# Scale down
aws ecs update-service \
  --cluster event-planner-dev-cluster \
  --service notification-service \
  --desired-count 0 \
  --region eu-west-1
```

---

## Tags Reference

### Global Tags (All Resources)
```hcl
Project     = "event-planner"
Environment = "dev"
ManagedBy   = "Terraform"
Repository  = "get-devops"
Team        = "DevOps"
CostCenter  = "Engineering"
Compliance  = "Standard"
Backup      = "Daily"
Monitoring  = "Enabled"
```

### Service-Specific Tags
```hcl
# IAM Roles
Service   = "notification-service"
Component = "task-role"
Purpose   = "service-permissions"

# SQS/SNS
Service   = "messaging"
Component = "sqs"
Purpose   = "event-processing"
Retention = "3-days"
```

---

## Troubleshooting

### Notification Service Not Starting
```bash
# Check task definition
aws ecs describe-task-definition \
  --task-definition event-planner-dev-notification-service \
  --region eu-west-1

# Check stopped tasks
aws ecs list-tasks \
  --cluster event-planner-dev-cluster \
  --desired-status STOPPED \
  --region eu-west-1

# View task logs
aws logs get-log-events \
  --log-group-name /ecs/event-planner/dev/notification-service \
  --log-stream-name <stream-name> \
  --region eu-west-1
```

### Messages Stuck in Queue
```bash
# Check queue attributes
aws sqs get-queue-attributes \
  --queue-url <QUEUE_URL> \
  --attribute-names All \
  --region eu-west-1

# Purge queue (if needed)
aws sqs purge-queue \
  --queue-url <QUEUE_URL> \
  --region eu-west-1
```

### High DLQ Message Count
```bash
# Receive messages from DLQ
aws sqs receive-message \
  --queue-url <DLQ_URL> \
  --max-number-of-messages 10 \
  --region eu-west-1

# Redrive messages back to main queue (manual)
# 1. Receive from DLQ
# 2. Send to main queue
# 3. Delete from DLQ
```

---

## Cost Monitoring

### View Current Month Costs
```bash
aws ce get-cost-and-usage \
  --time-period Start=2025-01-01,End=2025-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=TAG,Key=Environment \
  --region us-east-1
```

### View Service-Specific Costs
```bash
aws ce get-cost-and-usage \
  --time-period Start=2025-01-01,End=2025-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=TAG,Key=Service \
  --filter file://cost-filter.json \
  --region us-east-1
```

---

## Deployment Checklist

- [ ] Run `terraform plan` and review changes
- [ ] Verify no unexpected resource deletions
- [ ] Check estimated cost impact
- [ ] Backup current state file
- [ ] Run `terraform apply`
- [ ] Verify notification service is running
- [ ] Check all queues are created
- [ ] Verify IAM permissions
- [ ] Test service health endpoint
- [ ] View dashboards in CloudWatch
- [ ] Monitor for 1 hour
- [ ] Send test notification
- [ ] Verify email delivery
- [ ] Test OTP generation
- [ ] Check DLQ is empty
- [ ] Update documentation
- [ ] Notify team

---

## Emergency Contacts

- **DevOps Team**: devops@sankofagrid.com
- **On-Call**: [Slack Channel]
- **AWS Support**: [Support Case Link]

---

## Useful Links

- [Terraform Docs](https://www.terraform.io/docs)
- [AWS ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- [AWS SQS Developer Guide](https://docs.aws.amazon.com/sqs/)
- [AWS SES Developer Guide](https://docs.aws.amazon.com/ses/)
- [CloudWatch Dashboards](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch_Dashboards.html)

---

**Last Updated**: January 2025
