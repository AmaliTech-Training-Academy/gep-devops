# CI/CD Pipeline Implementation

**Last Updated:** November 2025  
**Version:** 2.0.0

## Overview

The Event Planner Platform uses GitHub Actions for automated CI/CD pipelines. Three separate pipelines handle infrastructure, backend, and frontend deployments with a master pipeline orchestrating the workflow.

## Pipeline Architecture

![CI/CD Architecture](diagrams/ci-cd-architecture-draft.png)

### Pipeline Components

1. **Infrastructure Pipeline** - Terraform deployments
2. **Backend Pipeline** - Java/Spring Boot services
3. **Frontend Pipeline** - Angular application
4. **Master Pipeline** - Orchestration and coordination

## Infrastructure Pipeline

**File:** `.github/workflows/infrastructure-ci-cd.yml`

### Pipeline Stages

**1. Validate**
- Terraform format check
- Syntax validation
- TFLint scanning

**2. Security Scan**
- Checkov security analysis
- tfsec vulnerability scanning
- Policy compliance checks

**3. Plan**
- Generate infrastructure changes
- Review resource modifications
- Cost estimation

**4. Deploy**
- Apply infrastructure changes
- Update AWS resources
- Verify deployment

**5. Notify**
- Send Slack notifications
- Report deployment status

### Workflow Triggers

- Push to main/dev/staging branches
- Pull requests (plan only)
- Manual workflow dispatch

### Environment Variables

```yaml
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_REGION
TF_STATE_BUCKET
TF_STATE_DYNAMODB_TABLE
SLACK_WEBHOOK_URL
```

## Backend Pipeline

**File:** `.github/workflows/backend-ci-cd.yml`

### Pipeline Stages

**1. Build**
- Maven clean install
- Run unit tests
- Generate test reports

**2. Docker**
- Build Docker images
- Tag with commit SHA
- Push to Amazon ECR

**3. Deploy**
- Update ECS task definitions
- Deploy to ECS Fargate
- Register with service discovery

**4. Verify**
- Health check validation
- Service availability check
- Smoke tests

### Service Detection

Pipeline automatically detects changed services and deploys only modified microservices:

```yaml
- auth-service (port 8081)
- event-service (port 8082)
- payment-service (port 8088)
- notification-service (port 8085)
```

### Build Configuration

**Java:**
- Version: Java 21
- Build Tool: Maven 3.9+
- Spring Boot: 3.x

**Docker:**
- Base Image: eclipse-temurin:21-jre-alpine
- Multi-stage builds
- Layer caching enabled

## Frontend Pipeline

**File:** `.github/workflows/frontend-ci-cd.yml`

### Pipeline Stages

**1. Build**
- npm install dependencies
- Run linting (ESLint)
- Run unit tests (Karma/Jasmine)
- Build production bundle

**2. Deploy**
- Upload to S3 bucket
- Set cache headers
- Update bucket policy

**3. Invalidate**
- CloudFront cache invalidation
- Verify distribution update

### Build Configuration

**Node.js:**
- Version: 18.x
- Package Manager: npm
- Framework: Angular 17+

**Build Command:**
```bash
ng build --configuration=production
```

**Output:**
- Minified JavaScript
- Optimized assets
- Source maps (optional)

## Master Pipeline

**File:** `.github/workflows/master-pipeline.yml`

### Orchestration Flow

1. Trigger infrastructure pipeline
2. Wait for infrastructure completion
3. Trigger backend pipeline (if changes detected)
4. Trigger frontend pipeline (if changes detected)
5. Run integration tests
6. Send consolidated notifications

### Dependencies

```yaml
infrastructure → backend → frontend → tests → notify
```

## Reusable Actions

### AWS Configure

**Path:** `.github/actions/aws-configure/`

Configures AWS credentials for pipeline steps.

### Terraform Init

**Path:** `.github/actions/terraform-init/`

Initializes Terraform with S3 backend configuration.

### Terraform Deploy

**Path:** `.github/actions/terraform-deploy/`

Executes Terraform plan and apply operations.

### Terraform Security Scan

**Path:** `.github/actions/terraform-security-scan/`

Runs security scanning tools on Terraform code.

### Docker Build Push

**Path:** `.github/actions/docker-build-push/`

Builds and pushes Docker images to ECR.

### ECS Deploy

**Path:** `.github/actions/ecs-deploy/`

Updates ECS services with new task definitions.

### Frontend Build

**Path:** `.github/actions/frontend-build/`

Builds Angular application for production.

### S3 Deploy

**Path:** `.github/actions/s3-deploy/`

Deploys frontend assets to S3 bucket.

## Environment Protection

### Development
- No approval required
- Automatic deployment on push
- Fast feedback loop

### Staging
- Optional approval
- Manual trigger available
- Pre-production testing

### Production
- Required approval from designated reviewers
- Blue-green deployment strategy
- Rollback capability

## Deployment Strategies

### Rolling Deployment (Development)

1. Build new task definition
2. Update ECS service
3. ECS gradually replaces tasks
4. Health checks validate new tasks
5. Old tasks terminated

### Blue-Green Deployment (Production)

1. Deploy to green environment
2. Run smoke tests
3. Switch traffic to green
4. Monitor for issues
5. Keep blue for rollback

## Security Features

### Secrets Management
- GitHub Secrets for credentials
- AWS Secrets Manager integration
- No hardcoded secrets in code

### Access Control
- IAM roles for pipeline execution
- Least-privilege permissions
- Audit logging enabled

### Code Scanning
- Terraform security scanning
- Dependency vulnerability checks
- Container image scanning

## Monitoring & Notifications

### Slack Integration

Notifications sent for:
- Deployment start/completion
- Build failures
- Security scan results
- Approval requests

### CloudWatch Integration

Metrics tracked:
- Pipeline execution time
- Deployment success rate
- Build failure rate
- Resource utilization

## Troubleshooting

### Common Issues

**Terraform State Lock**
```bash
# Force unlock if needed
terraform force-unlock <LOCK_ID>
```

**ECS Deployment Timeout**
- Check service health checks
- Review CloudWatch logs
- Verify security group rules

**Docker Build Failures**
- Check Dockerfile syntax
- Verify base image availability
- Review build logs

**S3 Deployment Issues**
- Verify bucket permissions
- Check IAM role policies
- Review CloudFront settings

## Best Practices

### Pipeline Design
- Keep pipelines fast and focused
- Use caching for dependencies
- Parallelize independent steps
- Fail fast on errors

### Testing
- Run tests before deployment
- Use smoke tests after deployment
- Implement health checks
- Monitor application metrics

### Rollback Strategy
- Keep previous task definitions
- Maintain deployment history
- Test rollback procedures
- Document rollback steps

## Performance Optimization

### Build Caching
- Maven dependency caching
- npm package caching
- Docker layer caching
- Terraform provider caching

### Parallel Execution
- Independent service builds
- Concurrent test execution
- Parallel infrastructure updates

### Resource Optimization
- Minimal runner requirements
- Efficient Docker images
- Optimized build commands

## Compliance & Auditing

### Audit Trail
- All deployments logged
- Change tracking enabled
- Approval history maintained

### Compliance Checks
- Security scanning required
- Code review enforced
- Automated policy validation
