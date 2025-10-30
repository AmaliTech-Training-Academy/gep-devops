# Event Planner Platform - DevOps Infrastructure Documentation
## Part 1: Project Overview & Architecture

**Author:** DevOps Team  
**Last Updated:** October 30, 2025  
**Version:** 1.0.0  
**Repository:** gep_devops

---

## Executive Summary

This documentation covers the complete DevOps infrastructure implementation for the Event Planner Platform (GEP), a cloud-native microservices application deployed on AWS. The project implements a **centralized DevOps approach** where all infrastructure, CI/CD pipelines, and deployment orchestration are managed from a single repository (`gep_devops`), while application code resides in separate repositories.

### Key Achievements

- ✅ **Centralized DevOps Architecture**: Single source of truth for all infrastructure and deployment pipelines
- ✅ **Cost-Optimized Infrastructure**: Development environment running at ~$75-95/month (weekday-only) vs $248/month (24/7)
- ✅ **Production-Ready Terraform Modules**: 15+ reusable modules for complete AWS infrastructure
- ✅ **Automated CI/CD Pipelines**: Separate pipelines for backend (Java/Spring Boot) and frontend (Angular)
- ✅ **Self-Hosted Runners**: Custom GitHub Actions runners with pre-installed tools for faster builds
- ✅ **Service Discovery**: AWS Cloud Map integration for microservices communication
- ✅ **Selective Deployment**: Deploy only changed services to reduce deployment time and costs
- ✅ **Security-First Approach**: Secrets management, VPC endpoints, encryption at rest and in transit

---

## Architecture Overview

### High-Level Architecture

The Event Planner Platform follows a **microservices architecture** deployed on AWS using:

- **Frontend**: Angular SPA hosted on S3 + CloudFront (events.sankofagrid.com)
- **Backend**: Java Spring Boot microservices on ECS Fargate (api.sankofagrid.com)
- **Database**: PostgreSQL RDS with multi-schema approach
- **Caching**: ElastiCache Redis for session management and caching
- **Messaging**: SQS/SNS for asynchronous communication
- **Service Discovery**: AWS Cloud Map (eventplanner.local namespace)

### Infrastructure Components

#### Frontend Infrastructure
- **S3 Bucket**: Static website hosting for Angular application
- **CloudFront**: Global CDN with custom SSL certificate
- **Domain**: events.sankofagrid.com (external DNS, not Route53)
- **SSL/TLS**: Manual certificate management for CloudFront

#### Backend Infrastructure
- **VPC**: Custom VPC with public/private subnets
  - Development: Single-AZ (eu-west-1a) for cost optimization
  - Production: Multi-AZ (2 AZs) for high availability
- **ECS Fargate**: Serverless container orchestration
  - Currently Active: auth-service, notification-service
  - Ready to Deploy: event-service, booking-service, payment-service
- **Application Load Balancer**: HTTPS traffic routing (api.sankofagrid.com)
- **RDS PostgreSQL**: Multi-schema database approach
  - Currently Active: auth_db
  - Ready to Deploy: event_db, booking_db, payment_db
- **ElastiCache Redis**: Distributed caching and session storage
- **AWS Cloud Map**: DNS-based service discovery (eventplanner.local)

#### Network Architecture
- **Public Subnets**: ALB, NAT Gateway
- **Private App Subnets**: ECS tasks
- **Private Data Subnets**: RDS, ElastiCache
- **NAT Gateway**: Required for external SMTP access (Gmail notifications)
- **VPC Endpoints**: ECR, Secrets Manager, CloudWatch, S3 (saves ~$15/month)

---

## Centralized DevOps Approach

### Repository Structure

The project uses a **centralized DevOps model** with three main repositories:

1. **gep_devops** (This Repository) - Central Control
   - All Terraform infrastructure code
   - All CI/CD pipeline definitions
   - Configuration management
   - Monitoring and security workflows

2. **gep-backend** (External Repository)
   - Java Spring Boot microservices source code
   - Minimal trigger workflow only
   - Triggers deployments via repository_dispatch

3. **event-planner-frontend** (External Repository)
   - Angular application source code
   - Minimal trigger workflow only
   - Triggers deployments via repository_dispatch

### Benefits of Centralized Approach

1. **Single Source of Truth**: All infrastructure and deployment logic in one place
2. **Consistent Deployments**: Same pipeline logic across all environments
3. **Easier Maintenance**: Update pipelines once, affects all services
4. **Better Security**: Centralized secrets management
5. **Cost Optimization**: Shared resources and unified monitoring
6. **Simplified Onboarding**: New developers only need access to app repos

---

## Current Deployment Status

### Active Services (Currently Running)

| Service | Port | CPU | Memory | Status | Database |
|---------|------|-----|--------|--------|----------|
| auth-service | 8081 | 256 | 512MB | ✅ Active | auth_db (PostgreSQL) |
| notification-service | 8085 | 256 | 512MB | ✅ Active | N/A (uses SQS) |

### Ready to Deploy (Infrastructure Provisioned)

