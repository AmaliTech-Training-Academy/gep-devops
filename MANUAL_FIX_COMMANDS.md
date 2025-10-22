# Manual Fix Commands - Run These Exactly

## The Issue
Your S3 bucket policy doesn't exist yet. You need to apply the Terraform changes I made.

## Commands to Run (Copy & Paste)

### 1. Apply Terraform Changes
```bash
cd /home/cletusmangu/Desktop/get-devops/terraform/environments/dev
terraform apply -auto-approve
```

This creates the S3 bucket policy that allows CloudFront to access S3.

### 2. Upload a Test File
```bash
# Get bucket name
BUCKET=$(terraform output -raw assets_bucket_id)

# Create test file
cat > /tmp/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head><title>Test</title></head>
<body><h1>✅ CloudFront Works!</h1></body>
</html>
EOF

# Upload to S3
aws s3 cp /tmp/index.html s3://$BUCKET/index.html
```

### 3. Invalidate CloudFront Cache
```bash
# Get distribution ID
DIST_ID=$(terraform output -raw cloudfront_distribution_id)

# Create invalidation
aws cloudfront create-invalidation \
    --distribution-id "$DIST_ID" \
    --paths "/*"
```

### 4. Wait and Test
```bash
# Wait 2 minutes
echo "Waiting 2 minutes for changes to propagate..."
sleep 120

# Test
CLOUDFRONT_URL=$(terraform output -raw cloudfront_domain_name)
curl -I https://$CLOUDFRONT_URL

# Should show: HTTP/2 200
```

## What Each Command Does

1. **terraform apply** - Creates the S3 bucket policy with CloudFront ARN
2. **aws s3 cp** - Uploads index.html so there's something to serve
3. **aws cloudfront create-invalidation** - Clears CloudFront cache
4. **curl** - Tests if it works

## Expected Output

After step 4, you should see:
```
HTTP/2 200
content-type: text/html
...
```

If you still see `403 Access Denied`, wait another 2 minutes and try again.

## Verify Bucket Policy Was Created

```bash
cd /home/cletusmangu/Desktop/get-devops/terraform/environments/dev

# Check if policy exists
BUCKET=$(terraform output -raw assets_bucket_id)
aws s3api get-bucket-policy --bucket "$BUCKET" --query Policy --output text | jq

# You should see cloudfront.amazonaws.com in the output
```

## If It Still Doesn't Work

Run this diagnostic:
```bash
cd /home/cletusmangu/Desktop/get-devops/terraform/environments/dev

echo "=== Checking S3 Bucket ==="
BUCKET=$(terraform output -raw assets_bucket_id)
echo "Bucket: $BUCKET"
aws s3 ls s3://$BUCKET/

echo ""
echo "=== Checking Bucket Policy ==="
aws s3api get-bucket-policy --bucket "$BUCKET" 2>&1 | grep -q "cloudfront" && echo "✅ Policy exists" || echo "❌ Policy missing"

echo ""
echo "=== Checking CloudFront ==="
DIST_ID=$(terraform output -raw cloudfront_distribution_id)
echo "Distribution: $DIST_ID"
aws cloudfront get-distribution --id "$DIST_ID" --query 'Distribution.Status' --output text

echo ""
echo "=== Testing Access ==="
CLOUDFRONT_URL=$(terraform output -raw cloudfront_domain_name)
curl -I https://$CLOUDFRONT_URL 2>&1 | head -1
```
