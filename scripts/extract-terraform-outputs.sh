#!/bin/bash
set -e

ENV=${1:-dev}

echo "Extracting Terraform outputs for $ENV environment..."

cd terraform/environments/$ENV

# Check if terraform state exists
if ! terraform state list > /dev/null 2>&1; then
    echo "❌ No Terraform state found. Run 'terraform apply' first."
    exit 1
fi

OUTPUT_FILE="../../../ansible/inventories/$ENV/group_vars/infrastructure.yml"

cat > $OUTPUT_FILE << EOF
---
# Auto-generated from Terraform outputs
# Generated: $(date)

# ECS Configuration
ecs_cluster_name: $(terraform output -raw ecs_cluster_name 2>/dev/null || echo "event-planner-$ENV-cluster")

# Network
vpc_id: $(terraform output -raw vpc_id 2>/dev/null || echo "")
aws_region: $(terraform output -raw aws_region 2>/dev/null || echo "eu-west-1")

# ECR Repositories
ecr_repositories:
EOF

# Extract ECR URLs
terraform output -json ecr_repository_urls 2>/dev/null | jq -r 'to_entries[] | "  \(.key): \"\(.value)\""' >> $OUTPUT_FILE || echo "  auth: \"\"" >> $OUTPUT_FILE

cat >> $OUTPUT_FILE << EOF

# Database Endpoints
rds_endpoints:
EOF

terraform output -json rds_endpoints 2>/dev/null | jq -r 'to_entries[] | "  \(.key): \"\(.value)\""' >> $OUTPUT_FILE || echo "  auth: \"\"" >> $OUTPUT_FILE

cat >> $OUTPUT_FILE << EOF

# Cache
redis_endpoint: $(terraform output -raw redis_primary_endpoint 2>/dev/null || echo "")

# Secrets Manager
jwt_secret_arn: $(terraform output -raw jwt_secret_arn 2>/dev/null || echo "")
aws_credentials_secret_arn: $(terraform output -raw aws_credentials_secret_arn 2>/dev/null || echo "")
google_credentials_secret_arn: $(terraform output -raw google_credentials_secret_arn 2>/dev/null || echo "")

# Load Balancer
alb_dns_name: $(terraform output -raw alb_dns_name 2>/dev/null || echo "")
alb_arn: $(terraform output -raw alb_arn 2>/dev/null || echo "")

# S3
frontend_bucket: $(terraform output -raw frontend_bucket_name 2>/dev/null || echo "")

# CloudFront
cloudfront_distribution_id: $(terraform output -raw cloudfront_distribution_id 2>/dev/null || echo "")
EOF

echo "✅ Infrastructure details saved to: $OUTPUT_FILE"
echo ""
cat $OUTPUT_FILE
