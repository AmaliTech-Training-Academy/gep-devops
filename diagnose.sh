#!/bin/bash

echo "=== CloudFront Access Denied Diagnostic ==="
echo ""

cd terraform/environments/dev

echo "1. Checking if bucket policy exists in Terraform state..."
if terraform state list 2>/dev/null | grep -q "aws_s3_bucket_policy.cloudfront_access"; then
    echo "   ✅ Bucket policy EXISTS in Terraform state"
else
    echo "   ❌ Bucket policy DOES NOT EXIST in Terraform state"
    echo "   → You need to run: terraform apply"
    echo ""
    echo "Run this command:"
    echo "   cd terraform/environments/dev && terraform apply"
    exit 1
fi

echo ""
echo "2. Checking if bucket policy exists in main.tf..."
if grep -q "aws_s3_bucket_policy.cloudfront_access" main.tf; then
    echo "   ✅ Bucket policy code EXISTS in main.tf"
else
    echo "   ❌ Bucket policy code MISSING from main.tf"
    exit 1
fi

echo ""
echo "3. Getting CloudFront and S3 details..."
BUCKET=$(terraform output -raw assets_bucket_id 2>/dev/null)
CLOUDFRONT=$(terraform output -raw cloudfront_domain_name 2>/dev/null)
DIST_ID=$(terraform output -raw cloudfront_distribution_id 2>/dev/null)

echo "   Bucket: $BUCKET"
echo "   CloudFront: $CLOUDFRONT"
echo "   Distribution ID: $DIST_ID"

echo ""
echo "=== DIAGNOSIS ==="
echo "The bucket policy code exists in main.tf but hasn't been applied to AWS yet."
echo ""
echo "FIX: Run terraform apply"
echo ""
echo "Commands to run:"
echo "  cd terraform/environments/dev"
echo "  terraform apply -auto-approve"
echo ""
