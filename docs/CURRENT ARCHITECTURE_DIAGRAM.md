# Event Planner Platform - Architecture Diagram

## Complete Infrastructure Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                    INTERNET USERS                                        │
│                              (www.sankofagrid.com / api.sankofagrid.com)                │
└──────────────────────────────────────┬──────────────────────────────────────────────────┘
                                       │
                                       │ DNS Resolution
                                       ▼
                    ┌──────────────────────────────────────────┐
                    │         AWS Route53 (DNS)                │
                    │  ┌────────────────┬──────────────────┐   │
                    │  │ Hosted Zone:   │  Nameservers     │   │
                    │  │ sankofagrid.com│  (4 NS records)  │   │
                    │  └────────────────┴──────────────────┘   │
                    │                                           │
                    │  A Records:                               │
                    │  • www.sankofagrid.com → CloudFront      │
                    │  • api.sankofagrid.com → ALB             │
                    └──────────┬────────────────┬───────────────┘
                               │                │
                    ┌──────────┘                └──────────────┐
                    │                                          │
                    ▼ Frontend Traffic                         ▼ Backend Traffic
    ┌───────────────────────────────┐          ┌──────────────────────────────────┐
    │   Amazon CloudFront (CDN)     │          │  Application Load Balancer (ALB) │
    │   Distribution ID: E2ZC4BU... │          │  Internet-facing                 │
    │                               │          │                                  │
    │   • Global Edge Locations     │          │  Listeners:                      │
    │   • HTTPS (SSL/TLS)           │          │  • HTTP:80  → Redirect to HTTPS  │
    │   • Origin Access Control     │          │  • HTTPS:443 → Target Groups     │
    │   • Cache Behaviors           │          │                                  │
    │   • Security Headers          │          │  Path-based Routing:             │
    │   • SPA URL Rewriting         │          │  /api/auth/*    → Auth TG        │
    │                               │          │  /api/events/*  → Event TG       │
    └───────────┬───────────────────┘          │  /api/bookings/* → Booking TG    │
                │                              │  /api/payments/* → Payment TG    │
                │ Origin Request               └──────────┬───────────────────────┘
                ▼                                         │
    ┌───────────────────────────────┐                    │
    │   Amazon S3                   │                    │
    │   event-planner-dev-assets    │                    │
    │                               │                    │
    │   /event-planner/browser/     │                    │
    │   ├── index.html              │                    │
    │   ├── main-*.js               │                    │
    │   ├── styles-*.css            │                    │
    │   └── assets/                 │                    │
    │                               │                    │
    │   Features:                   │                    │
    │   • Versioning: Disabled      │                    │
    │   • Encryption: AES256        │                    │
    │   • Bucket Policy: CloudFront │                    │
    └───────────────────────────────┘                    │
                                                          │
                                                          ▼
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                  AWS VPC (10.0.0.0/16)                                   │
│                                  Region: eu-west-1                                       │
│                                                                                          │
│  ┌────────────────────────────────────────────────────────────────────────────────────┐ │
│  │                         Availability Zone: eu-west-1a                               │ │
│  │                                                                                     │ │
│  │  ┌─────────────────────────────────────────────────────────────────────────────┐  │ │
│  │  │  Public Subnet (10.0.1.0/24)                                                 │  │ │
│  │  │                                                                              │  │ │
│  │  │  ┌──────────────────┐         ┌──────────────────┐                         │  │ │
│  │  │  │  Internet Gateway│         │   NAT Gateway    │                         │  │ │
│  │  │  │   (IGW)          │         │   + Elastic IP   │                         │  │ │
│  │  │  └──────────────────┘         └──────────────────┘                         │  │ │
│  │  │           ▲                            ▲                                    │  │ │
│  │  │           │                            │                                    │  │ │
│  │  │  ┌────────┴────────────────────────────┴──────────┐                        │  │ │
│  │  │  │     ALB (in public subnet)                     │                        │  │ │
│  │  │  │     Security Group: Allow 80, 443 from 0.0.0.0 │                        │  │ │
│  │  │  └────────────────────────────────────────────────┘                        │  │ │
│  │  └──────────────────────────────────────────────────────────────────────────┘  │ │
│  │                                                                                  │ │
│  │  ┌─────────────────────────────────────────────────────────────────────────────┐  │ │
│  │  │  Private Application Subnet (10.0.11.0/24)                                  │  │ │
│  │  │                                                                              │  │ │
│  │  │  ┌────────────────────────────────────────────────────────────────────┐    │  │ │
│  │  │  │              ECS Fargate Cluster                                   │    │  │ │
│  │  │  │              event-planner-dev-cluster                             │    │  │ │
│  │  │  │                                                                     │    │  │ │
│  │  │  │  ┌──────────────────────────────────────────────────────────────┐ │    │  │ │
│  │  │  │  │  ECS Services (Fargate Tasks)                                │ │    │  │ │
│  │  │  │  │                                                               │ │    │  │ │
│  │  │  │  │  ┌─────────────────┐  ┌─────────────────┐                   │ │    │  │ │
│  │  │  │  │  │  Auth Service   │  │  Event Service  │                   │ │    │  │ │
│  │  │  │  │  │  Port: 8081     │  │  Port: 8082     │                   │ │    │  │ │
│  │  │  │  │  │  CPU: 256       │  │  CPU: 256       │                   │ │    │  │ │
│  │  │  │  │  │  Memory: 512MB  │  │  Memory: 512MB  │                   │ │    │  │ │
│  │  │  │  │  └─────────────────┘  └─────────────────┘                   │ │    │  │ │
│  │  │  │  │                                                               │ │    │  │ │
│  │  │  │  │  ┌─────────────────┐  ┌─────────────────┐                   │ │    │  │ │
│  │  │  │  │  │ Booking Service │  │ Payment Service │                   │ │    │  │ │
│  │  │  │  │  │  Port: 8083     │  │  Port: 8084     │                   │ │    │  │ │
│  │  │  │  │  │  CPU: 256       │  │  CPU: 256       │                   │ │    │  │ │
│  │  │  │  │  │  Memory: 512MB  │  │  Memory: 512MB  │                   │ │    │  │ │
│  │  │  │  │  └─────────────────┘  └─────────────────┘                   │ │    │  │ │
│  │  │  │  │                                                               │ │    │  │ │
│  │  │  │  │  ┌─────────────────────────────┐                             │ │    │  │ │
│  │  │  │  │  │  Notification Service       │                             │ │    │  │ │
│  │  │  │  │  │  Port: 8085                 │                             │ │    │  │ │
│  │  │  │  │  │  CPU: 256, Memory: 512MB    │                             │ │    │  │ │
│  │  │  │  │  └─────────────────────────────┘                             │ │    │  │ │
│  │  │  │  │                                                               │ │    │  │ │
│  │  │  │  │  Security Group: Allow 8081-8085 from ALB                    │ │    │  │ │
│  │  │  │  └───────────────────────────────────────────────────────────────┘ │    │  │ │
│  │  │  │                                                                     │    │  │ │
│  │  │  │  Service Discovery (AWS Cloud Map):                                │    │  │ │
│  │  │  │  • auth-service.eventplanner.local:8081                            │    │  │ │
│  │  │  │  • event-service.eventplanner.local:8082                           │    │  │ │
│  │  │  │  • booking-service.eventplanner.local:8083                         │    │  │ │
│  │  │  │  • payment-service.eventplanner.local:8084                         │    │  │ │
│  │  │  │  • notification-service.eventplanner.local:8085                    │    │  │ │
│  │  │  └─────────────────────────────────────────────────────────────────────┘    │  │ │
│  │  └──────────────────────────────────────────────────────────────────────────────┘  │ │
│  │                                                                                     │ │
│  │  ┌─────────────────────────────────────────────────────────────────────────────┐  │ │
│  │  │  Private Data Subnet (10.0.21.0/24)                                         │  │ │
│  │  │                                                                              │  │ │
│  │  │  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐         │  │ │
│  │  │  │  RDS PostgreSQL  │  │   DocumentDB     │  │  ElastiCache     │         │  │ │
│  │  │  │                  │  │   (MongoDB)      │  │   (Redis)        │         │  │ │
│  │  │  │  • auth-db       │  │                  │  │                  │         │  │ │
│  │  │  │  • event-db      │  │  Cluster:        │  │  Cluster Mode:   │         │  │ │
│  │  │  │  • booking-db    │  │  1 instance      │  │  Disabled (dev)  │         │  │ │
│  │  │  │  • payment-db    │  │  db.t3.medium    │  │  cache.t3.micro  │         │  │ │
│  │  │  │                  │  │                  │  │                  │         │  │ │
│  │  │  │  Instance:       │  │  Port: 27017     │  │  Port: 6379      │         │  │ │
│  │  │  │  db.t3.medium    │  │  TLS: Required   │  │  Encryption: Yes │         │  │ │
│  │  │  │  Storage: 20GB   │  │                  │  │                  │         │  │ │
│  │  │  │  Multi-AZ: No    │  │  Use: Audit Logs │  │  Use: Sessions   │         │  │ │
│  │  │  │  Port: 5432      │  │                  │  │       Caching    │         │  │ │
│  │  │  │                  │  │                  │  │                  │         │  │ │
│  │  │  │  SG: Allow 5432  │  │  SG: Allow 27017 │  │  SG: Allow 6379  │         │  │ │
│  │  │  │      from ECS    │  │      from ECS    │  │      from ECS    │         │  │ │
│  │  │  └──────────────────┘  └──────────────────┘  └──────────────────┘         │  │ │
│  │  └──────────────────────────────────────────────────────────────────────────────┘  │ │
│  └─────────────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                          │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │                         VPC Endpoints (Interface & Gateway)                      │   │
│  │                                                                                  │   │
│  │  Gateway Endpoints:                    Interface Endpoints:                     │   │
│  │  • S3 (com.amazonaws.eu-west-1.s3)     • ECR API                               │   │
│  │                                         • ECR Docker                             │   │
│  │                                         • CloudWatch Logs                        │   │
│  │                                         • Secrets Manager                        │   │
│  │                                         • Systems Manager (SSM)                  │   │
│  │                                                                                  │   │
│  │  Purpose: Reduce NAT Gateway costs, improve security                            │   │
│  └──────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                          │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
│  │                         VPC Flow Logs → CloudWatch Logs                          │   │
│  │                         Traffic Type: ALL | Retention: 30 days                   │   │
│  └──────────────────────────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              SUPPORTING AWS SERVICES                                     │
└─────────────────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────┐  ┌──────────────────────────────────┐
│   Amazon ECR (Container Registry)│  │   AWS Secrets Manager            │
│                                  │  │                                  │
│   Repositories:                  │  │   Secrets:                       │
│   • event-planner-dev-auth-svc   │  │   • RDS auth-db credentials      │
│   • event-planner-dev-event-svc  │  │   • RDS event-db credentials     │
│   • event-planner-dev-booking-svc│  │   • RDS booking-db credentials   │
│   • event-planner-dev-payment-svc│  │   • RDS payment-db credentials   │
│   • event-planner-dev-notif-svc  │  │   • DocumentDB credentials       │
│                                  │  │   • JWT signing keys             │
│   Features:                      │  │                                  │
│   • Image Scanning: Enabled      │  │   Auto-rotation: Enabled         │
│   • Lifecycle: Keep 30 images    │  │   Encryption: KMS                │
│   • Encryption: AES256           │  │                                  │
└──────────────────────────────────┘  └──────────────────────────────────┘

┌──────────────────────────────────┐  ┌──────────────────────────────────┐
│   Amazon SQS (Message Queues)    │  │   Amazon SNS (Pub/Sub Topics)    │
│                                  │  │                                  │
│   Queues:                        │  │   Topics:                        │
│   • user-registration            │  │   • event-created                │
│   • user-login                   │  │   • booking-confirmed            │
│   • event-created                │  │   • payment-processed            │
│   • event-updated                │  │   • notification-trigger         │
│   • booking-created              │  │                                  │
│   • booking-cancelled            │  │   Subscriptions:                 │
│   • payment-processed            │  │   • SQS queues                   │
│   • email-notifications          │  │   • Email endpoints              │
│                                  │  │                                  │
│   Encryption: KMS                │  │   Encryption: KMS                │
│   Dead Letter Queue: Enabled     │  │                                  │
└──────────────────────────────────┘  └──────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────┐
│   Amazon CloudWatch (Monitoring & Logging)                               │
│                                                                          │
│   Log Groups:                                                            │
│   • /ecs/event-planner/dev/auth-service                                 │
│   • /ecs/event-planner/dev/event-service                                │
│   • /ecs/event-planner/dev/booking-service                              │
│   • /ecs/event-planner/dev/payment-service                              │
│   • /ecs/event-planner/dev/notification-service                         │
│   • /aws/vpc/flowlogs                                                   │
│                                                                          │
│   Alarms:                                                                │
│   • ECS CPU/Memory High                                                  │
│   • ALB 5xx Errors                                                       │
│   • RDS CPU/Storage/Connections                                          │
│   • ElastiCache CPU/Memory/Evictions                                     │
│                                                                          │
│   Dashboard: event-planner-dev-dashboard                                 │
│   SNS Topic: event-planner-dev-alerts                                    │
└──────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────┐
│   AWS IAM (Identity & Access Management)                                 │
│                                                                          │
│   Roles:                                                                 │
│   • ECS Task Execution Role                                              │
│     - Pull images from ECR                                               │
│     - Write logs to CloudWatch                                           │
│     - Read secrets from Secrets Manager                                  │
│                                                                          │
│   • ECS Task Roles (per service)                                         │
│     - Auth Service: SES, S3, SQS                                         │
│     - Event Service: SNS, S3, SQS                                        │
│     - Booking Service: SNS, SQS                                          │
│     - Payment Service: SNS, SQS                                          │
│     - Notification Service: SES, SNS, SQS                                │
│                                                                          │
│   • VPC Flow Logs Role                                                   │
│     - Write flow logs to CloudWatch                                      │
└──────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              TERRAFORM STATE MANAGEMENT                                  │
└─────────────────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────┐  ┌──────────────────────────────────┐
│   Amazon S3 (State Storage)      │  │   DynamoDB (State Locking)       │
│                                  │  │                                  │
│   Bucket:                        │  │   Table:                         │
│   event-planner-terraform-state  │  │   event-planner-terraform-locks  │
│   -eu-west-1-904570587823        │  │                                  │
│                                  │  │   Purpose:                       │
│   Contents:                      │  │   • Prevent concurrent state     │
│   • dev/terraform.tfstate        │  │     modifications                │
│   • prod/terraform.tfstate       │  │   • Team collaboration           │
│                                  │  │                                  │
│   Features:                      │  │   Attributes:                    │
│   • Versioning: Enabled          │  │   • LockID (Primary Key)         │
│   • Encryption: AES256           │  │   • Info (Lock metadata)         │
│   • Lifecycle: 90-day retention  │  │                                  │
└──────────────────────────────────┘  └──────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              DATA FLOW DIAGRAM                                           │
└─────────────────────────────────────────────────────────────────────────────────────────┘

User Request Flow:
1. User → Route53 (DNS) → CloudFront → S3 (Angular App)
2. Angular App → Route53 (DNS) → ALB → ECS Service
3. ECS Service → RDS/DocumentDB/ElastiCache (Data Layer)
4. ECS Service → SQS/SNS (Async Messaging)
5. Response → User

Service-to-Service Communication:
Auth Service → event-service.eventplanner.local:8082 → Event Service
Event Service → booking-service.eventplanner.local:8083 → Booking Service
Booking Service → payment-service.eventplanner.local:8084 → Payment Service
Payment Service → notification-service.eventplanner.local:8085 → Notification Service

┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              SECURITY ARCHITECTURE                                       │
└─────────────────────────────────────────────────────────────────────────────────────────┘

Network Security:
├── Public Subnets: ALB only (internet-facing)
├── Private App Subnets: ECS tasks (no direct internet)
├── Private Data Subnets: Databases (most isolated)
├── Security Groups: Least privilege (specific ports/sources)
└── NACLs: Default (allow all within VPC)

Data Security:
├── Encryption at Rest: RDS, DocumentDB, ElastiCache, S3, EBS
├── Encryption in Transit: TLS/SSL everywhere
├── Secrets Management: AWS Secrets Manager (no hardcoded credentials)
└── KMS Keys: AWS-managed (can be customer-managed for compliance)

Access Control:
├── IAM Roles: Least privilege per service
├── No IAM Users: Use roles and temporary credentials
├── MFA: Required for console access (recommended)
└── CloudTrail: Audit all API calls (recommended for prod)

Application Security:
├── WAF: Optional (can be added to CloudFront/ALB)
├── Security Headers: CSP, HSTS, X-Frame-Options
├── Container Scanning: ECR image scanning enabled
└── VPC Flow Logs: Network traffic monitoring

┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              COST BREAKDOWN (Development)                                │
└─────────────────────────────────────────────────────────────────────────────────────────┘

Monthly Costs (24/7 operation):
├── NAT Gateway: $32/month (1 gateway) + data transfer
├── RDS (4 x db.t3.medium): ~$120/month
├── DocumentDB (1 x db.t3.medium): ~$60/month
├── ElastiCache (1 x cache.t3.micro): ~$12/month
├── ALB: ~$16/month + LCU charges
├── ECS Fargate (5 services): ~$8/month (0.25 vCPU, 512MB each)
├── S3: ~$1/month (storage + requests)
├── CloudFront: ~$1/month (low traffic)
├── Route53: ~$0.50/month (hosted zone)
├── CloudWatch Logs: ~$5/month
├── VPC Endpoints: ~$7/month (5 endpoints)
├── Data Transfer: ~$5-20/month
└── Total: ~$248-268/month

Cost Optimization Opportunities:
├── Stop environment after hours: Save ~60% (~$100/month)
├── Use Fargate Spot: Save ~70% on compute (~$5/month)
├── Reserved Instances (RDS): Save ~40% (~$48/month)
├── VPC Endpoints: Already implemented (saves ~$15/month on NAT)
└── S3 Lifecycle Policies: Already implemented

┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              HIGH AVAILABILITY (Production)                              │
└─────────────────────────────────────────────────────────────────────────────────────────┘

Multi-AZ Deployment:
├── 2 Availability Zones (eu-west-1a, eu-west-1b)
├── 2 NAT Gateways (one per AZ)
├── ALB across multiple AZs
├── ECS tasks distributed across AZs
├── RDS Multi-AZ (automatic failover)
├── DocumentDB cluster (3 instances across AZs)
└── ElastiCache cluster mode (automatic failover)

Auto Scaling:
├── ECS: CPU/Memory-based scaling (2-10 tasks per service)
├── RDS: Storage auto-scaling (100GB → 1TB)
└── ALB: Automatic scaling (AWS-managed)

Backup & Recovery:
├── RDS: Automated backups (7-day retention), point-in-time recovery
├── DocumentDB: Automated backups (7-day retention)
├── S3: Versioning enabled, lifecycle policies
└── Terraform State: S3 versioning enabled

Monitoring & Alerting:
├── CloudWatch Alarms: CPU, memory, errors, latency
├── SNS Notifications: Email alerts to DevOps team
├── CloudWatch Dashboard: Real-time metrics
└── VPC Flow Logs: Network traffic analysis

┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              DEPLOYMENT PIPELINE                                         │
└─────────────────────────────────────────────────────────────────────────────────────────┘

Infrastructure Deployment (Terraform):
1. Developer commits to git
2. GitHub Actions triggered
3. Terraform plan executed
4. Manual approval (prod only)
5. Terraform apply executed
6. Infrastructure updated

Application Deployment (Docker):
1. Developer commits code
2. GitHub Actions builds Docker image
3. Image pushed to ECR
4. ECS service updated with new image
5. Rolling deployment (zero downtime)
6. Health checks validate deployment
7. Automatic rollback on failure

Current State:
├── Infrastructure: Deployed via Terraform
├── State: Stored in S3 with DynamoDB locking
├── Frontend: Angular app in S3, served via CloudFront
├── Backend: Ready for Docker images (ECR repositories created)
└── Databases: Provisioned and ready for connections

Next Steps:
1. Build and push Docker images to ECR
2. ECS will automatically pull and run containers
3. Configure custom domain SSL certificates (ACM)
4. Update Route53 with custom domain records
5. Test end-to-end functionality
