#!/bin/bash
set -e

echo "=========================================="
echo "Manual S3 Bucket Policy Fix"
echo "=========================================="
echo ""

cd terraform/environments/dev

# Get values from terraform
echo "Getting bucket and CloudFront details..."
BUCKET_NAME=$(terraform output -json | jq -r '.assets_bucket_id.value' 2>/dev/null)
CLOUDFRONT_ARN=$(terraform output -json | jq -r '.cloudfront_distribution_arn.value' 2>/dev/null)
CLOUDFRONT_URL=$(terraform output -json | jq -r '.cloudfront_domain_name.value' 2>/dev/null)

if [ -z "$BUCKET_NAME" ] || [ "$BUCKET_NAME" = "null" ]; then
    echo "❌ Cannot get bucket name from terraform"
    echo "Trying alternative method..."
    BUCKET_NAME=$(aws s3 ls | grep "event-planner.*assets" | awk '{print $3}' | head -1)
fi

if [ -z "$CLOUDFRONT_ARN" ] || [ "$CLOUDFRONT_ARN" = "null" ]; then
    echo "❌ Cannot get CloudFront ARN from terraform"
    echo "Getting from AWS..."
    DIST_ID=$(aws cloudfront list-distributions --query "DistributionList.Items[?Comment=='event-planner dev CDN'].Id" --output text 2>/dev/null | head -1)
    if [ -n "$DIST_ID" ]; then
        CLOUDFRONT_ARN="arn:aws:cloudfront::$(aws sts get-caller-identity --query Account --output text):distribution/$DIST_ID"
    fi
fi

echo "Bucket: $BUCKET_NAME"
echo "CloudFront ARN: $CLOUDFRONT_ARN"
echo ""

if [ -z "$BUCKET_NAME" ] || [ -z "$CLOUDFRONT_ARN" ]; then
    echo "❌ Missing required information"
    exit 1
fi

# Create bucket policy
echo "Creating S3 bucket policy..."
cat > /tmp/bucket-policy.json << EOF
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
      "Resource": "arn:aws:s3:::${BUCKET_NAME}/*",
      "Condition": {
        "StringEquals": {
          "AWS:SourceArn": "${CLOUDFRONT_ARN}"
        }
      }
    }
  ]
}
EOF

echo "Policy created:"
cat /tmp/bucket-policy.json
echo ""

echo "Applying policy to bucket..."
aws s3api put-bucket-policy --bucket "$BUCKET_NAME" --policy file:///tmp/bucket-policy.json

echo "✅ Bucket policy applied!"
echo ""

# Upload test file
echo "Uploading test file..."
cat > /tmp/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>CloudFront Test</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .container {
            text-align: center;
            padding: 40px;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>✅ Success!</h1>
        <p>CloudFront + S3 is working correctly</p>
    </div>
</body>
</html>
EOF

aws s3 cp /tmp/index.html s3://$BUCKET_NAME/index.html
echo "✅ Test file uploaded"
echo ""

# Invalidate CloudFront
echo "Invalidating CloudFront cache..."
DIST_ID=$(echo "$CLOUDFRONT_ARN" | awk -F'/' '{print $NF}')
aws cloudfront create-invalidation --distribution-id "$DIST_ID" --paths "/*" --no-cli-pager
echo "✅ Cache invalidated"
echo ""

echo "=========================================="
echo "✅ Fix Complete!"
echo "=========================================="
echo ""
echo "CloudFront URL: https://$CLOUDFRONT_URL"
echo ""
echo "Wait 2-3 minutes, then test:"
echo "  curl -I https://$CLOUDFRONT_URL"
echo ""
echo "Or open in browser:"
echo "  https://$CLOUDFRONT_URL"
echo ""
