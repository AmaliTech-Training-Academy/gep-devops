# Centralized GEP DevOps Repository Structure

## This Repository (gep_devops) - Central Control

```
gep_devops/
├── .github/
│   └── workflows/
│       ├── backend-ci-cd.yml            # Triggered by backend repo
│       ├── frontend-ci-cd.yml           # Triggered by frontend repo
│       ├── infrastructure-ci-cd.yml     # Terraform deployments
│       ├── master-pipeline.yml          # Orchestrates all pipelines
│       ├── security-monitoring.yml      # Security scans
│       └── terraform-deploy-oidc.yml    # OIDC-based deployments
├── terraform/
│   ├── bootstrap/                     # S3 backend setup (run once)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   ├── modules/
│   │   ├── vpc/
│   │   ├── ecs/
│   │   ├── ecr/
│   │   ├── rds/
│   │   ├── elasticache/
│   │   ├── s3/
│   │   ├── cloudfront/
│   │   ├── alb/
│   │   ├── route53/
│   │   ├── acm/
│   │   ├── cloudwatch/
│   │   ├── iam/
│   │   └── security-groups/
│   └── environments/
│       ├── dev/
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   ├── terraform.tfvars
│       │   ├── backend.tf
│       │   └── outputs.tf
│       └── prod/
│           ├── main.tf
│           ├── variables.tf
│           ├── terraform.tfvars
│           ├── backend.tf
│           └── outputs.tf
├── configs/
│   ├── backend-configs/
│   │   ├── dev/
│   │   │   ├── application.yml
│   │   │   └── database.yml
│   │   ├── prod/
│   │   │   ├── application.yml
│   │   │   └── database.yml
│   │   └── staging/
│   │       ├── application.yml
│   │       └── database.yml
│   ├── frontend-configs/
│   │   ├── dev/
│   │   │   ├── environment.ts
│   │   │   └── nginx.conf
│   │   ├── prod/
│   │   │   ├── environment.ts
│   │   │   └── nginx.conf
│   │   └── staging/
│   │       ├── environment.ts
│   │       └── nginx.conf
│   └── shared-configs/
│       ├── docker/
│       │   ├── backend.Dockerfile
│       │   └── frontend.Dockerfile
│       ├── nginx/
│       │   └── nginx.conf
│       └── security/
│           └── security-headers.conf
├── docs/
│   ├── README.md
│   ├── 01-project-overview.md
│   ├── 02-terraform-infrastructure.md
│   ├── 03-cicd-pipeline-implementation.md
│   ├── 04-deployment-workflows.md
│   ├── 05-monitoring-security-operations.md
│   ├── 06-cost-optimization-best-practices.md
│   └── 07-troubleshooting-runbooks.md
└── README.md
```

## External Repositories (Minimal Pipeline Structure)

### Backend Repository (gep-backend)
```
gep-backend/
├── .github/
│   └── workflows/
│       └── trigger-deployment.yml     # Intelligent change detection
├── services/
│   ├── auth-service/
│   ├── event-service/
│   ├── notification-service/
│   ├── booking-service/
│   ├── payment-service/
│   ├── api-gateway/
│   ├── config-server/
│   └── discovery-server/
├── shared/
│   ├── common-lib/
│   ├── security-lib/
│   └── messaging-lib/
└── README.md
```

### Frontend Repository (event-planner-frontend)
```
event-planner-frontend/
├── .github/
│   └── workflows/
│       └── trigger-devops.yml         # Simple deployment trigger
├── src/
├── cypress/
└── README.md
```

## Pipeline Trigger Architecture

### Repository Dispatch Triggers
```yaml
Backend Repo Events:
├── push to dev → triggers backend-ci-cd.yml (dev)
├── push to staging → triggers backend-ci-cd.yml (staging)
├── push to prod → triggers backend-ci-cd.yml (prod)
└── pull_request → triggers backend-ci-cd.yml (validation)

Frontend Repo Events:
├── push to dev → triggers frontend-ci-cd.yml (dev)
├── push to staging → triggers frontend-ci-cd.yml (staging)
├── push to prod → triggers frontend-ci-cd.yml (prod)
└── pull_request → triggers frontend-ci-cd.yml (validation)
```

## Central Pipeline Structure

### Backend CI/CD Pipeline (backend-ci-cd.yml)
```yaml
Trigger: repository_dispatch from gep-backend
Jobs:
├── checkout-backend-code
├── java-build-test
├── security-scan
├── docker-build-push-ecr
├── update-ecs-task-definition
├── deploy-to-environment
├── health-checks
├── rollback-on-failure
└── slack-notifications
```

### Frontend CI/CD Pipeline (frontend-ci-cd.yml)
```yaml
Trigger: repository_dispatch from event-planner-frontend
Jobs:
├── checkout-frontend-code
├── node-build-test
├── security-audit
├── build-production
├── deploy-to-s3
├── cloudfront-invalidation
├── lighthouse-audit
├── smoke-tests
└── slack-notifications
```

### Local Infrastructure Management
```bash
# Infrastructure managed locally with scripts:
├── ./scripts/terraform/init-backend.sh    # One-time S3 setup
├── ./scripts/terraform/deploy-env.sh dev plan
├── ./scripts/terraform/deploy-env.sh dev apply
├── ./scripts/terraform/validate-all.sh
└── Manual approval for staging/prod
```

## Environment Management

### Development Environment
```yaml
Auto-Deploy: true
Approval: none
Resources: minimal
Monitoring: basic
```

### Staging Environment
```yaml
Auto-Deploy: false
Approval: 1 reviewer
Resources: production-like
Monitoring: comprehensive
```

### Production Environment
```yaml
Auto-Deploy: false
Approval: 2+ reviewers
Resources: high-availability
Monitoring: full-stack
```

## Secrets Management Structure

### Repository Secrets (gep_devops)
```yaml
AWS:
  - AWS_ACCESS_KEY_ID
  - AWS_SECRET_ACCESS_KEY
  - AWS_REGION

Container Registry:
  - ECR_REGISTRY_URL

External Repos:
  - DEVOPS_REPO_TOKEN
  - DEVOPS_REPO_OWNER

Notifications:
  - SLACK_WEBHOOK
  - TEAMS_WEBHOOK

Security Tools:
  - SONAR_TOKEN
  - SNYK_TOKEN

Environment Specific:
  - DB_PASSWORD_DEV
  - DB_PASSWORD_STAGING
  - DB_PASSWORD_PROD
```

## Monitoring and Alerting

### Health Monitoring (health-monitoring.yml)
```yaml
Schedule: */15 minutes
Monitors:
├── ECS service health
├── ALB target health
├── RDS connectivity
├── ElastiCache status
├── CloudFront distribution
└── Route53 health checks
```

### Performance Monitoring (performance-monitoring.yml)
```yaml
Schedule: hourly
Tests:
├── Load testing (K6)
├── Lighthouse audits
├── API response times
├── Database performance
└── Cost optimization
```

### Security Monitoring (security-monitoring.yml)
```yaml
Schedule: daily
Scans:
├── Container vulnerability
├── Infrastructure compliance
├── SSL certificate expiry
├── Access pattern analysis
└── Secrets detection
```