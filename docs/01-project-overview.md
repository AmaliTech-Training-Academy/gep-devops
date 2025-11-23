# Project Overview

**Last Updated:** November 2025  
**Version:** 2.0.0

## Executive Summary

The Event Planner Platform is a cloud-native microservices application deployed on AWS, implementing a centralized DevOps approach where all infrastructure, CI/CD pipelines, and deployment orchestration are managed from a single repository.

### Key Features

- Centralized DevOps architecture with single source of truth
- Cost-optimized infrastructure (~$150-200/month for development)
- Production-ready Terraform modules for complete AWS infrastructure
- Automated CI/CD pipelines for infrastructure, backend, and frontend
- Service discovery using AWS Cloud Map
- Security-first approach with encryption and secrets management

## Architecture Overview

### High-Level Architecture

The platform follows a microservices architecture with:

- **Frontend**: Angular SPA hosted on S3 + CloudFront (events.sankofagrid.com)
- **Backend**: Java Spring Boot microservices on ECS Fargate (api.sankofagrid.com)
- **Database**: PostgreSQL RDS with multi-schema approach
- **Caching**: ElastiCache Redis for session management
- **Messaging**: SQS/SNS for asynchronous communication
- **Service Discovery**: AWS Cloud Map (eventplanner.local)

### Infrastructure Components

**Frontend Infrastructure:**
- S3 bucket for static website hosting
- CloudFront CDN with SSL certificate
- Domain managed by Cloudflare (events.sankofagrid.com)

**Backend Infrastructure:**
- VPC with public/private subnets
  - Development: Single-AZ (eu-west-1a)
  - Production: Multi-AZ (2 AZs)
- ECS Fargate for serverless containers
- Application Load Balancer with HTTPS
- RDS PostgreSQL with multi-schema design
- ElastiCache Redis for caching
- AWS Cloud Map for service discovery

**Network Architecture:**
- Public subnets: ALB, NAT Gateway
- Private app subnets: ECS tasks
- Private data subnets: RDS, ElastiCache
- VPC endpoints for AWS services

## Centralized DevOps Approach

### Repository Structure

The project uses three main repositories:

1. **get-devops** (This Repository)
   - All Terraform infrastructure code
   - All CI/CD pipeline definitions
   - Configuration management
   - Monitoring and security workflows

2. **Backend Repository**
   - Java Spring Boot microservices
   - Triggers deployments via repository dispatch

3. **Frontend Repository**
   - Angular application
   - Triggers deployments via repository dispatch

### Benefits

- Single source of truth for infrastructure
- Consistent deployments across environments
- Easier maintenance and updates
- Centralized secrets management
- Simplified onboarding for developers

## Active Services

### Currently Running

| Service | Port | Purpose | Database |
|---------|------|---------|----------|
| auth-service | 8081 | User authentication | auth_schema |
| event-service | 8082 | Event management | event_schema |
| payment-service | 8088 | Payment processing | payment_schema |
| notification-service | 8085 | Email/SMS notifications | N/A |

### Service Discovery

Services communicate via AWS Cloud Map:
- auth-service.eventplanner.local:8081
- event-service.eventplanner.local:8082
- payment-service.eventplanner.local:8088
- notification-service.eventplanner.local:8085

## Technology Stack

### Infrastructure
- Terraform v1.5.0+ for infrastructure as code
- AWS as cloud platform
- GitHub Actions for CI/CD

### Cloud Services
- ECS Fargate (compute)
- RDS PostgreSQL (database)
- ElastiCache Redis (caching)
- S3 (storage)
- CloudFront (CDN)
- ALB (load balancing)
- ECR (container registry)
- Secrets Manager (secrets)
- CloudWatch (monitoring)
- SQS/SNS (messaging)

### Application Stack
- Backend: Java 21, Spring Boot 3.x
- Frontend: Angular 17+, TypeScript
- Database: PostgreSQL 15.12
- Cache: Redis 7.1

## Environment Strategy

### Development Environment

**Configuration:**
- Single-AZ deployment
- Minimal resource allocation
- 4 active microservices
- Single PostgreSQL with multi-schema
- Single Redis node

**Cost:** ~$150-200/month

**Deployment:** Automatic on push to main branch

### Production Environment

**Configuration:**
- Multi-AZ deployment (2 AZs)
- High availability setup
- All microservices active
- RDS Multi-AZ with read replicas
- Redis cluster with replicas
- Auto-scaling enabled

**Cost:** ~$800-1200/month

**Deployment:** Manual approval with blue-green deployment

## Key Design Decisions

### Centralized DevOps Repository
Single repository for all infrastructure and CI/CD provides consistency and easier maintenance.

### Multi-Schema PostgreSQL
Single PostgreSQL instance with multiple schemas in development reduces costs while maintaining isolation.

### AWS Cloud Map
DNS-based service discovery enables dynamic service resolution and easier scaling.

### VPC Endpoints
Reduces NAT Gateway data transfer costs by ~$15/month for AWS service traffic.

### Cloudflare DNS
External DNS management provides flexibility and additional security features.

## Security Features

- Encryption at rest and in transit
- AWS Secrets Manager for credential management
- VPC isolation with security groups
- IAM roles with least privilege
- SSL/TLS certificates for all endpoints
- Audit logging in PostgreSQL JSONB format

## Monitoring & Observability

- CloudWatch for infrastructure metrics
- Service-specific dashboards for each microservice
- Grafana for unified monitoring and alerting
- Audit logs stored in PostgreSQL
- Custom alarms for critical metrics

## Next Steps

For detailed information, refer to:
- [Terraform Infrastructure](02-terraform-infrastructure.md)
- [CI/CD Pipeline Implementation](03-cicd-pipeline-implementation.md)
- [Deployment Workflows](04-deployment-workflows.md)
- [Monitoring & Security Operations](05-monitoring-security-operations-I.md)
- [Cost Optimization](06-cost-optimization-best-practices.md)
