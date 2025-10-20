# terraform/environments/prod/backend.tf
terraform {
  backend "s3" {
    key     = "prod/terraform.tfstate"
    encrypt = true

    region         = "us-east-1"
    # bucket         = "event-planner-frontend-terraform-state-us-east-1-904570587823"
    # dynamodb_table = "event-planner-frontend-terraform-locks"
  }
}