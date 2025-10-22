# CloudFront Access Denied - Status Check

## Quick Diagnosis

Run these commands to see what's wrong:

### 1. Find your S3 bucket
```bash
aws s3 ls | grep event-planner | grep assets
```

### 2. Check if bucket policy exists
```bash
# Replace BUCKET_NAME with output from step 1
aws s3api get-bucket-policy --bucket BUCKET_NAME
```

**Expected:** Should show a policy with `cloudfront.amazonaws.com`  
**If error "NoSuchBucketPolicy":** Policy doesn't exist - THIS IS YOUR PROBLEM

### 3. Check if files exist in S3
```bash
aws s3 ls s3://BUCKET_NAME/
```

**Expected:** Should show `index.html` or other files  
**If empty:** No files to serve - upload something

### 4. Check CloudFront distribution
```bash
aws cloudfront list-distributions --query "DistributionList.Items[?contains(DomainName, 'd2atd3vdxzjhxk')].[Id,Status,Origins.Items[0].DomainName]" --output table
```

**Expected:** Status should be "Deployed"

## The Root Cause

Based on your error, one of these is true:

1. **Bucket policy doesn't exist** (most likely)
   - Solution: Run commands in FINAL_FIX_COMMANDS.txt

2. **No files in S3 bucket**
   - Solution: Upload index.html

3. **CloudFront cache has old "Access Denied" response**
   - Solution: Create invalidation

## Fastest Fix

Copy and paste this entire block (replace YOUR_BUCKET_NAME):

```bash
# Set your bucket name
BUCKET_NAME="event-planner-dev-assets-YOUR_ACCOUNT_ID"

# Get CloudFront info
DIST_ID=$(aws cloudfront list-distributions --query "DistributionList.Items[?contains(DomainName, 'd2atd3vdxzjhxk')].Id" --output text)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
CLOUDFRONT_ARN="arn:aws:cloudfront::${ACCOUNT_ID}:distribution/${DIST_ID}"

# Create and apply bucket policy
cat > /tmp/policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "AllowCloudFront",
    "Effect": "Allow",
    "Principal": {"Service": "cloudfront.amazonaws.com"},
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::${BUCKET_NAME}/*",
    "Condition": {
      "StringEquals": {"AWS:SourceArn": "${CLOUDFRONT_ARN}"}
    }
  }]
}
EOF

aws s3api put-bucket-policy --bucket "$BUCKET_NAME" --policy file:///tmp/policy.json

# Upload test file
echo '<html><body><h1>Success!</h1></body></html>' > /tmp/index.html
aws s3 cp /tmp/index.html s3://$BUCKET_NAME/index.html

# Invalidate cache
aws cloudfront create-invalidation --distribution-id "$DIST_ID" --paths "/*"

# Wait and test
sleep 120
curl -I https://d2atd3vdxzjhxk.cloudfront.net
```

## Why Terraform Didn't Work

The `aws_s3_bucket_policy.cloudfront_access` resource in your main.tf might not have been applied because:

1. Terraform apply didn't actually run
2. There was an error during apply that was ignored
3. The resource has a dependency issue
4. AWS profile wasn't configured correctly

The manual AWS CLI commands bypass Terraform and directly fix the issue.
