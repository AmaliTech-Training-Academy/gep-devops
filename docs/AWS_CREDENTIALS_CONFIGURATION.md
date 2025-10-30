# AWS Credentials Configuration

## Overview
This document explains how AWS credentials are configured for Terraform and ECS services.

## Terraform AWS Credentials

### Configuration Method: AWS CLI Profile
Terraform uses the **AWS CLI profile** named `gtp-cletus` for authentication.

**Location:** `terraform/environments/dev/main.tf`
```hcl
provider "aws" {
  region  = var.aws_region
  profile = "gtp-cletus"  # Uses credentials from ~/.aws/credentials
}
```

### How It Works
1. AWS credentials are stored in `~/.aws/credentials` under the `[gtp-cletus]` profile
2. Terraform reads credentials from this profile automatically
3. No credentials are hardcoded in Terraform files
4. No credentials are committed to Git

### Verify Your Profile
```bash
aws configure list --profile gtp-cletus
```

## ECS Services AWS Credentials

### Configuration Method: AWS Secrets Manager
ECS services (auth-service, notification-service, etc.) get AWS credentials from **AWS Secrets Manager** at runtime.

**Secret Name:** `event-planner/dev/aws-credentials`
**Secret ARN:** `arn:aws:secretsmanager:eu-west-1:904570587823:secret:event-planner/dev/aws-credentials-krdwSY`

### Secret Structure
```json
{
  "access_key": "AKIA...",
  "secret_key": "..."
}
```

### How ECS Services Access Credentials
**Location:** `terraform/modules/ecs/main.tf`
```hcl
secrets = [
  {
    name      = "SPRING_CLOUD_AWS_CREDENTIALS_ACCESS_KEY"
    valueFrom = "${var.aws_credentials_secret_arn}:access_key::"
  },
  {
    name      = "SPRING_CLOUD_AWS_CREDENTIALS_SECRET_KEY"
    valueFrom = "${var.aws_credentials_secret_arn}:secret_key::"
  }
]
```

### IAM Permissions
The ECS Task Execution Role has permissions to read from Secrets Manager:
- `secretsmanager:GetSecretValue`
- `secretsmanager:DescribeSecret`

## Security Best Practices

✅ **What We Do:**
- Use AWS CLI profiles for Terraform (no hardcoded credentials)
- Store service credentials in AWS Secrets Manager
- Mark sensitive variables as `sensitive = true`
- Never commit credentials to Git
- Use IAM roles for ECS tasks

❌ **What We Don't Do:**
- Hardcode credentials in Terraform files
- Store credentials in terraform.tfvars
- Commit credentials to version control
- Use environment variables for Terraform (profile is better)

## Troubleshooting

### Issue: Terraform asks for AWS credentials
**Solution:** Ensure AWS CLI profile is configured:
```bash
aws configure --profile gtp-cletus
```

### Issue: ECS tasks can't access AWS services
**Solution:** Verify:
1. Secret exists in Secrets Manager
2. ECS Task Execution Role has permissions
3. Secret ARN is correct in Terraform

### Issue: "Access Denied" errors
**Solution:** Check IAM permissions for:
- Terraform user/profile (for infrastructure deployment)
- ECS Task Execution Role (for pulling secrets)
- ECS Task Role (for service-specific permissions)

## Rotating Credentials

### Rotate Terraform Credentials
```bash
# Update AWS CLI profile
aws configure --profile gtp-cletus
```

### Rotate ECS Service Credentials
```bash
# Update secret in Secrets Manager
aws secretsmanager update-secret \
  --secret-id event-planner/dev/aws-credentials \
  --secret-string '{"access_key":"NEW_KEY","secret_key":"NEW_SECRET"}' \
  --profile gtp-cletus \
  --region eu-west-1

# Force ECS service redeployment to pick up new credentials
aws ecs update-service \
  --cluster event-planner-dev-cluster \
  --service auth-service \
  --force-new-deployment \
  --profile gtp-cletus \
  --region eu-west-1
```

## Summary

| Component | Credential Source | Storage Location |
|-----------|------------------|------------------|
| Terraform | AWS CLI Profile | `~/.aws/credentials` |
| ECS Services | Secrets Manager | `event-planner/dev/aws-credentials` |
| Backend (S3) | AWS CLI Profile | `~/.aws/credentials` |

**No credentials are hardcoded or exposed in Terraform code!** ✅
