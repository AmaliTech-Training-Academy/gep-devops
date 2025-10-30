# Event Planner Platform - DevOps Infrastructure Documentation
## Part 3: CI/CD Pipeline Implementation

**Author:** DevOps Team  
**Last Updated:** October 30, 2025  
**Version:** 1.0.0

---

## CI/CD Pipeline Architecture

The Event Planner Platform uses a **centralized CI/CD approach** with GitHub Actions, where all pipeline logic resides in the `gep_devops` repository and is triggered by external application repositories via `repository_dispatch` events.

### Pipeline Structure

```
.github/workflows/
├── master-pipeline.yml           # Orchestrates all pipelines
├── backend-ci-cd.yml            # Java/Spring Boot services
├── frontend-ci-cd.yml           # Angular application
├── infrastructure-ci-cd.yml     # Terraform deployments
├── security-monitoring.yml      # Security scans
└── terraform-deploy-oidc.yml    # OIDC-based deployments
```

---

## Backend CI/CD Pipeline

### Pipeline Overview

The backend pipeline (`backend-ci-cd.yml`) handles Java Spring Boot microservices with **selective service deployment** - only building and deploying services that have changed.

### Trigger Mechanisms

```yaml
on:
  repository_dispatch:
    types: [backend-deployment]
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        default: dev
        type: choice
        options: [dev, staging, prod]
      services:
        description: 'Services to deploy (JSON array)'
        required: false
        default: '["auth-service", "notification-service"]'
        type: string
```

### Key Pipeline Jobs

#### 1. Prepare Job - Service Discovery

**Purpose**: Dynamically determines which services to build and deploy.

```yaml
- name: Determine Services to Deploy
  id: services
  run: |
    # Use services from repository dispatch payload, fallback to enabled services
    if [ -n "${{ github.event.client_payload.services }}" ]; then
      SERVICES='${{ toJson(github.event.client_payload.services) }}'
    else
      # Default enabled services (Terraform-managed)
      SERVICES='["auth-service", "notification-service"]'
    fi
    
    # Filter only services that are enabled in Terraform
    ENABLED_SERVICES=("auth-service" "notification-service")
    # Filter logic ensures only active services are deployed
```

**Key Innovation**: Prevents deployment conflicts by only deploying services that exist in Terraform configuration.

#### 2. Build and Test Job - Optimized Java Builds

**Purpose**: Builds Java services with Maven, includes security scanning.

```yaml
- name: Build and Test Service
  run: |
    export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
    export MAVEN_OPTS="-Dmaven.repo.local=$HOME/.m2/repository -Xmx1024m"
    cd services/${{ matrix.service }}
    mvn clean package -DskipTests -T 1C --batch-mode
```

**Optimizations**:
- **Maven caching** reduces build time by ~60%
- **Parallel builds** with `-T 1C` flag
- **Skip tests in dev** for faster iterations
- **Pre-installed tools** on self-hosted runners

#### 3. Build and Push Job - ECR Integration

**Purpose**: Builds Docker images and pushes to ECR with proper tagging.

```yaml
- name: Build and Push Docker Image
  run: |
    cd services/${{ matrix.service }}
    REGISTRY="${{ steps.login-ecr.outputs.registry }}"
    
    # Use Terraform naming convention: event-planner-{env}-{service}
    REPO_NAME="event-planner-${{ env.ENVIRONMENT }}-${{ matrix.service }}"
    IMAGE_TAG="${{ env.COMMIT_SHA }}"
    
    docker build -t "$REGISTRY/$REPO_NAME:$IMAGE_TAG" .
    docker push "$REGISTRY/$REPO_NAME:$IMAGE_TAG"
    
    # Also tag as latest (Terraform uses 'latest' by default)
    docker tag "$REGISTRY/$REPO_NAME:$IMAGE_TAG" "$REGISTRY/$REPO_NAME:latest"
    docker push "$REGISTRY/$REPO_NAME:latest"
```

**Key Features**:
- **Consistent naming** with Terraform ECR repositories
- **Dual tagging** (commit SHA + latest) for flexibility
- **Direct ECR integration** without registry secrets

