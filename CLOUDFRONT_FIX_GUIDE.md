# CloudFront Access Denied - Complete Fix Guide

## Problem
Your CloudFront distribution at `https://d2atd3vdxzjhxk.cloudfront.net` returns:
```xml
<Error>
  <Code>AccessDenied</Code>
  <Message>Access Denied</Message>
</Error>
```

## Root Cause
The S3 bucket policy that grants CloudFront permission to read files was never created due to a **circular dependency**:
- S3 module needs CloudFront ARN for bucket policy
- CloudFront module needs S3 bucket to exist first
- Result: Bucket policy was never created ❌

## Solution Applied

### Changes Made

1. **Removed bucket policy from S3 module** (`terraform/modules/s3/main.tf`)
   - The policy was conditional and never created

2. **Created bucket policy in main.tf** (`terraform/environments/dev/main.tf`)
   - Policy is now created AFTER both S3 and CloudFront exist
   - Uses `depends_on` to ensure proper order

3. **Fixed CloudFront function** (`terraform/modules/cloudfront/main.tf`)
   - Improved URL rewriting for SPA routing

## How to Fix (Step-by-Step)

### Option 1: Automated Fix (Recommended)

```bash
cd /home/cletusmangu/Desktop/get-devops

# Run the fix script
chmod +x FIX_CLOUDFRONT_ACCESS.sh
./FIX_CLOUDFRONT_ACCESS.sh
```

This script will:
1. Apply Terraform changes
2. Create the S3 bucket policy with CloudFront ARN
3. Invalidate CloudFront cache
4. Show you the next steps

### Option 2: Manual Fix

#### Step 1: Apply Terraform Changes
```bash
cd terraform/environments/dev
terraform plan
terraform apply
```

You should see:
```
# aws_s3_bucket_policy.cloudfront_access will be created
+ resource "aws_s3_bucket_policy" "cloudfront_access" {
    + bucket = "event-planner-dev-assets-..."
    + policy = jsonencode(...)
  }
```

#### Step 2: Verify Bucket Policy
```bash
# Get bucket name
BUCKET=$(terraform output -raw assets_bucket_id)

# Check policy
aws s3api get-bucket-policy --bucket "$BUCKET" --query Policy --output text | jq
```

You should see:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowCloudFrontServicePrincipal",
      "Effect": "Allow",
      "Principal": {
        "Service": "cloudfront.amazonaws.com"
      },
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::event-planner-dev-assets-*/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceArn": "arn:aws:cloudfront::...:distribution/..."
        }
      }
    }
  ]
}
```

#### Step 3: Upload Test File
```bash
# Upload test file
aws s3 cp test-index.html s3://$BUCKET/index.html

# Verify upload
aws s3 ls s3://$BUCKET/
```

#### Step 4: Invalidate CloudFront Cache
```bash
# Get distribution ID
DIST_ID=$(terraform output -raw cloudfront_distribution_id)

# Create invalidation
aws cloudfront create-invalidation \
    --distribution-id "$DIST_ID" \
    --paths "/*"
```

#### Step 5: Test Access
```bash
# Wait 2-3 minutes, then test
CLOUDFRONT_URL=$(terraform output -raw cloudfront_domain_name)
curl -I https://$CLOUDFRONT_URL

# Should return: HTTP/2 200
```

## Verification

### Check 1: S3 Bucket Policy Exists
```bash
cd terraform/environments/dev
BUCKET=$(terraform output -raw assets_bucket_id)
aws s3api get-bucket-policy --bucket "$BUCKET" 2>&1 | grep -q "cloudfront.amazonaws.com" && echo "✅ Policy exists" || echo "❌ Policy missing"
```

### Check 2: Files in S3
```bash
aws s3 ls s3://$BUCKET/ --recursive
```

### Check 3: CloudFront Access
```bash
CLOUDFRONT_URL=$(terraform output -raw cloudfront_domain_name)
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" https://$CLOUDFRONT_URL)

if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ CloudFront working (HTTP 200)"
elif [ "$HTTP_CODE" = "403" ]; then
    echo "❌ Still Access Denied (HTTP 403)"
    echo "   Wait 2-3 minutes and try again"
elif [ "$HTTP_CODE" = "404" ]; then
    echo "⚠️  Not Found (HTTP 404)"
    echo "   Upload index.html to S3"
else
    echo "❌ Unexpected response: HTTP $HTTP_CODE"
fi
```

### Check 4: CloudFront Distribution Status
```bash
DIST_ID=$(terraform output -raw cloudfront_distribution_id)
aws cloudfront get-distribution --id "$DIST_ID" --query 'Distribution.Status' --output text
# Should show: Deployed
```

## Troubleshooting

### Issue: Still Getting 403 After Apply

**Possible Causes:**
1. CloudFront cache hasn't been invalidated
2. Changes haven't propagated (takes 2-5 minutes)
3. No files in S3 bucket

**Solutions:**
```bash
# 1. Force invalidation
DIST_ID=$(terraform output -raw cloudfront_distribution_id)
aws cloudfront create-invalidation --distribution-id "$DIST_ID" --paths "/*"

