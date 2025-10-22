#!/bin/bash
# ==============================================================================
# Fix CloudFront Access Denied Issue
# ==============================================================================

set -e

echo "=========================================="
echo "Fixing CloudFront Access Denied Issue"
echo "=========================================="
echo ""

cd terraform/environments/dev

echo "Step 1: Applying Terraform changes..."
echo "This will create the S3 bucket policy with CloudFront ARN"
echo ""

terraform apply -auto-approve

echo ""
echo "Step 2: Getting CloudFront distribution ID..."
DISTRIBUTION_ID=$(terraform output -raw cloudfront_distribution_id 2>/dev/null)
CLOUDFRONT_URL=$(terraform output -raw cloudfront_domain_name 2>/dev/null)

if [ -z "$DISTRIBUTION_ID" ]; then
    echo "❌ Failed to get CloudFront distribution ID"
    exit 1
fi

echo "✓ Distribution ID: $DISTRIBUTION_ID"
echo "✓ CloudFront URL: https://$CLOUDFRONT_URL"
echo ""

echo "Step 3: Creating CloudFront invalidation..."
echo "This clears the cache so CloudFront uses the new bucket policy"
echo ""

aws cloudfront create-invalidation \
    --distribution-id "$DISTRIBUTION_ID" \
    --paths "/*" \
    --no-cli-pager

echo ""
echo "Step 4: Waiting for invalidation to complete (this may take 1-2 minutes)..."
sleep 10

echo ""
echo "=========================================="
echo "✅ Fix Applied Successfully!"
echo "=========================================="
echo ""
echo "CloudFront URL: https://$CLOUDFRONT_URL"
echo ""
echo "Next steps:"
echo "1. Wait 2-3 minutes for changes to propagate"
echo "2. Upload your frontend files:"
echo "   aws s3 sync dist/ s3://\$(terraform output -raw assets_bucket_id)/"
echo "3. Test access: curl -I https://$CLOUDFRONT_URL"
echo ""
