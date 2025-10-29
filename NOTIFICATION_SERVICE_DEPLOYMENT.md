# Notification Service Deployment Issue

## Problem
Notification service has no running tasks because there's no Docker image in ECR.

## Solution

### 1. Backend developers need to build and push notification-service image:

```bash
# Get ECR login
aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin 904570587823.dkr.ecr.eu-west-1.amazonaws.com

# Build image
cd notification-service
docker build -t event-planner-dev-notification-service .

# Tag image
docker tag event-planner-dev-notification-service:latest 904570587823.dkr.ecr.eu-west-1.amazonaws.com/event-planner-dev-notification-service:latest

# Push to ECR
docker push 904570587823.dkr.ecr.eu-west-1.amazonaws.com/event-planner-dev-notification-service:latest
```

### 2. After image is pushed, ECS will automatically start the task

### 3. Verify deployment:
```bash
aws ecs describe-services \
  --cluster event-planner-dev-cluster \
  --services notification-service \
  --region eu-west-1
```

---

## SQS Environment Variables Updated

Changed from:
```
USER_REGISTRATION_QUEUE_NAME=...
USER_LOGIN_QUEUE_NAME=...
USER_REGISTRATION_QUEUE=https://...
USER_LOGIN_QUEUE=https://...
PASSWORD_RESET_QUEUE=https://...
```

To (as requested by backend developers):
```
SQS_ENDPOINT=https://sqs.eu-west-1.amazonaws.com
USER_LOGIN_QUEUE=https://sqs.eu-west-1.amazonaws.com/904570587823/event-planner-dev-user-login-queue
USER_REGISTRATION_QUEUE=https://sqs.eu-west-1.amazonaws.com/904570587823/event-planner-dev-user-registration-queue
PASSWORD_RESET_QUEUE=https://sqs.eu-west-1.amazonaws.com/904570587823/event-planner-dev-password-reset-queue
```

---

## Apply Changes

```bash
cd terraform/environments/dev
terraform apply
```

This will update the auth-service task definition with the correct SQS queue URLs.
