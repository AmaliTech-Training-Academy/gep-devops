

# ==============================================================================
# terraform/environments/dev/backend.tf
# ==============================================================================
# Terraform Backend Configuration
# ==============================================================================
# Configure S3 backend for remote state storage with DynamoDB locking.
# 
# Before running this configuration:
# 1. Deploy the bootstrap module to create S3 bucket and DynamoDB table
# 2. Update the bucket and dynamodb_table values with actual resource names
# 3. Run: terraform init -backend-config=backend.tf
# ==============================================================================

terraform {
  backend "s3" {
    # S3 bucket for state storage (created by bootstrap module)
    bucket = "event-planner-terraform-state-us-east-1-ACCOUNT_ID"

    # State file path within the bucket
    key = "dev/terraform.tfstate"

    # AWS region
    region = "us-east-1"

    # DynamoDB table for state locking (created by bootstrap module)
    dynamodb_table = "event-planner-terraform-locks"

    # Enable encryption at rest
    encrypt = true

    # Versioning is enabled on the S3 bucket
    # Point-in-time recovery is enabled on DynamoDB table
  }
}