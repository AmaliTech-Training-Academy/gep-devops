# Reusable GitHub Actions

This directory contains reusable composite actions for CI/CD pipelines.

## Backend Actions

### checkout-backend
Checks out the backend repository code.

**Inputs:**
- `repository`: Backend repository name
- `ref`: Git ref to checkout
- `token`: GitHub token for authentication

### aws-configure
Configures AWS credentials for AWS CLI and SDK usage.

**Inputs:**
- `aws-access-key-id`: AWS Access Key ID
- `aws-secret-access-key`: AWS Secret Access Key
- `aws-region`: AWS Region

### setup-maven
Sets up Maven environment with caching and clears cache failures.

**No inputs required**

### build-maven
Builds Maven dependencies and the specified service.

**Inputs:**
- `service`: Service name to build

### docker-build-push
Builds and pushes Docker image to ECR.

**Inputs:**
- `service`: Service name
- `environment`: Environment name (dev/staging/prod)
- `commit-sha`: Commit SHA for image tagging
- `ecr-registry`: ECR registry URL

### ecs-deploy
Deploys service to ECS with health checks and stability wait.

**Inputs:**
- `service`: Service name
- `cluster`: ECS cluster name
- `region`: AWS region

## Frontend Actions

### checkout-frontend
Checks out the frontend repository code.

**Inputs:**
- `repository`: Frontend repository name
- `ref`: Git ref to checkout
- `token`: GitHub token for authentication

### setup-node
Sets up Node.js and installs dependencies.

**Inputs:**
- `working-directory`: Working directory (default: 'frontend')

### frontend-build
Builds frontend application.

**Inputs:**
- `environment`: Environment to build for
- `working-directory`: Working directory (default: 'frontend')
- `api-url`: API URL for production (optional)

### s3-deploy
Deploys to S3 and invalidates CloudFront.

**Inputs:**
- `bucket`: S3 bucket name
- `distribution-id`: CloudFront distribution ID
- `source-dir`: Source directory to deploy (default: 'dist/')

## Usage Example

```yaml
# Backend
- uses: ./.github/actions/checkout-backend
  with:
    repository: ${{ env.BACKEND_REPO }}
    ref: ${{ env.COMMIT_SHA }}
    token: ${{ secrets.BACKEND_REPO_TOKEN }}

# Frontend
- uses: ./.github/actions/checkout-frontend
  with:
    repository: ${{ env.FRONTEND_REPO }}
    ref: ${{ env.COMMIT_SHA }}
    token: ${{ secrets.FRONTEND_REPO_TOKEN }}
```
