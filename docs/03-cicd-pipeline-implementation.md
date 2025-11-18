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
├── master-pipeline.yml                # Orchestrates all pipelines
├── backend-ci-cd.yml                 # Java/Spring Boot services (dev/staging)
├── frontend-ci-cd.yml                # Angular application (dev/staging)
├── backend-prod-blue-green.yml       # Backend production deployment ⭐ NEW
├── frontend-prod-blue-green.yml      # Frontend production deployment ⭐ NEW
├── infrastructure-ci-cd.yml          # Terraform deployments
├── security-monitoring.yml           # Security scans
└── terraform-deploy-oidc.yml         # OIDC-based deployments
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

## Infrastructure CI/CD Pipeline

### Pipeline Overview

The infrastructure pipeline (`infrastructure-ci-cd.yml`) handles Terraform deployments with security scanning, validation, and state management.

### Reusable Actions

#### setup-terraform
Sets up Terraform with AWS CLI and dependencies.

**Inputs:**
- `terraform-version`: Terraform version (default: '1.13.4')
- `terraform-wrapper`: Enable wrapper (default: 'true')

#### terraform-init
Initializes Terraform with S3 backend configuration.

**Inputs:**
- `environment`: Environment name (dev/staging/prod)
- `state-bucket`: S3 bucket for state
- `state-dynamodb-table`: DynamoDB table for locking
- `aws-region`: AWS region

#### terraform-security-scan
Runs Checkov and TFSec security scans on Terraform code.

#### terraform-deploy
Plans and applies Terraform configuration with state backup.

**Inputs:**
- `environment`: Environment name
- `action`: Action to perform (plan/apply)
- `state-bucket`: S3 bucket for backup
- `aws-region`: AWS region

#### workspace-cleanup
Cleans workspace and temporary files.

### Key Pipeline Jobs

#### 1. Validate Job
```yaml
- uses: ./.github/actions/setup-terraform
- name: Terraform Format Check
- uses: ./.github/actions/terraform-init
- name: Terraform Validate
- name: TFLint
```

#### 2. Security Scan Job
```yaml
- uses: ./.github/actions/terraform-security-scan
```

#### 3. Plan Job (PRs)
```yaml
- uses: ./.github/actions/terraform-deploy
  with:
    action: plan
- name: Comment PR with Plan
```

#### 4. Deploy Job (Push to branches)
```yaml
- uses: ./.github/actions/terraform-deploy
  with:
    action: apply
- name: Upload State Backup
```

### Smart Environment Detection
```yaml
env:
  ENVIRONMENT: ${{ github.ref == 'refs/heads/dev' && 'dev' || github.ref == 'refs/heads/staging' && 'staging' || github.ref == 'refs/heads/main' && 'prod' || inputs.environment }}
  ACTION: ${{ inputs.action || (github.event_name == 'pull_request' && 'plan' || 'apply') }}
```

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

1. **Intelligent Change Detection** (Latest)
   - Git-based service change detection in backend repository
   - Shared library dependency awareness
   - Workflow change triggers for comprehensive testing
   - Branch-based environment mapping (both repositories)
   - Developer information tracking for notifications

2. **Selective Service Building** (Commit: 5678627)
   - Only build services that have changed
   - Reduces build time by ~50% for partial deployments
   - Integration with backend repository change detection

3. **Enhanced Error Handling** (Commit: e39de9b)
   - Comprehensive service status checking
   - Detailed failure diagnostics
   - Repository access validation
   - Automatic retry mechanisms

4. **Service Activation Logic** (Commit: edf01b8)
   - Automatically scale up INACTIVE services
   - Handle edge cases in ECS service states
   - Smart service existence checking

5. **Build Performance Optimization** (Commit: e39de9b)
   - Skip tests in development environment
   - Parallel Maven builds
   - Optimized Docker layer caching

### Pipeline Metrics

- **Average build time**: 8-12 minutes (backend), 5-8 minutes (frontend)
- **Selective deployment savings**: ~50% reduction when only 1-2 services changed
- **Success rate**: >95% (after error handling improvements)
- **Change detection accuracy**: >98% (correctly identifies affected services)
- **Deployment frequency**: 3-5 times per day (development)
- **Mean time to recovery**: <15 minutes

---

## Repository Dispatch Integration

### Intelligent Change Detection in Backend Repository

The backend repository (`gep-backend`) includes a sophisticated `trigger-deployment.yml` workflow that automatically detects which services have changed and triggers selective deployments.

#### Change Detection Logic

```yaml
# Detects changed services based on file paths
- name: Detect changed services
  run: |
    CHANGED_FILES=$(git diff --name-only $BASE_SHA ${{ github.sha }})
    SERVICES=()
    
    # Check each service directory for changes
    for service in services/auth-service services/event-service services/notification-service; do
      service_name=$(basename $service)
      if echo "$CHANGED_FILES" | grep -q "^$service/"; then
        SERVICES+=("\"$service_name\"")
      fi
    done
    
    # If shared libraries changed, rebuild all services
    if echo "$CHANGED_FILES" | grep -qE "^shared/(common-lib|security-lib|messaging-lib)/"; then
      SERVICES=("\"auth-service\"" "\"event-service\"" "\"notification-service\"")
    fi
```

#### Smart Triggering Rules

1. **Service-Specific Changes**: Only rebuild services with modified code
2. **Shared Library Changes**: Rebuild all services when shared dependencies change
3. **Workflow Changes**: Trigger all services when CI/CD files are modified
4. **Environment Detection**: Automatically determine target environment from branch

#### Repository Dispatch Payload

