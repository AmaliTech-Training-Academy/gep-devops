#!/bin/bash
set -e

echo "================================================"
echo "Applying CloudFront S3 Access Fix"
echo "================================================"
echo ""

cd terraform/environments/dev

echo "Step 1: Applying Terraform changes..."
echo "This will create the S3 bucket policy"
echo ""

terraform apply -auto-approve

echo ""
echo "Step 2: Uploading test file to S3..."
BUCKET=$(terraform output -raw assets_bucket_id)
echo "Bucket: $BUCKET"

cat > /tmp/test-index.html << 'EOF'
<!DOCTYPE html>
<html>
<head><title>CloudFront Test</title></head>
<body>
<h1>✅ Success! CloudFront is working!</h1>
<p>If you see this, CloudFront can access S3.</p>
</body>
</html>
EOF

aws s3 cp /tmp/test-index.html s3://$BUCKET/index.html
echo "✓ Uploaded index.html"

echo ""
echo "Step 3: Invalidating CloudFront cache..."
DIST_ID=$(terraform output -raw cloudfront_distribution_id)
CLOUDFRONT_URL=$(terraform output -raw cloudfront_domain_name)

aws cloudfront create-invalidation \
    --distribution-id "$DIST_ID" \
    --paths "/*" \
    --no-cli-pager

echo ""
echo "================================================"
echo "✅ Fix Applied!"
echo "================================================"
echo ""
echo "CloudFront URL: https://$CLOUDFRONT_URL"
echo ""
echo "Wait 2-3 minutes, then test:"
echo "  curl -I https://$CLOUDFRONT_URL"
echo ""
echo "Or open in browser:"
echo "  https://$CLOUDFRONT_URL"
echo ""
