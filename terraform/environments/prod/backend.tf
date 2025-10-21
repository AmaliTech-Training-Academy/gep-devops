# terraform/environments/prod/backend.tf
terraform {
  backend "s3" {
    key     = "prod/terraform.tfstate"
    encrypt = true

    region         = "eu-west-1"
    # bucket         = ""
    # dynamodb_table = ""
  }
}