| Service | Port | CPU | Memory | Status | Database |
|---------|------|-----|--------|--------|----------|
| event-service | 8082 | 256 | 512MB | 🟡 Ready | event_db (commented in Terraform) |
| booking-service | 8083 | 256 | 512MB | 🟡 Ready | booking_db (commented in Terraform) |
| payment-service | 8084 | 256 | 512MB | 🟡 Ready | payment_db (commented in Terraform) |

**Note**: To activate additional services, uncomment the relevant blocks in:
- `terraform/modules/ecs/main.tf` (ECS service definitions)
- `terraform/modules/rds/main.tf` (Database instances)
- `.github/workflows/backend-ci-cd.yml` (CI/CD pipeline)

---

## Technology Stack

### Infrastructure as Code
- **Terraform**: v1.5.0+ for infrastructure provisioning
- **AWS Provider**: v5.0+ for AWS resource management

### Cloud Platform
- **AWS Services**:
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
  - Cloud Map (service discovery)
  - VPC (networking)

### CI/CD
- **GitHub Actions**: Workflow orchestration
- **Self-Hosted Runners**: Custom runners with pre-installed tools
  - Backend runner: Java 21, Maven, Docker
  - Frontend runner: Node.js 18, npm, AWS CLI

### Application Stack
- **Backend**: Java 21, Spring Boot 3.x, Maven
- **Frontend**: Angular 17+, TypeScript, Node.js 18
- **Database**: PostgreSQL 15.12
- **Cache**: Redis 7.1

---

## Environment Strategy

### Development Environment (Current)
- **Purpose**: Active development and testing
- **Configuration**:
  - Single-AZ deployment (eu-west-1a)
  - Minimal resource allocation
  - 2 active microservices
  - Single PostgreSQL instance (multi-schema)
  - Single Redis node
  - No read replicas
- **Cost**: ~$75-95/month (weekday-only) or ~$248/month (24/7)
- **Auto-Deploy**: Yes (on push to dev branch)

### Staging Environment (Planned)
- **Purpose**: Pre-production testing
- **Configuration**:
  - Multi-AZ deployment (2 AZs)
  - Production-like resources
  - All 5 microservices active
  - Separate databases per service
  - Redis cluster mode
- **Cost**: ~$1,000-1,500/month
- **Auto-Deploy**: No (manual approval required)

### Production Environment (Ready to Deploy)
- **Purpose**: Live customer-facing environment
- **Configuration**:
  - Multi-AZ deployment (2 AZs)
  - High availability setup
  - All 5 microservices active
  - RDS Multi-AZ with read replicas
  - Redis cluster with replicas
  - Auto-scaling enabled
  - Enhanced monitoring
- **Cost**: ~$2,500-3,000/month
- **Auto-Deploy**: No (manual approval + blue-green deployment)

---

## Key Design Decisions

### 1. Centralized DevOps Repository
**Decision**: All infrastructure and CI/CD in one repository  
**Rationale**: Single source of truth, easier maintenance, consistent deployments  
**Trade-off**: Requires repository_dispatch triggers from app repos

### 2. Multi-Schema PostgreSQL vs Multiple Databases
**Decision**: Single PostgreSQL with multiple schemas (dev), separate instances (prod)  
**Rationale**: Cost optimization for dev (~$60/month savings), isolation for prod  
**Trade-off**: Schema management complexity in dev

### 3. Self-Hosted GitHub Runners
**Decision**: Custom runners with pre-installed tools  
**Rationale**: Faster builds (no tool installation), cost savings, better control  
**Trade-off**: Runner maintenance and monitoring required

### 4. Selective Service Deployment
**Decision**: Deploy only changed services  
**Rationale**: Faster deployments, reduced costs, less risk  
**Trade-off**: More complex pipeline logic

### 5. NAT Gateway for Dev Environment
**Decision**: Keep NAT Gateway enabled despite cost  
**Rationale**: Required for external SMTP (Gmail) for notification service  
**Alternative**: VPC Endpoints for AWS services (saves ~$15/month on data transfer)

### 6. AWS Cloud Map for Service Discovery
**Decision**: DNS-based service discovery vs hardcoded URLs  
**Rationale**: Dynamic service resolution, easier scaling, better resilience  
**Trade-off**: Additional AWS service cost (~$1/month per service)

---

## Next Steps

This is Part 1 of the comprehensive documentation. The following parts cover:

- **Part 2**: Terraform Infrastructure Deep Dive
- **Part 3**: CI/CD Pipeline Implementation
- **Part 4**: Deployment Workflows and Automation
- **Part 5**: Monitoring, Security, and Operations
- **Part 6**: Cost Optimization and Best Practices
- **Part 7**: Troubleshooting and Runbooks

---

## Quick Links

- [Centralized DevOps Structure](../centralized-devops-structure.md)
- [Main README](../README.md)
- [Architecture Diagram](../Architecture%20Overview.png)
- [GitHub Repository](https://github.com/AmaliTech-Training-Academy/gep-devops)
