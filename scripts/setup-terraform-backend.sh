#!/bin/bash
set -e

echo "🏗️  Setting up Terraform S3 backend..."

# Check if AWS CLI is configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS CLI not configured. Please run 'aws configure' first."
    exit 1
fi

# Deploy bootstrap infrastructure
cd terraform/bootstrap
terraform init
terraform plan -out=bootstrap.tfplan
terraform apply bootstrap.tfplan

# Get outputs
BUCKET_NAME=$(terraform output -raw s3_bucket_name)
DYNAMODB_TABLE=$(terraform output -raw dynamodb_table_name)

echo "✅ Backend infrastructure created:"
echo "   S3 Bucket: $BUCKET_NAME"
echo "   DynamoDB Table: $DYNAMODB_TABLE"

# Update backend configurations for each environment
for env in dev staging prod; do
    backend_file="../environments/$env/backend.tf"
    if [ -f "$backend_file" ]; then
        # Replace placeholder with actual bucket name
        sed -i.bak "s/gep-terraform-state-XXXXXXXX/$BUCKET_NAME/g" "$backend_file"
        # Update environment-specific state key
        sed -i.bak "s/environments\/dev/environments\/$env/g" "$backend_file"
        rm -f "$backend_file.bak"
        echo "✅ Updated backend configuration for $env"
    else
        echo "⚠️  Backend file not found for $env environment"
    fi
done

echo ""
echo "🎉 Backend setup complete!"
echo ""
echo "Next steps:"
echo "1. Commit the updated backend.tf files"
echo "2. Initialize each environment:"
echo "   cd terraform/environments/dev && terraform init"
echo "   cd terraform/environments/staging && terraform init" 
echo "   cd terraform/environments/prod && terraform init"
echo ""
echo "3. Add these secrets to GitHub:"
echo "   AWS_ACCESS_KEY_ID"
echo "   AWS_SECRET_ACCESS_KEY"
echo ""
echo "4. Your state files will be stored in:"
echo "   s3://$BUCKET_NAME/environments/dev/terraform.tfstate"
echo "   s3://$BUCKET_NAME/environments/staging/terraform.tfstate"
echo "   s3://$BUCKET_NAME/environments/prod/terraform.tfstate"