# Event Planner Platform - Network Architecture

## Network Architecture Diagram

```
                                  INTERNET
                                     │
              ┌──────────────────────┼──────────────────────┐
              │                      │                      │
              ▼                      ▼                      ▼
       CloudFront CDN      External DNS (Route53)      Users/Clients
    events.sankofagrid.com   api.sankofagrid.com
              │                      │
              ▼                      ▼
         S3 Bucket            Application Load Balancer
      (Static Assets)              (HTTPS: 443)
                                     │
┌────────────────────────────────────┼────────────────────────────────────┐
│  VPC: 10.0.0.0/16 (eu-west-1)     │                                    │
│                                    │                                    │
│  ┌─────────────────────────────────┼──────────────────────────────┐    │
│  │  Availability Zone: eu-west-1a  │                              │    │
│  │                                 │                              │    │
│  │  ┌──────────────────────────────┼────────────────────────┐    │    │
│  │  │  PUBLIC SUBNET (10.0.1.0/24) │                        │    │    │
│  │  │                              │                        │    │    │
│  │  │  ┌────────────┐             │                        │    │    │
│  │  │  │  Internet  │◄────────────┘                        │    │    │
│  │  │  │  Gateway   │                                      │    │    │
│  │  │  └─────┬──────┘                                      │    │    │
│  │  │        │                                             │    │    │
│  │  │  ┌─────▼──────┐    ┌──────────────┐                │    │    │
│  │  │  │    ALB     │    │ NAT Gateway  │                │    │    │
│  │  │  │ Port 80/443│    │ (Enabled)    │                │    │    │
│  │  │  └─────┬──────┘    └──────┬───────┘                │    │    │
│  │  └────────┼──────────────────┼────────────────────────┘    │    │
│  │           │                  │                              │    │
│  │  ┌────────┼──────────────────┼────────────────────────┐    │    │
│  │  │  PRIVATE APP SUBNET (10.0.10.0/24)                 │    │    │
│  │  │        │                  │                         │    │    │
│  │  │  ┌─────▼──────────────────▼──────────────┐         │    │    │
│  │  │  │   ECS Fargate Cluster                 │         │    │    │
│  │  │  │   (4 Microservices)                   │         │    │    │
│  │  │  │   Auth, Event, Notification, Payment  │         │    │    │
│  │  │  │   Ports: 8081-8085                    │         │    │    │
│  │  │  │   Service Discovery: eventplanner.local│        │    │    │
│  │  │  └───────────────────────────────────────┘         │    │    │
│  │  └─────────────────────────────────────────────────────┘    │    │
│  │                                                              │    │
│  │  ┌─────────────────────────────────────────────────────┐    │    │
│  │  │  PRIVATE DATA SUBNET (10.0.20.0/24)                 │    │    │
│  │  │                                                      │    │    │
│  │  │  ┌──────────────┐    ┌──────────────┐              │    │    │
│  │  │  │     RDS      │    │ ElastiCache  │              │    │    │
│  │  │  │  PostgreSQL  │    │    Redis     │              │    │    │
│  │  │  │ db.t3.medium │    │cache.t3.micro│              │    │    │
│  │  │  │  Port: 5432  │    │  Port: 6379  │              │    │    │
│  │  │  └──────────────┘    └──────────────┘              │    │    │
│  │  └─────────────────────────────────────────────────────┘    │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │  Availability Zone: eu-west-1b                               │    │
│  │  - Public Subnet (10.0.2.0/24): ALB Multi-AZ                 │    │
│  │  - Private App Subnet (10.0.11.0/24): ECS Ready              │    │
│  │  - Private Data Subnet (10.0.21.0/24): RDS Multi-AZ Ready    │    │
│  └──────────────────────────────────────────────────────────────┘    │
└───────────────────────────────────────────────────────────────────────┘

                    AWS Services (External Access)
        ┌──────────┬──────────┬──────────┬──────────┬──────────┐
        │   ECR    │CloudWatch│   SQS    │   SNS    │    S3    │
        │ Registry │   Logs   │  Queues  │  Topics  │  Buckets │
        └──────────┴──────────┴──────────┴──────────┴──────────┘
                    (via NAT Gateway + S3 Gateway Endpoint)
```

## Key Components

**Region:** eu-west-1  
**VPC CIDR:** 10.0.0.0/16  
**Primary AZ:** eu-west-1a (Active)  
**Secondary AZ:** eu-west-1b (Standby)

**Public Subnets:** Internet Gateway, ALB (HTTPS), NAT Gateway  
**Private App Subnets:** ECS Fargate (2 active services), VPC Endpoints  
**Private Data Subnets:** RDS PostgreSQL (db.t3.medium), ElastiCache Redis

**Frontend:** CloudFront CDN → S3 (events.sankofagrid.com)  
**Backend:** External DNS → ALB → ECS Services (api.sankofagrid.com)

**Active Services:** Auth (8081), Event (8082), Notification (8085), Payment (8084)  
**Service Discovery:** eventplanner.local namespace

**Connectivity:** NAT Gateway for external access, S3 Gateway Endpoint for cost optimization
