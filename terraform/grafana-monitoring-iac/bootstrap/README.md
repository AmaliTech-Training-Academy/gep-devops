# Grafana Monitoring Bootstrap

## Purpose
Creates S3 bucket and DynamoDB table for Grafana monitoring Terraform state management.

## Usage

### 1. Deploy Bootstrap
```bash
cd terraform/grafana-monitoring-iac/bootstrap
terraform init
terraform apply
```

### 2. Note Outputs
Copy the bucket and table names from outputs.

### 3. Update Backend Configs
Update `environment/dev/backend.tf` and `environment/prod/backend.tf` with actual resource names.

### 4. Initialize Environments
```bash
cd ../environment/dev
terraform init
```

## Resources Created
- S3 bucket: `grafana-monitoring-state-{region}-{account-id}`
- DynamoDB table: `grafana-monitoring-locks`
