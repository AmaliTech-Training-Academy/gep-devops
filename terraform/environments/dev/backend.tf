

# ==============================================================================
# terraform/environments/dev/backend.tf
# ==============================================================================
# Terraform Backend Configuration - Remote State Storage
# ==============================================================================
# This file configures Terraform to store state remotely in AWS S3 with DynamoDB
# locking for team collaboration and state consistency.
#
# WHY REMOTE STATE?
# - Enables team collaboration (multiple developers can work simultaneously)
# - Provides state locking to prevent concurrent modifications
# - Automatic state backup and versioning
# - Secure storage with encryption
#
# SETUP PROCESS:
# 1. First, deploy the bootstrap module to create S3 bucket and DynamoDB table:
#    cd terraform/bootstrap
#    terraform init && terraform apply
#
# 2. Note the bucket name and DynamoDB table name from bootstrap outputs
#
# 3. Update this file with the actual resource names (already done below)
#
# 4. Initialize the backend:
#    cd terraform/environments/dev
#    terraform init
#
# 5. Terraform will ask to migrate local state to S3 (answer 'yes')
#
# IMPORTANT NOTES:
# - Never commit terraform.tfstate files to git when using remote backend
# - The S3 bucket has versioning enabled for state file recovery
# - DynamoDB table prevents simultaneous state modifications (locking)
# - State files contain sensitive data (passwords, endpoints) - keep secure
# ==============================================================================

terraform {
  backend "s3" {
    # S3 bucket name for state storage (created by bootstrap module)
    # Format: {project}-terraform-state-{region}-{account-id}
    bucket = "event-planner-terraform-state-eu-west-1-904570587823"
    
    # Path within the bucket where this environment's state will be stored
    # Each environment (dev/prod) has its own state file
    key = "dev/terraform.tfstate"
    
    # AWS region where the S3 bucket is located
    region = "eu-west-1"
    
    # DynamoDB table for state locking (prevents concurrent modifications)
    # Format: {project}-terraform-locks
    dynamodb_table = "event-planner-terraform-locks"
    
    # Enable server-side encryption for state file at rest
    # Uses AWS-managed keys (SSE-S3)
    encrypt = true
    
    # Note: Sensitive credentials (AWS access keys) are configured via:
    # - Environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
    # - AWS CLI profiles (aws configure)
    
  }
}