# 2. Wait 5 minutes
sleep 300

# 3. Upload test file
BUCKET=$(terraform output -raw assets_bucket_id)
aws s3 cp test-index.html s3://$BUCKET/index.html

# 4. Test again
CLOUDFRONT_URL=$(terraform output -raw cloudfront_domain_name)
curl -I https://$CLOUDFRONT_URL
```

### Issue: Terraform Apply Fails

**Error:** "Error putting S3 policy: AccessDenied"

**Solution:**
```bash
# Check your AWS credentials have s3:PutBucketPolicy permission
aws sts get-caller-identity

# If using wrong profile, set correct one
export AWS_PROFILE=your-profile-name
```

### Issue: 404 Not Found

**Cause:** No index.html file in S3 bucket

**Solution:**
```bash
# Upload test file
BUCKET=$(terraform output -raw assets_bucket_id)
aws s3 cp test-index.html s3://$BUCKET/index.html

# Or upload your actual frontend
cd your-frontend-app
npm run build
aws s3 sync dist/ s3://$BUCKET/ --delete
```

### Issue: Changes Not Reflecting

**Cause:** CloudFront cache

**Solution:**
```bash
# Create invalidation and wait
DIST_ID=$(terraform output -raw cloudfront_distribution_id)
aws cloudfront create-invalidation --distribution-id "$DIST_ID" --paths "/*"

# Check invalidation status
aws cloudfront list-invalidations --distribution-id "$DIST_ID"

# Wait for status: Completed (takes 1-5 minutes)
```

## Architecture (After Fix)

```
┌─────────────┐
│   Browser   │
└──────┬──────┘
       │ HTTPS
       ▼
┌─────────────────────────────────┐
│   CloudFront Distribution       │
│   (d2atd3vdxzjhxk.cloudfront.net)│
└──────┬──────────────────────────┘
       │ Origin Access Control (OAC)
       │ Service Principal: cloudfront.amazonaws.com
       ▼
┌─────────────────────────────────┐
│   S3 Bucket Policy              │
│   ✅ Allows cloudfront.amazonaws.com│
│   ✅ Condition: SourceArn matches│
└──────┬──────────────────────────┘
       │
       ▼
┌─────────────────────────────────┐
│   S3 Bucket (Assets)            │
│   event-planner-dev-assets-*    │
│   🔒 Public Access: BLOCKED     │
│   📁 Files: index.html, etc.    │
└─────────────────────────────────┘
```

## What Changed in Code

### Before (Broken)
```hcl
# In terraform/modules/s3/main.tf
resource "aws_s3_bucket_policy" "assets" {
  count = var.cloudfront_distribution_arn != "" ? 1 : 0  # ❌ Never created
  # ...
}

# In terraform/environments/dev/main.tf
module "s3" {
  cloudfront_distribution_arn = ""  # ❌ Empty string
}
```

### After (Fixed)
```hcl
# In terraform/modules/s3/main.tf
# Bucket policy removed from module

# In terraform/environments/dev/main.tf
resource "aws_s3_bucket_policy" "cloudfront_access" {
  bucket = module.s3.assets_bucket_id
  policy = jsonencode({
    # ... allows cloudfront.amazonaws.com
    Condition = {
      StringEquals = {
        "AWS:SourceArn" = module.cloudfront.distribution_arn  # ✅ Real ARN
      }
    }
  })
  depends_on = [module.cloudfront, module.s3]  # ✅ Proper order
}
```

## Next Steps

1. **Deploy Your Frontend**
   ```bash
   cd your-angular-app
   npm run build
   
   BUCKET=$(cd terraform/environments/dev && terraform output -raw assets_bucket_id)
   aws s3 sync dist/ s3://$BUCKET/ --delete
   
   DIST_ID=$(cd terraform/environments/dev && terraform output -raw cloudfront_distribution_id)
   aws cloudfront create-invalidation --distribution-id "$DIST_ID" --paths "/*"
   ```

2. **Set Up Custom Domain** (Optional)
   - Request ACM certificate for your domain
   - Update CloudFront with certificate ARN
   - Add Route53 CNAME record

3. **Monitor Access**
   - Check CloudFront access logs in S3
   - Set up CloudWatch alarms
   - Monitor 4xx/5xx errors

## Success Criteria

✅ Terraform apply creates `aws_s3_bucket_policy.cloudfront_access`  
✅ S3 bucket policy contains CloudFront ARN  
✅ Files uploaded to S3 bucket  
✅ CloudFront returns HTTP 200  
✅ Browser shows your application  

---

**Status**: Ready to apply  
**Estimated Time**: 5-10 minutes  
**Risk**: Low (only adds bucket policy)