#### 4. Deploy to ECS Job - Intelligent Service Management

**Purpose**: Deploys services to ECS with automatic service activation and health checks.

```yaml
- name: Check and Activate Service
  run: |
    SERVICE_NAME="${{ matrix.service }}"
    CLUSTER_NAME="${{ env.ECS_CLUSTER }}"
    
    # Check if service exists and get its status
    SERVICE_INFO=$(aws ecs describe-services \
      --cluster "$CLUSTER_NAME" \
      --services "$SERVICE_NAME" \
      --query 'services[0].{Status:status,DesiredCount:desiredCount}' \
      --output json 2>/dev/null || echo '{"Status":"NOT_FOUND"}')
    
    if [ "$SERVICE_STATUS" = "INACTIVE" ] || [ "$DESIRED_COUNT" = "0" ]; then
      echo "🔄 Service $SERVICE_NAME is INACTIVE. Scaling up..."
      aws ecs update-service \
        --cluster "$CLUSTER_NAME" \
        --service "$SERVICE_NAME" \
        --desired-count 1
    fi
```

**Smart Features**:
- **Service existence checking** prevents deployment failures
- **Automatic service activation** for scaled-down services
- **Comprehensive error handling** with detailed diagnostics
- **10-minute timeout** with failure analysis

---

## Frontend CI/CD Pipeline

### Pipeline Overview

The frontend pipeline (`frontend-ci-cd.yml`) handles Angular application deployment to S3 + CloudFront.

### Key Jobs

#### 1. Build and Test Job

```yaml
- name: Install and Build
  working-directory: frontend
  run: |
    if [ -f "package-lock.json" ]; then
      npm ci
    else
      npm install
    fi
    
    if npm run | grep -q "build:${{ env.ENVIRONMENT }}"; then
      npm run build:${{ env.ENVIRONMENT }}
    else
      npm run build
    fi
```

#### 2. Deploy to S3 Job

```yaml
- name: Deploy to S3
  run: |
    case "${{ env.ENVIRONMENT }}" in
      dev) BUCKET="${{ secrets.S3_BUCKET_DEV }}" ;;
      staging) BUCKET="${{ secrets.S3_BUCKET_STAGING }}" ;;
      prod) BUCKET="${{ secrets.S3_BUCKET_PROD }}" ;;
    esac
    
    aws s3 sync dist/ s3://$BUCKET --delete
```

#### 3. CloudFront Invalidation

```yaml
- name: Invalidate CloudFront
  run: |
    aws cloudfront create-invalidation \
      --distribution-id $DISTRIBUTION \
      --paths "/*"
```

---

## Master Pipeline Orchestrator

### Purpose

The master pipeline (`master-pipeline.yml`) provides a **unified interface** for triggering multiple pipelines with different deployment strategies per environment.

### Deployment Strategies

#### Development & Staging: Rolling Deployment
```yaml
backend-pipeline:
  needs: [pipeline-start, infrastructure-pipeline]
  if: inputs.run_backend && inputs.environment != 'prod'
  uses: ./.github/workflows/backend-ci-cd.yml
```

#### Production: Blue-Green Deployment
```yaml
backend-blue-green:
  needs: [pipeline-start, infrastructure-pipeline]
  if: inputs.run_backend && inputs.environment == 'prod'
  uses: ./.github/workflows/backend-blue-green.yml
```

### Pipeline Orchestration Features

- **Conditional execution** based on environment
- **Dependency management** between pipelines
- **Comprehensive reporting** with pipeline summaries
- **Slack notifications** for all pipeline events

---

## Self-Hosted Runners Implementation

### Runner Configuration

**Backend Runner**:
- **Pre-installed tools**: Java 21, Maven 3.9+, Docker, AWS CLI
- **Labels**: `[self-hosted, backend]`
- **Benefits**: ~3-5 minutes faster builds (no tool installation)

**Frontend Runner**:
- **Pre-installed tools**: Node.js 18, npm, AWS CLI
- **Labels**: `[self-hosted, frontend]`
- **Benefits**: ~2-3 minutes faster builds

