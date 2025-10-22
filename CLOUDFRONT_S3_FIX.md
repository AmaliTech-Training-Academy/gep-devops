# CloudFront + S3 Access Denied Fix

## Problem
CloudFront distribution was returning "Access Denied" when accessing files from S3 bucket.

## Root Cause
The S3 bucket policy that grants CloudFront access was never created because:
1. `cloudfront_distribution_arn` was passed as empty string `""` to S3 module
2. The bucket policy had a conditional `count = var.cloudfront_distribution_arn != "" ? 1 : 0`
3. This meant CloudFront had no permission to read from S3

## Fixes Applied

### 1. **Fixed Circular Dependency** (`terraform/environments/dev/main.tf`)
```hcl
# BEFORE
cloudfront_distribution_arn = "" # Will update after CloudFront

# AFTER
cloudfront_distribution_arn = module.cloudfront.distribution_arn
```

### 2. **Removed Conditional Bucket Policy** (`terraform/modules/s3/main.tf`)
```hcl
# BEFORE
resource "aws_s3_bucket_policy" "assets" {
  count = var.cloudfront_distribution_arn != "" ? 1 : 0
  # ...
}

# AFTER
resource "aws_s3_bucket_policy" "assets" {
  # Always create the policy
  bucket = aws_s3_bucket.assets.id
  # ...
}
```

### 3. **Improved URL Rewrite Function** (`terraform/modules/cloudfront/main.tf`)
Fixed the CloudFront function to properly handle SPA routing:
- Checks for file extensions using regex
- Handles trailing slashes
- Serves index.html for routes without extensions

### 4. **Fixed Function Association**
Changed from nullable to dynamic block to avoid Terraform errors.

## How It Works Now

```
User Request → CloudFront Distribution
                    ↓
            Origin Access Control (OAC)
                    ↓
            S3 Bucket Policy (allows cloudfront.amazonaws.com)
                    ↓
            S3 Bucket (assets)
                    ↓
            Return File to CloudFront → User
```

### S3 Bucket Policy (Auto-Created)
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
          "AWS:SourceArn": "arn:aws:cloudfront::*:distribution/*"
        }
      }
    }
  ]
}
```

## Deployment Steps

### Step 1: Apply Terraform Changes
```bash
cd terraform/environments/dev
terraform plan
terraform apply
```

This will:
1. Update the S3 bucket policy with CloudFront ARN
2. Update the CloudFront function
3. Invalidate CloudFront cache (if needed)

### Step 2: Verify S3 Bucket Policy
```bash
aws s3api get-bucket-policy \
  --bucket event-planner-dev-assets-<account-id> \
  --query Policy --output text | jq
```

You should see the CloudFront service principal with your distribution ARN.

### Step 3: Test CloudFront Access
```bash
# Get your CloudFront domain
CLOUDFRONT_DOMAIN=$(terraform output -raw cloudfront_domain_name)

# Test access
curl -I https://${CLOUDFRONT_DOMAIN}/index.html
```

Expected response: `HTTP/2 200`

### Step 4: Upload Test Files (if needed)
```bash
# Upload a test file
aws s3 cp index.html s3://event-planner-dev-assets-<account-id>/

# Verify it's there
aws s3 ls s3://event-planner-dev-assets-<account-id>/
```

### Step 5: Invalidate CloudFront Cache
```bash
DISTRIBUTION_ID=$(terraform output -raw cloudfront_distribution_id)

aws cloudfront create-invalidation \
  --distribution-id ${DISTRIBUTION_ID} \
  --paths "/*"
```

## Verification Checklist

- [ ] S3 bucket has files uploaded
- [ ] S3 bucket policy includes CloudFront ARN
- [ ] S3 bucket has public access blocked (security)
- [ ] CloudFront distribution is deployed
- [ ] CloudFront can access S3 via OAC
- [ ] Browser can access CloudFront URL
- [ ] SPA routing works (e.g., /events, /login redirect to index.html)

## Troubleshooting

### Still Getting Access Denied?

1. **Check S3 Bucket Policy**
   ```bash
   aws s3api get-bucket-policy --bucket event-planner-dev-assets-<account-id>
   ```
   Verify CloudFront ARN is present.

2. **Check CloudFront Origin Settings**
   ```bash
   aws cloudfront get-distribution --id <distribution-id>
   ```
   Verify Origin Access Control is configured.

3. **Check S3 Files Exist**
   ```bash
   aws s3 ls s3://event-planner-dev-assets-<account-id>/ --recursive
   ```

4. **Check CloudFront Cache**
   Create an invalidation to clear cache:
   ```bash
   aws cloudfront create-invalidation \
     --distribution-id <distribution-id> \
     --paths "/*"
   ```

5. **Check Browser Console**
   - Open Developer Tools → Network tab
   - Look for 403 errors
   - Check response headers for clues

### Common Issues

**Issue**: "The bucket does not allow ACLs"
- **Solution**: Already fixed - we're using OAC (Origin Access Control), not OAI

**Issue**: "Access Denied" from S3
- **Solution**: Bucket policy now automatically created with CloudFront ARN

**Issue**: "NoSuchKey" error
- **Solution**: Upload files to S3 bucket or check file paths

**Issue**: Routes return 404
- **Solution**: CloudFront function now properly rewrites URLs for SPA

## Security Notes

✅ **Properly Configured:**
- S3 bucket has public access blocked
- CloudFront uses Origin Access Control (OAC) - modern approach
- Only CloudFront can access S3 (via service principal)
- HTTPS enforced (redirect-to-https)
- Security headers configured
- CORS properly configured

## Next Steps

1. **Deploy Frontend Application**
   ```bash
   # Build Angular app
   cd frontend
   npm run build

   # Upload to S3
   aws s3 sync dist/ s3://event-planner-dev-assets-<account-id>/ --delete

   # Invalidate CloudFront
   aws cloudfront create-invalidation \
     --distribution-id <distribution-id> \
     --paths "/*"
   ```

2. **Configure Custom Domain** (Optional)
   - Request ACM certificate
   - Update CloudFront with certificate ARN
   - Add Route53 records

3. **Monitor Access**
   - Check CloudFront access logs in S3
   - Monitor CloudWatch metrics
   - Set up alarms for errors

---

**Last Updated**: January 2025
**Status**: ✅ Fixed and Ready for Deployment
