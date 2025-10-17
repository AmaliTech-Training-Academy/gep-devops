# ==============================================================================
# Terraform bootstrap outputs - S3 bucket and DynamoDB table information
# ==============================================================================

# Output the S3 bucket name for backend configuration
output "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

# Output the S3 bucket ARN
output "state_bucket_arn" {
  description = "ARN of the S3 bucket for Terraform state"
  value       = aws_s3_bucket.terraform_state.arn
}

# Output the DynamoDB table name for state locking
output "lock_table_name" {
  description = "Name of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_locks.id
}

# Output the DynamoDB table ARN
output "lock_table_arn" {
  description = "ARN of the DynamoDB table for state locking"
  value       = aws_dynamodb_table.terraform_locks.arn
}

# Output the region
output "aws_region" {
  description = "AWS region where backend resources are created"
  value       = data.aws_region.current.name
}

# Output the AWS account ID
output "aws_account_id" {
  description = "AWS account ID where backend resources are created"
  value       = data.aws_caller_identity.current.account_id
}

# Output backend configuration for copy-paste
output "backend_config" {
  description = "Terraform backend configuration block (for reference)"
  value       = <<-EOT
    terraform {
      backend "s3" {
        bucket         = "${aws_s3_bucket.terraform_state.id}"
        key            = "ENVIRONMENT/terraform.tfstate"  # Replace ENVIRONMENT with dev/prod
        region         = "${data.aws_region.current.name}"
        dynamodb_table = "${aws_dynamodb_table.terraform_locks.id}"
        encrypt        = true
      }
    }
  EOT
}