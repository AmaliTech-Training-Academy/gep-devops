# Ansible Configuration Management Plan

## Overview

This plan integrates Ansible for configuration management of the Event Planner infrastructure, complementing Terraform's infrastructure provisioning.

## Architecture

**Terraform**: Provisions AWS infrastructure (VPC, ECS, RDS, etc.)
**Ansible**: Manages application configurations, secrets, deployments, and runtime settings

## Directory Structure

```
gep_devops/
├── ansible/
│   ├── inventories/
│   │   ├── dev/
│   │   │   ├── hosts.yml
│   │   │   └── group_vars/
│   │   │       ├── all.yml
│   │   │       └── ecs.yml
│   │   ├── staging/
│   │   └── prod/
│   ├── roles/
│   │   ├── ecs-service/
│   │   ├── secrets-manager/
│   │   ├── database-config/
│   │   └── monitoring/
│   ├── playbooks/
│   │   ├── deploy-services.yml
│   │   ├── update-secrets.yml
│   │   ├── configure-monitoring.yml
│   │   └── rollback.yml
│   ├── ansible.cfg
│   └── requirements.yml
```

## Use Cases

### 1. ECS Service Configuration
- Update environment variables without redeploying infrastructure
- Manage service-specific configurations
- Update task definitions dynamically

### 2. Secrets Management
- Rotate secrets in AWS Secrets Manager
- Update database passwords
- Manage API keys and tokens

### 3. Application Deployment
- Deploy new Docker images to ECS
- Perform blue-green deployments
- Rollback to previous versions

### 4. Configuration Drift Detection
- Verify configurations match desired state
- Report configuration inconsistencies
- Auto-remediate drift

## Implementation Steps

### Step 1: Install Ansible
```bash
pip install ansible boto3 botocore
ansible-galaxy collection install amazon.aws community.aws
```

### Step 2: Configure AWS Authentication
```bash
export AWS_PROFILE=gtp-cletus
export AWS_REGION=eu-west-1
```

### Step 3: Create Inventory
Dynamic inventory using AWS tags to discover ECS services, RDS instances, etc.

### Step 4: Create Roles
- **ecs-service**: Manage ECS task definitions and services
- **secrets-manager**: Update and rotate secrets
- **database-config**: Configure RDS parameters
- **monitoring**: Configure CloudWatch alarms

### Step 5: Create Playbooks
- Deploy services
- Update configurations
- Rotate secrets
- Configure monitoring

## Integration with CI/CD

```yaml
# .github/workflows/ansible-deploy.yml
- name: Run Ansible Playbook
  run: |
    ansible-playbook -i inventories/dev \
      playbooks/deploy-services.yml \
      --extra-vars "image_tag=${{ github.sha }}"
```

## Key Benefits

1. **Separation of Concerns**: Terraform for infrastructure, Ansible for configuration
2. **Faster Updates**: Change configs without Terraform apply
3. **Idempotent**: Safe to run multiple times
4. **Auditable**: Track configuration changes in Git
5. **Flexible**: Easy to add new services or configurations

## Quick Start Commands

```bash
# Deploy all services
ansible-playbook -i inventories/dev playbooks/deploy-services.yml

# Update secrets
ansible-playbook -i inventories/dev playbooks/update-secrets.yml

# Configure monitoring
ansible-playbook -i inventories/dev playbooks/configure-monitoring.yml

# Rollback deployment
ansible-playbook -i inventories/dev playbooks/rollback.yml --extra-vars "version=previous"
```

## Security Considerations

- Use Ansible Vault for sensitive variables
- Leverage AWS IAM roles for authentication
- Encrypt secrets at rest
- Audit all configuration changes
- Use least privilege access

## Monitoring & Validation

- Pre-deployment validation checks
- Post-deployment health checks
- Configuration drift detection
- Automated rollback on failure
