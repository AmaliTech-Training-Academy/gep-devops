# S3 Upload Issue - Fix Summary

## Problem
User file uploads from frontend are failing with error:
```
File Upload Failed, please try again later
```

## Root Cause
Auth service is configured to use the **assets bucket** instead of the **backend files bucket** for user uploads.

**Current Configuration:**
```
AWS_S3_BUCKET = event-planner-dev-assets-904570587823  ❌ Wrong bucket
```

**Should be:**
```
AWS_S3_BACKEND_FILES_BUCKET = event-planner-backend-dev-files-904570587823  ✅ Correct bucket
```

## Solution Applied

### 1. ✅ IAM Permissions (Already Configured)
All services already have S3 permissions for both buckets:
- Auth Service ✅
- Event Service ✅
- Payment Service ✅
- Notification Service ✅

Permissions granted:
```json
{
  "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
  "Resource": [
    "arn:aws:s3:::event-planner-dev-assets-904570587823/*",
    "arn:aws:s3:::event-planner-backend-dev-files-904570587823/*"
  ]
}
```

### 2. ✅ S3 Bucket Configuration (Already Configured)
Backend files bucket has:
- ✅ CORS enabled for frontend origins
- ✅ Lifecycle rules configured
- ✅ Public access blocked (secure)
- ✅ Encryption enabled

### 3. ✅ Terraform Code Updated
Added new environment variable to ECS task definitions:

**File:** `terraform/modules/ecs/main.tf`
```hcl
{
  name  = "AWS_S3_BACKEND_FILES_BUCKET"
  value = var.s3_backend_files_bucket_name
}
```

**File:** `terraform/modules/ecs/variables.tf`
```hcl
variable "s3_backend_files_bucket_name" {
  description = "Name of the S3 bucket for backend user file uploads"
  type        = string
}
```

**File:** `terraform/environments/dev/main.tf`
```hcl
module "ecs" {
  # ... other config ...
  s3_bucket_name               = module.s3.assets_bucket_id
  s3_backend_files_bucket_name = module.s3.backend_files_bucket_id
}
```

## Next Steps

### Apply Terraform Changes
```bash
cd terraform/environments/dev
export AWS_PROFILE=gtp-cletus
terraform apply
```

This will:
1. Update ECS task definitions with new environment variable
2. Force new deployment of all services
3. Services will restart with correct bucket configuration

### Backend Code Update Required
The auth service code needs to use the new environment variable:

**Current (Wrong):**
```java
@Value("${AWS_S3_BUCKET}")
private String s3Bucket;  // Points to assets bucket
```

**Should be (Correct):**
```java
@Value("${AWS_S3_BACKEND_FILES_BUCKET}")
private String s3BackendFilesBucket;  // Points to backend files bucket
```

Or use both:
```java
@Value("${AWS_S3_BUCKET}")
private String s3AssetsBucket;  // For static assets

@Value("${AWS_S3_BACKEND_FILES_BUCKET}")
private String s3BackendFilesBucket;  // For user uploads
```

## Bucket Usage Guide

### Assets Bucket (event-planner-dev-assets-904570587823)
**Purpose:** Static frontend files served via CloudFront
- Angular application files
- Static images, CSS, JS
- Public read access via CloudFront OAC
- **DO NOT use for user uploads**

### Backend Files Bucket (event-planner-backend-dev-files-904570587823)
**Purpose:** User-uploaded files (private)
- User profile pictures
- Event images
- Document uploads
- Access via presigned URLs only
- **USE THIS for user uploads**

## Environment Variables After Fix

All services will have:
```bash
AWS_S3_BUCKET=event-planner-dev-assets-904570587823                    # Static assets
AWS_S3_BACKEND_FILES_BUCKET=event-planner-backend-dev-files-904570587823  # User uploads
```

## Verification Steps

After applying Terraform changes:

1. **Check ECS task definition:**
```bash
aws ecs describe-task-definition \
  --task-definition event-planner-dev-auth-service \
  --region eu-west-1 \
  --query 'taskDefinition.containerDefinitions[0].environment[?name==`AWS_S3_BACKEND_FILES_BUCKET`]'
```

2. **Check service logs:**
```bash
aws logs tail /ecs/event-planner/dev/auth-service --follow
```

3. **Test upload from frontend:**
- Upload a profile picture
- Check CloudWatch logs for success
- Verify file appears in backend files bucket

4. **Verify file in S3:**
```bash
aws s3 ls s3://event-planner-backend-dev-files-904570587823/images/ --recursive
```

## Cost Impact
No additional cost - using existing infrastructure.

## Security Notes
- ✅ Backend files bucket is private (no public access)
- ✅ Access via presigned URLs only
- ✅ CORS configured for authorized origins only
- ✅ All services have least-privilege IAM permissions

---

**Status:** Code updated, ready to apply
**Action Required:** Run `terraform apply` to deploy changes