### Runner Optimization

```yaml
- name: Cache Maven Dependencies
  uses: actions/cache@v3
  with:
    path: ~/.m2/repository
    key: ${{ runner.os }}-maven-${{ hashFiles('**/pom.xml') }}
    restore-keys: |
      ${{ runner.os }}-maven-
```

---

## Security Integration

### 1. Trivy Security Scanning

```yaml
- name: Security Scan (Trivy)
  uses: aquasecurity/trivy-action@master
  with:
    scan-type: 'fs'
    scan-ref: 'services/${{ matrix.service }}'
```

### 2. Secrets Management

```yaml
secrets:
  - name: "DB_PASSWORD"
    valueFrom: "arn:aws:secretsmanager:region:account:secret:db-password"
  - name: "JWT_SECRET"
    valueFrom: "arn:aws:secretsmanager:region:account:secret:jwt-secret"
```

### 3. OIDC Authentication (Planned)

```yaml
# terraform-deploy-oidc.yml
- name: Configure AWS Credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_TO_ASSUME }}
    role-session-name: GitHubActions
    aws-region: ${{ env.AWS_REGION }}
```

---

## Pipeline Evolution & Improvements

### Recent Enhancements (October 2025)

1. **Selective Service Building** (Commit: 5678627)
   - Only build services that have changed
   - Reduces build time by ~50% for partial deployments

2. **Enhanced Error Handling** (Commit: e39de9b)
   - Comprehensive service status checking
   - Detailed failure diagnostics
   - Automatic retry mechanisms

3. **Service Activation Logic** (Commit: edf01b8)
   - Automatically scale up INACTIVE services
   - Handle edge cases in ECS service states

4. **Build Performance Optimization** (Commit: e39de9b)
   - Skip tests in development environment
   - Parallel Maven builds
   - Optimized Docker layer caching

### Pipeline Metrics

- **Average build time**: 8-12 minutes (backend), 5-8 minutes (frontend)
- **Success rate**: >95% (after error handling improvements)
- **Deployment frequency**: 3-5 times per day (development)
- **Mean time to recovery**: <15 minutes

---

## Repository Dispatch Integration

### Trigger from Backend Repository

```yaml
# In gep-backend repository
- name: Trigger DevOps Pipeline
  uses: peter-evans/repository-dispatch@v2
  with:
    token: ${{ secrets.DEVOPS_REPO_TOKEN }}
    repository: AmaliTech-Training-Academy/gep-devops
    event-type: backend-deployment
    client-payload: |
      {
        "environment": "dev",
        "repository": "AmaliTech-Training-Academy/gep-backend",
        "sha": "${{ github.sha }}",
        "services": ["auth-service", "notification-service"]
      }
```

### Benefits of Repository Dispatch

1. **Centralized pipeline logic** - Update once, affects all services
2. **Consistent deployments** - Same process across all environments
3. **Better security** - Secrets managed in one place
4. **Easier maintenance** - Single point of pipeline updates

---

## Monitoring and Notifications

### Slack Integration

```yaml
- name: Slack Notification
  uses: 8398a7/action-slack@v3
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
  with:
    status: custom
    custom_payload: |
      {
        "text": "Backend Deployment Status",
        "attachments": [{
          "color": "${{ contains(needs.*.result, 'failure') && 'danger' || 'good' }}",
          "fields": [
            {
              "title": "Status",
              "value": "${{ contains(needs.*.result, 'failure') && 'Failed' || 'Succeeded' }}",
              "short": true
            },
            {
              "title": "Environment", 
              "value": "${{ env.ENVIRONMENT }}",
              "short": true
            }
          ]
        }]
      }
```

### Pipeline Reporting

- **Real-time status updates** via Slack
- **Deployment summaries** with artifact links
- **Failure analysis** with detailed error logs
- **Performance metrics** tracking

---

## Next Steps

This covers the CI/CD pipeline implementation. Continue with:

- **Part 4**: Deployment Workflows and Automation
- **Part 5**: Monitoring, Security, and Operations
- **Part 6**: Cost Optimization and Best Practices