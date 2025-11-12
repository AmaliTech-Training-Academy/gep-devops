# Reusable GitHub Actions

This directory contains reusable composite actions for the backend CI/CD pipeline.

## Available Actions

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

## Usage Example

```yaml
- uses: ./.github/actions/checkout-backend
  with:
    repository: ${{ env.BACKEND_REPO }}
    ref: ${{ env.COMMIT_SHA }}
    token: ${{ secrets.BACKEND_REPO_TOKEN }}
```
