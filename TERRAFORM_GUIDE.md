# AWS Infrastructure as Code - Fullstack Docker Project

This document describes the production-grade AWS infrastructure setup using Terraform for the fullstack-docker-project.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Internet (0.0.0.0/0)                         │
└────────────────────────────┬────────────────────────────────────┘
                             │ HTTP/HTTPS :80/:443
                             ▼
                    ┌────────────────┐
                    │  AWS ALB       │
                    │ Public Subnet  │
                    └────┬───────┬──┘
              ┌──────────┘       └──────────┐
              │                             │
              ▼                             ▼
    ┌──────────────────┐         ┌──────────────────┐
    │ Frontend Service │         │ Backend Service  │
    │  ECS Fargate     │         │  ECS Fargate     │
    │ Private Subnet   │         │ Private Subnet   │
    └──────────────────┘         └────┬────────┬───┘
                                      │        │
                    ┌─────────────────┘        └──────────────┐
                    │                                         │
                    ▼                                         ▼
            ┌──────────────┐                         ┌──────────────┐
            │ RDS          │                         │ ElastiCache  │
            │ PostgreSQL   │                         │ Redis        │
            │ Multi-AZ     │                         │ Multi-Node   │
            │ Private      │                         │ Private      │
            └──────────────┘                         └──────────────┘
