# VPC Endpoint Changes
 

This report documents the infrastructure changes made to optimize costs by replacing VPC endpoints with a NAT Gateway for AWS service connectivity. The change resulted in **~$92-112/month savings** while maintaining security and functionality.

## Current Configuration

- **VPC Endpoints**: `enable_vpc_endpoints = false` (DISABLED)
- **NAT Gateway**: `enable_nat_gateway = true` (ENABLED)
- **Single NAT Gateway**: `single_nat_gateway = true` (Cost optimization)

## VPC Endpoints Previously Available (Now Removed)

### Interface Endpoints (Removed)

| Endpoint | Service Name | Purpose | Monthly Cost |
|----------|--------------|---------|--------------|
| **ECR API** | `com.amazonaws.eu-west-1.ecr.api` | Pull container images from ECR | ~$22 |
| **ECR Docker** | `com.amazonaws.eu-west-1.ecr.dkr` | Docker registry operations | ~$22 |
| **CloudWatch Logs** | `com.amazonaws.eu-west-1.logs` | Send application logs to CloudWatch | ~$22 |
| **Secrets Manager** | `com.amazonaws.eu-west-1.secretsmanager` | Retrieve database passwords and API keys | ~$22 |
| **Systems Manager** | `com.amazonaws.eu-west-1.ssm` | Parameter store access | ~$22 |
| **SQS** | `com.amazonaws.eu-west-1.sqs` | Message queue operations | ~$22 |
| **SNS** | `com.amazonaws.eu-west-1.sns` | Pub/sub messaging | ~$22 |

**Total Interface Endpoints Cost**: ~$154/month

### Gateway Endpoint (Still Active)

| Endpoint | Service Name | Purpose | Monthly Cost |
|----------|--------------|---------|--------------|
| **S3 Gateway** | `com.amazonaws.eu-west-1.s3` | Access S3 buckets for frontend assets and logs | **FREE** |

## NAT Gateway Current Role

### What NAT Gateway Now Handles

1. **Container Image Pulls**: ECS pulls images from ECR via NAT Gateway
2. **AWS Service Access**: All AWS API calls (Secrets Manager, CloudWatch, SQS, SNS)
3. **External SMTP**: Notification service sends emails via Gmail SMTP
4. **Software Updates**: OS and application updates
5. **Third-party APIs**: External service integrations

### NAT Gateway Costs

| Component | Monthly Cost | Description |
|-----------|--------------|-------------|
| **Hourly Charge** | ~$32 | 24/7 operation |
| **Data Transfer** | ~$10-30 | Depending on usage |
| **Total** | ~$42-62 | Combined NAT Gateway costs |

## Cost Impact Analysis

| Item | Before | After | Savings |
|------|--------|-------|---------|
| **VPC Endpoints** | $154/month | $0/month | +$154 |
| **NAT Gateway** | $0/month | $42-62/month | -$42-62 |
| **Net Savings** | - | - | **$92-112/month** |

## Trade-offs Analysis

###  Benefits
- **Significant Cost Reduction**: $92-112/month savings
- **Simplified Architecture**: Single NAT Gateway vs 7 VPC endpoints
- **External Connectivity**: Required for SMTP and third-party services
- **Maintained Security**: Traffic still encrypted, private subnets protected

###  Considerations
- **Latency**: Minimal increase (internet routing vs AWS backbone)
- **Single Point of Failure**: One NAT Gateway for cost optimization
- **Data Transfer Costs**: Variable based on usage patterns

## Security Posture

### Maintained Security Features
- **Private Subnets**: Applications remain in private subnets
- **Encrypted Traffic**: All AWS API calls use HTTPS/TLS
- **Security Groups**: Firewall rules still enforced
- **No Direct Internet Access**: Applications cannot receive inbound internet traffic

### Network Flow
```
ECS Tasks (Private Subnet) → NAT Gateway (Public Subnet) → Internet Gateway → AWS Services
```

## Recommendations

### Development Environment
-  **Current setup is optimal** for cost-conscious development
-  **Single NAT Gateway** appropriate for non-critical workloads
-  **Monitor data transfer costs** to ensure savings are maintained

### Production Environment (Future)
-  **Consider Multi-AZ NAT Gateways** for high availability
-  **Evaluate VPC Endpoints** for high-traffic AWS services
-  **Implement cost monitoring** for data transfer optimization

## Implementation Details

### Configuration Changes Made
```hcl
# In terraform/environments/dev/main.tf
module "vpc" {
  # NAT Gateway enabled for external connectivity
  enable_nat_gateway = true   # Required for SMTP and AWS services
  single_nat_gateway = true   # Single NAT for cost optimization
  
  # VPC Endpoints disabled for cost optimization
  enable_vpc_endpoints = false # Route all AWS traffic through NAT Gateway
}
```

### Services Affected
- **ECS Tasks**: Now pull images via NAT Gateway
- **Notification Service**: SMTP traffic routes through NAT Gateway
- **All Microservices**: AWS API calls route through NAT Gateway

