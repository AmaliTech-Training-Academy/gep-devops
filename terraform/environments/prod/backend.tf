# terraform/environments/prod/backend.tf
# ==============================================================================
# Production Environment - Remote State Configuration
# ==============================================================================
# Terraform backend for production state storage with S3 and DynamoDB locking.
#
# IMPORTANT: Production state is separate from development state.
# ==============================================================================

terraform {
  backend "s3" {
    # S3 bucket for production state (created by bootstrap module)
    bucket = "event-planner-terraform-state-eu-west-1-904570587823"

    # DynamoDB table for state locking
    dynamodb_table = "event-planner-terraform-locks"

    # Production state file path
    key = "prod/terraform.tfstate"

    # Region
    region = "eu-west-1"

    # Enable encryption
    encrypt = true
  }
}