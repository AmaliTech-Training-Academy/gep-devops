# Quick Reference - JWT Configuration

## ✅ All Errors Fixed!

The JWT configuration is now properly structured as a Terraform module.

---

## 📁 Module Structure

```
terraform/
├── modules/
│   └── secrets-manager/          ← NEW MODULE
│       ├── main.tf               ← Generates JWT secret
│       ├── variables.tf          ← Module inputs
│       └── outputs.tf            ← jwt_secret_arn
└── environments/
    └── dev/
        ├── main.tf               ← Uses secrets_manager module
        ├── variables.tf          ← JWT expiration variables
        ├── terraform.tfvars      ← JWT expiration values
        └── outputs.tf            ← Outputs jwt_secret_arn
```

---

## 🚀 Deploy Now

```bash
cd terraform/environments/dev
terraform init    # Install new module
terraform plan    # Review changes
terraform apply   # Deploy
```

---

## 🔐 What Gets Created

### 1. AWS Secrets Manager
- **Secret Name:** `event-planner-dev-jwt-secret`
- **Value:** `{"JWT_SECRET": "64-random-chars"}`
- **Auto-generated:** ✅ Yes

### 2. ECS Task Definition (auth-service)
- **JWT_SECRET:** From Secrets Manager (encrypted)
- **JWT_ACCESS_EXPIRATION:** 3600000 (1 hour)
- **JWT_REFRESH_EXPIRATION:** 86400000 (24 hours)

---

## 📝 Module Usage

### In main.tf:
```hcl
module "secrets_manager" {
  source = "../../modules/secrets-manager"
  
  project_name = "event-planner"
  environment  = "dev"
  tags         = local.common_tags
}

# Reference in other modules
module "iam" {
  jwt_secret_arn = module.secrets_manager.jwt_secret_arn
}

module "ecs" {
  jwt_secret_arn = module.secrets_manager.jwt_secret_arn
}
```

---

## 🔧 Change Expiration Times

### Edit terraform.tfvars:
```hcl
jwt_access_expiration  = 7200000   # 2 hours
jwt_refresh_expiration = 604800000 # 7 days
```

### Apply:
```bash
terraform apply
```

---

## ✅ Verification

### Check secret exists:
```bash
aws secretsmanager describe-secret \
  --secret-id event-planner-dev-jwt-secret \
  --region eu-west-1
```

### View secret value:
```bash
aws secretsmanager get-secret-value \
  --secret-id event-planner-dev-jwt-secret \
  --region eu-west-1 \
  --query 'SecretString' \
  --output text
```

### Check ECS task definition:
```bash
aws ecs describe-task-definition \
  --task-definition event-planner-dev-auth-service \
  --region eu-west-1 \
  --query 'taskDefinition.containerDefinitions[0].{Environment:environment,Secrets:secrets}'
```

---

## 🎯 Summary

✅ JWT secret automatically generated  
✅ Stored securely in AWS Secrets Manager  
✅ Injected into auth-service container  
✅ Expiration times configurable  
✅ All errors resolved  
✅ Ready to deploy  

---

**Next Step:** Run `terraform apply`
