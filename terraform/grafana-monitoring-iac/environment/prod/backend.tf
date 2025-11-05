terraform {
  backend "s3" {
    bucket         = "grafana-monitoring-state-eu-west-1-904570587823"
    dynamodb_table = "grafana-monitoring-locks"
    key            = "prod/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
  }
}
