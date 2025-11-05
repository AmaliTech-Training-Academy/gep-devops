terraform {
  backend "s3" {
    bucket         = "gep-grafana-monitoring-state-eu-west-1-904570587823"
    dynamodb_table = "gep-grafana-monitoring-locks"
    key            = "dev/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
  }
}
