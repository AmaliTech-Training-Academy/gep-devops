#!/bin/bash
# ==============================================================================
# CloudFront + S3 Verification Script
# ==============================================================================
# This script verifies that CloudFront can properly access S3 bucket
# ==============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "CloudFront + S3 Verification"
echo "=========================================="
echo ""

# Change to terraform directory
cd "$(dirname "$0")/../terraform/environments/dev"

# Get outputs
echo -e "${YELLOW}Fetching Terraform outputs...${NC}"
BUCKET_NAME=$(terraform output -raw assets_bucket_id 2>/dev/null || echo "")
CLOUDFRONT_DOMAIN=$(terraform output -raw cloudfront_domain_name 2>/dev/null || echo "")
DISTRIBUTION_ID=$(terraform output -raw cloudfront_distribution_id 2>/dev/null || echo "")

if [ -z "$BUCKET_NAME" ] || [ -z "$CLOUDFRONT_DOMAIN" ] || [ -z "$DISTRIBUTION_ID" ]; then
    echo -e "${RED}❌ Failed to get Terraform outputs. Run 'terraform apply' first.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Bucket: $BUCKET_NAME${NC}"
echo -e "${GREEN}✓ CloudFront: $CLOUDFRONT_DOMAIN${NC}"
echo -e "${GREEN}✓ Distribution ID: $DISTRIBUTION_ID${NC}"
echo ""

# Check S3 bucket exists
echo -e "${YELLOW}Checking S3 bucket...${NC}"
if aws s3 ls "s3://$BUCKET_NAME" >/dev/null 2>&1; then
    echo -e "${GREEN}✓ S3 bucket exists${NC}"
else
    echo -e "${RED}❌ S3 bucket not found${NC}"
    exit 1
fi

# Check bucket policy
echo -e "${YELLOW}Checking S3 bucket policy...${NC}"
POLICY=$(aws s3api get-bucket-policy --bucket "$BUCKET_NAME" --query Policy --output text 2>/dev/null || echo "")
if [ -z "$POLICY" ]; then
    echo -e "${RED}❌ No bucket policy found${NC}"
    exit 1
fi

if echo "$POLICY" | grep -q "cloudfront.amazonaws.com"; then
    echo -e "${GREEN}✓ Bucket policy allows CloudFront${NC}"
else
    echo -e "${RED}❌ Bucket policy doesn't allow CloudFront${NC}"
    exit 1
fi

# Check files in bucket
echo -e "${YELLOW}Checking files in S3 bucket...${NC}"
FILE_COUNT=$(aws s3 ls "s3://$BUCKET_NAME" --recursive | wc -l)
if [ "$FILE_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ Found $FILE_COUNT files in bucket${NC}"
    echo "Files:"
    aws s3 ls "s3://$BUCKET_NAME" --recursive | head -10
else
    echo -e "${YELLOW}⚠ No files found in bucket. Upload your frontend files.${NC}"
fi
echo ""

# Check CloudFront distribution status
echo -e "${YELLOW}Checking CloudFront distribution status...${NC}"
STATUS=$(aws cloudfront get-distribution --id "$DISTRIBUTION_ID" --query 'Distribution.Status' --output text 2>/dev/null || echo "")
if [ "$STATUS" = "Deployed" ]; then
    echo -e "${GREEN}✓ CloudFront distribution is deployed${NC}"
else
    echo -e "${YELLOW}⚠ CloudFront distribution status: $STATUS (may take 15-20 minutes)${NC}"
fi

# Test CloudFront access
echo -e "${YELLOW}Testing CloudFront access...${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "https://$CLOUDFRONT_DOMAIN/" 2>/dev/null || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✓ CloudFront returns HTTP 200${NC}"
elif [ "$HTTP_CODE" = "403" ]; then
    echo -e "${RED}❌ CloudFront returns HTTP 403 (Access Denied)${NC}"
    echo "   This usually means:"
    echo "   1. No index.html file in S3 bucket"
    echo "   2. Bucket policy not applied yet"
    echo "   3. CloudFront cache needs invalidation"
elif [ "$HTTP_CODE" = "404" ]; then
    echo -e "${YELLOW}⚠ CloudFront returns HTTP 404 (Not Found)${NC}"
    echo "   Upload index.html to S3 bucket"
else
    echo -e "${RED}❌ CloudFront returns HTTP $HTTP_CODE${NC}"
fi
echo ""

# Summary
echo "=========================================="
echo "Summary"
echo "=========================================="
echo "CloudFront URL: https://$CLOUDFRONT_DOMAIN"
echo ""

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}✅ Everything is working correctly!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Deploy your frontend application"
    echo "2. Configure custom domain (optional)"
    echo "3. Set up monitoring and alarms"
elif [ "$FILE_COUNT" -eq 0 ]; then
    echo -e "${YELLOW}⚠ Upload your frontend files to S3:${NC}"
    echo ""
    echo "  cd your-frontend-app"
    echo "  npm run build"
    echo "  aws s3 sync dist/ s3://$BUCKET_NAME/ --delete"
    echo "  aws cloudfront create-invalidation --distribution-id $DISTRIBUTION_ID --paths '/*'"
else
    echo -e "${RED}❌ Issues detected. Check the logs above.${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "1. Run: terraform apply (to update bucket policy)"
    echo "2. Wait 5 minutes for changes to propagate"
    echo "3. Create CloudFront invalidation:"
    echo "   aws cloudfront create-invalidation --distribution-id $DISTRIBUTION_ID --paths '/*'"
fi

echo ""