```

## Infrastructure Components

### 1. **VPC (Virtual Private Cloud)**
- CIDR: `10.0.0.0/16` (configurable)
- **Public Subnets** (2): ALB placed here, routable to internet via IGW
- **Private Subnets** (2): ECS tasks, RDS, ElastiCache, only outbound via NAT
- **NAT Gateways**: One per AZ for HA and redundancy
- **Route Tables**: Separate for public (→ IGW) and private (→ NAT)

### 2. **ECS Fargate Cluster**
- **Cluster Name**: `fullstack-docker-{env}` (dev/staging/prod)
- **Capacity Providers**: FARGATE (on-demand) + FARGATE_SPOT (cost-optimized)
- **Container Insights**: Enabled for advanced monitoring
- **Services**:
  - **Backend**: 256 CPU, 512 MB memory (configurable per env)
  - **Frontend**: 256 CPU, 512 MB memory (configurable per env)

### 3. **Application Load Balancer (ALB)**
- **Port 80**: HTTP listener (no HTTPS in dev, configure ACM in prod)
- **Routing**:
  - `/` → Frontend (port 5000)
  - `/api/*` → Backend (port 8080)
- **Health Checks**:
  - Frontend: GET `/` expecting 200
  - Backend: GET `/ping` expecting 200

### 4. **RDS PostgreSQL**
- **Version**: 13.7 (upgradeable)
- **Instance Class**: `db.t3.micro` (dev), `db.t3.small+` (prod)
- **Storage**: 20 GB (dev), expandable (prod)
- **Backups**: 7-day retention (configurable)
- **Multi-AZ**: `false` (dev), `true` (prod)
- **Encryption**: At-rest (KMS) enabled
- **Secrets Manager**: Password securely stored

### 5. **ElastiCache Redis**
- **Version**: 7.0 (configurable)
- **Node Type**: `cache.t3.micro` (dev), `cache.t3.small+` (prod)
- **Encryption**: At-rest + in-transit enabled
- **Auth Token**: Generated and stored in Secrets Manager
- **CloudWatch Logs**: Integrated for troubleshooting

### 6. **Security Groups**
- **ALB SG**: Inbound 80, 443 from `0.0.0.0/0`
- **ECS SG**: Inbound 5000 (frontend), 8080 (backend) from ALB only
- **RDS SG**: Inbound 5432 from ECS only
- **Redis SG**: Inbound 6379 from ECS only

### 7. **IAM Roles & Policies**
- **ECS Task Execution Role**:
  - Pulls images from ECR
  - Writes logs to CloudWatch
  - Accesses Secrets Manager for DB/Redis credentials
- **Backend Task Role**: Can be extended for S3, DynamoDB access
- **Frontend Task Role**: Minimal permissions

### 8. **Auto Scaling**
- **Backend Auto Scaling Policies**:
  - Target CPU: 70% (scales up/down)
  - Target Memory: 75% (scales up/down)
  - Min tasks: 1, Max tasks: 2 (dev), 5 (prod)
  - Scale-up delay: ~60s, Scale-down delay: ~300s

### 9. **CloudWatch Monitoring**
- **Log Groups**:
  - `/ecs/fullstack-docker-{env}-backend` (7-day retention)
  - `/ecs/fullstack-docker-{env}-frontend` (7-day retention)
- **Alarms**:
  - Backend CPU > 80%
  - Backend Memory > 80%
  - RDS CPU > 80% (can be added)
  - ALB target health (can be added)

## Environment Configuration

### Directory Structure
```
terraform/
├── main.tf                    # Root configuration
├── variables.tf              # Input variables
├── outputs.tf               # Output values
├── modules/
│   ├── vpc/                 # VPC & subnets
│   ├── ecr/                 # ECR repositories
│   ├── rds/                 # RDS PostgreSQL
│   ├── redis/               # ElastiCache Redis
│   ├── alb/                 # Application Load Balancer
│   ├── security_groups/     # Security groups
│   ├── ecs/                 # ECS cluster
│   ├── ecs_service/         # ECS services (backend/frontend)
│   ├── iam/                 # IAM roles & policies
│   ├── cloudwatch/          # CloudWatch logs & alarms
│   └── autoscaling/         # Auto scaling policies
└── environments/
    ├── dev/
    │   └── terraform.tfvars  # Dev environment variables
    ├── staging/
    │   └── terraform.tfvars  # Staging environment variables
    └── prod/
        └── terraform.tfvars  # Production environment variables
```

### Environment Variables (terraform.tfvars)

**Dev Environment**:
- 1 backend task, 1 frontend task
- db.t3.micro, cache.t3.micro (cost-optimized)
- 7-day backup retention
- Multi-AZ: false

**Staging Environment**:
- 2 backend tasks, 2 frontend tasks
- db.t3.small, cache.t3.small
- 7-day backup retention
- Multi-AZ: true (recommended)

**Production Environment**:
- Min 2, Max 5+ backend tasks
- db.t3.large, cache.t3.medium
- 30+ day backup retention
- Multi-AZ: true (required)

## Deployment Instructions

### Prerequisites
1. AWS CLI v2 configured with credentials
2. Terraform 1.0+
3. Docker for building images
4. GitHub repository with Actions enabled

### Local Deployment (Dev)

```bash
cd terraform/environments/dev

# Initialize Terraform (one-time)
terraform init

# Plan changes (review)
terraform plan -out=tfplan

# Apply changes
terraform apply tfplan

# Get outputs
terraform output
```

### CI/CD Deployment (GitHub Actions)

**Triggered on**: `push` to `main` (production) or `develop` (staging)

**Pipeline stages**:
1. **CI** (`.github/workflows/ci.yml`):
   - Lint code (golangci-lint, eslint)
   - Run tests (Go, React)
   - Validate Terraform
   - Security scanning (Trivy)

2. **CD** (`.github/workflows/cd.yml`):
   - Build Docker images
   - Push to ECR
   - Terraform plan/apply
   - Smoke tests (health checks)
   - Deployment notifications

**Secrets required** in GitHub:
- `AWS_ROLE_ARN`: IAM role for OIDC federation
- `AWS_REGION`: AWS region (default: us-east-1)
- `TF_STATE_BUCKET`: S3 bucket for Terraform state

## Scaling & Cost Optimization

### Auto Scaling Behavior
- **Scale Up**: When CPU/Memory > target for 2 minutes
- **Scale Down**: When CPU/Memory < target for 5 minutes (prevents thrashing)
- **Min/Max Tasks**: Configured per environment in `terraform.tfvars`

### Cost Optimization Strategies
1. **FARGATE_SPOT**: Use for non-critical workloads (up to 70% savings)
2. **Reserved Capacity**: Consider for production baselines
3. **Scheduled Scaling**: Scale down during off-hours (not implemented yet)
4. **RDS Backup**: Adjust retention policy to balance cost vs. recovery
5. **Log Retention**: Set appropriate CloudWatch retention (default: 7 days)

### Estimated Monthly Costs (Dev Environment)
- ECS Fargate (2x micro): ~$15
- RDS t3.micro: ~$20
- ElastiCache t3.micro: ~$15
- ALB: ~$16
- Data transfer: ~$5
- **Total: ~$70/month** (rough estimate)

## Troubleshooting

### Services Not Reaching Healthy State
```bash
# Check ECS task logs
aws ecs describe-tasks --cluster fullstack-docker-dev --tasks <task-arn> --query 'tasks[0].containerInstanceArn'
aws logs tail /ecs/fullstack-docker-dev-backend --follow

# Check ALB target health
aws elbv2 describe-target-health --target-group-arn <tg-arn>
```

### Database Connection Failures
```bash
# Verify security group rules
aws ec2 describe-security-groups --group-ids <rds-sg-id>

# Check RDS endpoint
aws rds describe-db-instances --db-instance-identifier fullstack-docker-dev-postgres
```

### Terraform State Issues
```bash
# Pull latest state
terraform refresh

# Show state
terraform show

# Debug
TF_LOG=DEBUG terraform plan
```

## Security Considerations

1. **Secrets Management**: Use AWS Secrets Manager for DB/Redis credentials
2. **Network Isolation**: Private subnets for RDS/Redis, ALB-only traffic to ECS
3. **IAM Least Privilege**: Task roles have minimal required permissions
4. **Encryption**: RDS and Redis encryption enabled by default
5. **HTTPS/SSL**: Configure ACM certificates in production
6. **VPC Endpoints**: Consider for private ECR, S3 access (cost tradeoff)
7. **WAF**: Consider AWS WAF on ALB for DDoS protection (production)

## Next Steps

- [ ] Set up remote Terraform state (S3 + DynamoDB)
- [ ] Configure HTTPS with AWS Certificate Manager
- [ ] Add backup/disaster recovery strategy
- [ ] Implement cross-region replication
- [ ] Set up cost monitoring with AWS Budgets
- [ ] Enable AWS Config for compliance
- [ ] Implement X-Ray tracing in backend
- [ ] Add automated performance testing
