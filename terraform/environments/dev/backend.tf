

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
    #other sensitve info is configured via environment variables in github actions.
    # State file path within the bucket
    key = "dev/terraform.tfstate"
    # Enable encryption at rest
    encrypt = true

    # Versioning is enabled on the S3 bucket
    # Point-in-time recovery is enabled on DynamoDB table
  }
}