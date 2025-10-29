# AWS Credentials Setup for ECS Services

## Overview
This document explains how AWS credentials are securely stored in AWS Secrets Manager and accessed by ECS services without hardcoding in Terraform.

## Secret Created
- **Secret Name**: `event-planner/dev/aws-credentials`
- **Secret ARN**: `arn:aws:secretsmanager:eu-west-1:904570587823:secret:event-planner/dev/aws-credentials-krdwSY`
- **Region**: `eu-west-1`

## Step 1: Update Secret with Your Actual Credentials

Run this command with your actual AWS access key and secret key:

```bash
aws secretsmanager put-secret-value \
  --secret-id event-planner/dev/aws-credentials \
  --secret-string '{"access_key":"YOUR_ACTUAL_ACCESS_KEY","secret_key":"YOUR_ACTUAL_SECRET_KEY"}' \
  --region eu-west-1 \
  --profile gtp-cletus
```

**Replace**:
- `YOUR_ACTUAL_ACCESS_KEY` with your AWS access key
- `YOUR_ACTUAL_SECRET_KEY` with your AWS secret key

## Step 2: Apply Terraform Changes

```bash
cd /home/cletusmangu/Desktop/get-devops/terraform/environments/dev
terraform init -reconfigure
terraform apply
```

## What Was Changed

### 1. ECS Task Definition (`terraform/modules/ecs/main.tf`)
Added AWS credentials as secrets that ECS will inject at runtime:

```hcl
secrets = concat(
  # AWS Credentials from Secrets Manager
  var.aws_credentials_secret_arn != null ? [
    {
      name      = "SPRING_CLOUD_AWS_CREDENTIALS_ACCESS_KEY"
      valueFrom = "${var.aws_credentials_secret_arn}:access_key::"
    },
    {
      name      = "SPRING_CLOUD_AWS_CREDENTIALS_SECRET_KEY"
      valueFrom = "${var.aws_credentials_secret_arn}:secret_key::"
    }
  ] : [],
  # ... other secrets
)
```

Also added environment variables to configure Spring Cloud AWS:

```hcl
{
  name  = "SPRING_CLOUD_AWS_CREDENTIALS_INSTANCE_PROFILE"
  value = "true"
},
{
  name  = "SPRING_CLOUD_AWS_REGION_STATIC"
  value = var.aws_region
}
```

### 2. ECS Module Variables (`terraform/modules/ecs/variables.tf`)
Added new variable:

```hcl
variable "aws_credentials_secret_arn" {
  description = "ARN of AWS credentials secret in Secrets Manager"
  type        = string
  default     = null
}
```

### 3. Environment Configuration (`terraform/environments/dev/main.tf`)
Passed the secret ARN to the ECS module:

```hcl
module "ecs" {
  # ... other configuration
  aws_credentials_secret_arn = "arn:aws:secretsmanager:eu-west-1:904570587823:secret:event-planner/dev/aws-credentials-krdwSY"
}
```

### 4. IAM Execution Role (`terraform/modules/iam/main.tf`)
Updated the execution role to allow reading the AWS credentials secret:

```hcl
Resource = concat(
  var.db_secrets_arns,
  var.jwt_secret_arn != null ? [var.jwt_secret_arn] : [],
  ["arn:aws:secretsmanager:*:*:secret:event-planner/*/aws-credentials-*"]
)
```

## How It Works

1. **Secret Storage**: AWS credentials are stored in Secrets Manager (encrypted at rest)
2. **IAM Permissions**: ECS Task Execution Role has permission to read the secret
3. **Runtime Injection**: When ECS starts a container, it retrieves the secret and injects it as environment variables
4. **Application Access**: Spring Boot application reads `SPRING_CLOUD_AWS_CREDENTIALS_ACCESS_KEY` and `SPRING_CLOUD_AWS_CREDENTIALS_SECRET_KEY`

## Security Benefits

✅ **No Hardcoding**: Credentials never appear in Terraform code or version control  
✅ **Encryption**: Secrets are encrypted at rest in Secrets Manager  
✅ **Least Privilege**: Only ECS execution role can read the secret  
✅ **Audit Trail**: All secret access is logged in CloudTrail  
✅ **Rotation**: Credentials can be rotated without code changes  

## Verify Secret

```bash
# View secret (without revealing value)
aws secretsmanager describe-secret \
  --secret-id event-planner/dev/aws-credentials \
  --region eu-west-1 \
  --profile gtp-cletus

# Get secret value (reveals credentials - use carefully)
aws secretsmanager get-secret-value \
  --secret-id event-planner/dev/aws-credentials \
  --region eu-west-1 \
  --profile gtp-cletus
```

## Rotate Credentials

To rotate credentials:

```bash
aws secretsmanager put-secret-value \
  --secret-id event-planner/dev/aws-credentials \
  --secret-string '{"access_key":"NEW_ACCESS_KEY","secret_key":"NEW_SECRET_KEY"}' \
  --region eu-west-1 \
  --profile gtp-cletus
```

Then restart ECS services to pick up new credentials:

```bash
aws ecs update-service \
  --cluster event-planner-dev-cluster \
  --service auth-service \
  --force-new-deployment \
  --region eu-west-1 \
  --profile gtp-cletus
```

## Troubleshooting

### Service Still Failing?

1. **Verify secret exists**:
   ```bash
   aws secretsmanager get-secret-value \
     --secret-id event-planner/dev/aws-credentials \
     --region eu-west-1 \
     --profile gtp-cletus
   ```

2. **Check IAM permissions**:
   ```bash
   aws iam get-role-policy \
     --role-name event-planner-dev-ecs-execution-* \
     --policy-name secrets-access-* \
     --profile gtp-cletus
   ```

3. **View ECS task logs**:
   ```bash
   aws logs tail /ecs/event-planner/dev/auth-service \
     --follow \
     --region eu-west-1 \
     --profile gtp-cletus
   ```

## Next Steps

After updating the secret and applying Terraform:

1. Force new deployment of auth-service
2. Monitor logs for successful startup
3. Verify application can access AWS services (SQS, SES, S3)

---

**Created**: 2025-01-28  
**Last Updated**: 2025-01-28