```yaml
- name: Trigger DevOps Pipeline
  run: |
    curl -X POST \
      -H "Authorization: token ${{ secrets.DEVOPS_REPO_TOKEN }}" \
      -H "Accept: application/vnd.github.v3+json" \
      https://api.github.com/repos/${{ secrets.DEVOPS_REPO_OWNER }}/gep-devops/dispatches \
      -d '{
        "event_type": "backend-deployment",
        "client_payload": {
          "repository": "${{ github.repository }}",
          "sha": "${{ github.sha }}",
          "branch": "${{ github.ref_name }}",
          "environment": "${{ needs.detect-changes.outputs.environment }}",
          "services": ${{ needs.detect-changes.outputs.services }},
          "actor": "${{ github.actor }}"
        }
      }'
```

### Frontend Repository Integration

The frontend repository (`event-planner-frontend`) uses a simpler `trigger-devops.yml` workflow that triggers deployments for all frontend changes.

#### Frontend Trigger Workflow

```yaml
# Simple frontend deployment trigger
- name: Repository Dispatch
  uses: peter-evans/repository-dispatch@v2
  with:
    token: ${{ secrets.DEVOPS_REPO_TOKEN }}
    repository: AmaliTech-Training-Academy/gep-devops
    event-type: frontend-deployment
    client-payload: |
      {
        "ref": "${{ github.ref }}",
        "sha": "${{ github.sha }}",
        "repository": "${{ github.repository }}",
        "branch": "${{ github.ref_name }}",
        "environment": "${{ github.ref_name == 'prod' && 'prod' || github.ref_name == 'staging' && 'staging' || 'dev' }}",
        "developer_name": "${{ steps.developer.outputs.name }}",
        "developer_slack_user": "${{ steps.developer.outputs.slack_user }}"
      }
```

#### Frontend vs Backend Triggering

| Aspect | Backend Repository | Frontend Repository |
|--------|-------------------|--------------------|
| **Change Detection** | Intelligent service-level detection | All changes trigger deployment |
| **Complexity** | Advanced git diff analysis | Simple branch-based triggering |
| **Payload** | Dynamic service list | Static frontend deployment |
| **Dependencies** | Shared library awareness | No dependency analysis |
| **Notifications** | Pre and post deployment | Pre-deployment only |

### Benefits of Intelligent Repository Dispatch

1. **Selective Deployments** - Only deploy services that actually changed (backend)
2. **Dependency Awareness** - Rebuild all services when shared libraries change (backend)
3. **Branch-Based Environments** - Automatic environment detection (both)
4. **Developer Tracking** - Captures developer information for notifications (both)
5. **Slack Integration** - Notifies team of deployment triggers (both)

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

---

## Production Blue-Green Deployment Pipelines ⭐ NEW

### Overview

Enterprise-grade blue-green deployment pipelines for production with zero-downtime, canary testing, and automatic rollback.

### Frontend Blue-Green Pipeline

**File**: `frontend-prod-blue-green.yml`

**Workflow Phases**:

1. **Security Scan** (5 min)
   - npm audit for vulnerabilities
   - Fails on critical/high vulnerabilities
   - Uploads reports to S3

2. **Build** (5 min)
   - Production-optimized Angular build
   - Generates unique build ID
   - Artifacts retained 30 days

3. **Deploy Green** (5 min)
   - Deploy to green S3 bucket
   - Invalidate green CloudFront
   - Wait for cache clear

4. **Smoke Tests** (2 min)
   - Health check (10 retries)
   - Performance test (< 2s threshold)

5. **Traffic Switch** (3 min)
   - Backup current blue
   - Update CloudFront origin to green
   - Invalidate production cache

6. **Validation** (2 min)
   - Production health checks
   - Monitor CloudWatch 5xx errors

7. **Promote/Rollback**
   - Success: Sync green to blue
   - Failure: Automatic rollback to blue

**Total Duration**: ~15-30 minutes

### Backend Blue-Green Pipeline

**File**: `backend-prod-blue-green.yml`

**Workflow Phases**:

1. **Security & Build** (15 min)
   - Trivy security scan (CRITICAL/HIGH fails)
   - Maven build with tests
   - Code coverage check (70% threshold)
   - Docker build and ECR push

2. **Deploy Green** (10 min)
   - Create/update green ECS services
   - Deploy 2 tasks per service
   - Wait for service stability

3. **Health Checks** (5 min)
   - Spring Boot actuator endpoints
   - 20 retries, 15s interval
   - Integration tests

4. **Canary Test** (5 min)
   - Route 10% traffic to green
   - Monitor error rates
   - Check CloudWatch metrics

5. **Progressive Traffic Shift** (5 min)
   - 50% traffic (2 min monitoring)
   - 100% traffic to green

6. **Validation** (5 min)
   - Production health checks
   - CloudWatch alarm monitoring
   - 3-minute observation period

7. **Promote/Rollback**
   - Success: Update blue with green task def
   - Failure: Immediate traffic rollback

**Total Duration**: ~35-60 minutes

### Key Features

✅ **Zero-Downtime Deployment**  
✅ **Canary Testing** (10% traffic validation)  
✅ **Progressive Traffic Shifting** (10% → 50% → 100%)  
✅ **Comprehensive Health Checks**  
✅ **Automatic Rollback** (on any failure)  
✅ **Security Scanning** (blocks deployment on vulnerabilities)  
✅ **Code Quality Gates** (70% coverage minimum)  
✅ **CloudWatch Integration**  
✅ **Slack Notifications**  

---

## Next Steps

This covers the CI/CD pipeline implementation. Continue with:

- **Part 4**: Deployment Workflows and Automation (includes blue-green setup)
- **Part 5**: Monitoring, Security, and Operations
- **Part 6**: Cost Optimization and Best Practices