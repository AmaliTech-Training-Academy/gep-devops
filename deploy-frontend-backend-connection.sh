#!/bin/bash
# ==============================================================================
# Deploy Frontend-Backend Connection Configuration
# ==============================================================================
# This script applies the Terraform changes to connect your frontend 
# (CloudFront) to your backend (ALB) for the endpoint:
# https://api.sankofagrid.com/api
# ==============================================================================

set -e

echo "🚀 Deploying Frontend-Backend Connection Configuration..."
echo "=================================================="

# Navigate to dev environment
cd terraform/environments/dev

# Check if Terraform is initialized
if [ ! -d ".terraform" ]; then
    echo "❌ Terraform not initialized. Please run 'terraform init' first."
    exit 1
fi

# Plan the changes
echo "📋 Planning Terraform changes..."
terraform plan -out=frontend-backend-connection.tfplan

echo ""
echo "📝 Changes Summary:"
echo "- CloudFront ALB domain: api.sankofagrid.com"
echo "- CORS origins: events.sankofagrid.com, www.sankofagrid.com, localhost:4200"
echo "- CSP updated to allow API connections"
echo "- S3 CORS updated for direct access if needed"
echo ""

# Ask for confirmation
read -p "🤔 Do you want to apply these changes? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "✅ Applying changes..."
    terraform apply frontend-backend-connection.tfplan
    
    echo ""
    echo "🎉 Frontend-Backend Connection Deployed Successfully!"
    echo "=================================================="
    echo "Your frontend can now communicate with the backend using:"
    echo "API Endpoint: https://api.sankofagrid.com/api"
    echo ""
    echo "📊 Next Steps:"
    echo "1. Verify CloudFront distribution update (may take 5-15 minutes)"
    echo "2. Test API calls from your frontend"
    echo "3. Check CloudWatch logs for any issues"
    echo ""
    echo "🔍 Useful Commands:"
    echo "- Check CloudFront status: aws cloudfront get-distribution --id \$(terraform output -raw cloudfront_distribution_id)"
    echo "- Test API endpoint: curl -I https://api.sankofagrid.com/api/v1/auth/health"
    echo "- View ALB logs: Check S3 bucket for ALB access logs"
    
else
    echo "❌ Deployment cancelled."
    rm -f frontend-backend-connection.tfplan
fi