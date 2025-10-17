# Terraform Bootstrap Module

This directory contains the bootstrap configuration for setting up S3 backend and DynamoDB locking for Terraform state management.

##  Overview

This **bootstrap module** provisions the foundational AWS resources required to manage Terraform state securely and reliably.  
It should be executed **only once** before deploying any environments or infrastructure modules.

###  Purpose
- Create an **S3 bucket** for Terraform state file storage  
- Create a **DynamoDB table** for Terraform state locking  
- Enable **encryption, versioning, and lifecycle management** for secure state management  
- Set up **CloudWatch monitoring** and **SNS alerts** for visibility

---

##  Architecture Overview

| Resource | Purpose | Key Features |
|-----------|----------|---------------|
| **S3 Bucket** | Stores Terraform state files | Versioning, encryption (AES-256), lifecycle rules, access logs |
| **DynamoDB Table** | State locking & consistency | On-demand pricing, PITR (point-in-time recovery), encryption |
| **SNS Topic + Alerts** | Sends notifications on anomalies | Optional email subscriptions |
| **CloudWatch Alarm** | Monitors high DynamoDB read usage | Sends alerts via SNS |

---

##  Folder Structure

terraform/
└── bootstrap/
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf # (optional - can include bucket & table names)
        ├── terraform.tfvars # (user-defined values)
        └── README.md


---

##  Prerequisites

Before running the bootstrap:

1. **Install Terraform**  
  Ensure you have Terraform v1.5.0 or later:
   ```bash
       terraform -version
       cd terraform/bootstrap


2. **Configure AWS credentials**
Terraform uses your local AWS credentials to create resources:
aws configure

Usage 
```bash
   cd terraform/bootstrap
   terraform init
   terraform plan
   terraform apply
