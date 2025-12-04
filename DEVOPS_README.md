# Fullstack Docker Project - Production DevOps Setup

> **Transform your Docker learning project into a production-grade, scalable AWS infrastructure using Terraform, ECS, CI/CD, and more.**

## 🎯 What This Project Demonstrates

This repository showcases **enterprise-grade DevOps practices** applied to a fullstack application:

✅ **Infrastructure as Code (IaC)** - Complete AWS infrastructure defined in Terraform  
✅ **Containerization** - Multi-stage Docker builds for Go backend & React frontend  
✅ **CI/CD Pipeline** - GitHub Actions for automated testing, building, and deployment  
✅ **Auto Scaling** - ECS service auto-scaling based on CPU/memory metrics  
✅ **High Availability** - Multi-AZ deployment, RDS Multi-AZ, load balancing  
✅ **Observability** - CloudWatch logs, metrics, alarms, container insights  
✅ **Security** - Security groups, IAM least privilege, secrets management, encrypted storage  
✅ **Cost Optimization** - Fargate Spot, configurable resource sizing, monitoring  

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    GitHub Actions CI/CD                         │
│  (Lint → Test → Build → Push → Terraform → Deploy → Smoke Test)│
└────────────────────────────┬────────────────────────────────────┘
                             │
                    ┌────────▼─────────┐
                    │   AWS ECS        │
                    │   Fargate        │
                    │   Cluster        │
                    └────┬───────┬────┘
          ┌─────────────┘       └──────────────┐
          │                                    │
          ▼                                    ▼
    ┌──────────────┐                   ┌──────────────┐
    │  Frontend    │                   │  Backend     │
    │  React       │ ◄────ALB────►    │  Go/Gin      │
    └──────────────┘                   └────┬────┬───┘
                                           │    │
                        ┌──────────────────┘    └─────────┐
                        │                                 │
                        ▼                                 ▼
                ┌──────────────────┐           ┌──────────────────┐
                │  RDS PostgreSQL  │           │ ElastiCache      │
                │  Multi-AZ        │           │ Redis            │
                └──────────────────┘           └──────────────────┘
```

## 🚀 Quick Start

### Local Development (Docker Compose)

```bash
# Start the stack locally
docker-compose up --build

# Access services
Frontend: http://localhost:5000
Backend:  http://localhost:8080
```

### AWS Deployment (Terraform + GitHub Actions)

#### 1. Prerequisites

- AWS Account with credentials configured
- GitHub repository with Actions enabled
- Terraform 1.0+

#### 2. Configure AWS Credentials (GitHub Secrets)

Go to **Settings → Secrets and variables → Actions**:

```
AWS_ROLE_ARN       = arn:aws:iam::YOUR_ACCOUNT:role/github-actions-role
AWS_REGION         = us-east-1
TF_STATE_BUCKET    = your-terraform-state-bucket
```

#### 3. Deploy via Push

```bash
git push origin main      # Deploys to production
git push origin develop   # Deploys to dev environment
```

#### 4. Or Deploy Manually

```bash
# Initialize Terraform
cd terraform/environments/dev
terraform init

# Plan changes
terraform plan -out=tfplan

# Apply changes
terraform apply tfplan

# Get outputs (ALB DNS, log groups, etc.)
terraform output
```

## 📊 Key Features

### 1. **Infrastructure as Code**

- **Modular design**: VPC, ECS, RDS, ElastiCache, ALB, IAM, Auto Scaling
- **Environment parity**: Identical `dev`, `staging`, `prod` configurations
- **State management**: Ready for remote S3 backend
- **Variables & outputs**: Comprehensive tfvars for each environment

```bash
# Create infrastructure
make tf-init ENV=dev
make tf-plan ENV=dev
make tf-apply ENV=dev

# Clean up
make tf-destroy ENV=dev
```

### 2. **CI/CD Pipeline**

**Trigger**: Push to `main` (production) or `develop` (staging)

**Stages**:
1. **Lint & Test** (`.github/workflows/ci.yml`):
   - Go tests + coverage
   - React build
   - Terraform validation
   - Security scanning (Trivy)

2. **Build & Deploy** (`.github/workflows/cd.yml`):
   - Build Docker images (multi-stage builds)
   - Push to AWS Elastic Container Registry (ECR)
   - Terraform plan/apply (updates ECS task definitions with new ECR image URIs)
   - Smoke tests (health checks)

```bash
# View workflows
cat .github/workflows/ci.yml
cat .github/workflows/cd.yml
```

### 3. **Auto Scaling**

Backend service automatically scales based on:
- **CPU**: Target 70% utilization
- **Memory**: Target 75% utilization
- **Min/Max tasks**: 1-2 (dev), 1-5 (prod)

```bash
# Check scaling policies
aws applicationautoscaling describe-scaling-policies \
  --service-namespace ecs \
  --resource-id service/fullstack-docker-dev/backend
```

### 4. **Observability & Monitoring**

- **CloudWatch Logs**: All ECS container output automatically captured
- **Alarms**: CPU/Memory thresholds with SNS notifications
- **Container Insights**: Advanced metrics and dashboards
- **Structured logging**: (Recommended: implement in Go/React apps)

```bash
# View logs
make logs-backend ENV=dev
make logs-frontend ENV=dev

# View metrics
make metrics-backend ENV=dev
```

### 5. **Security**

- **Network**: Private subnets for data services, ALB-only traffic
- **IAM**: Task roles with least-privilege policies
- **Secrets**: DB passwords & Redis auth tokens in AWS Secrets Manager
- **Encryption**: RDS/Redis at-rest encryption enabled
- **Scanning**: Trivy vulnerability scanning on every build

```bash
# Run security scan
make security-scan
```

## 💰 Cost Estimation

### Monthly Cost Breakdown (Dev)

| Component | Instance | Cost |
|-----------|----------|------|
| ECS Fargate | 2x micro (0.5 vCPU, 512 MB) | ~$15 |
| RDS PostgreSQL | db.t3.micro, 20 GB | ~$20 |
| ElastiCache Redis | cache.t3.micro | ~$15 |
| ALB | 1x ALB, 1 rule | ~$16 |
| NAT Gateway | 2x (HA) | ~$32 |
| Data Transfer | ~5 GB out | ~$5 |
| **Total (Dev)** | | **~$103/month** |

**Optimization strategies**:
- Use FARGATE_SPOT for 70% savings (set in Terraform)
- Schedule scaling down off-hours
- Adjust RDS/Redis instance classes per environment
- Enable EBS snapshots instead of continuous backups

## 🛠️ Developer Workflows

### Makefile Commands

```bash
# Formatting & Linting
make fmt                 # Format all code (Terraform, Go, Node)
make lint                # Lint Terraform, Go, Docker

# Testing
make test                # Run all tests
make test-backend        # Go unit tests
make test-frontend       # React build test
make coverage            # Generate coverage report
make security-scan       # Trivy security scanner

# Infrastructure
make tf-init ENV=dev     # Initialize Terraform
make tf-plan ENV=dev     # Plan changes
make tf-apply ENV=dev    # Apply changes
make tf-destroy ENV=dev  # Destroy (DESTRUCTIVE)

# Docker & Local Development
make docker-build        # Build images locally
make docker-compose-up   # Start stack locally
make docker-compose-down # Stop stack

# Deployment & Monitoring
make smoke-test          # Run smoke tests
make logs-backend        # Tail backend logs
make logs-frontend       # Tail frontend logs
make status ENV=dev      # Check deployment status
```

### Development Workflow

```bash
# 1. Make code changes
# ...

# 2. Format and lint
make fmt lint

# 3. Test locally
make test

# 4. Test in Docker
make docker-compose-up
curl http://localhost:5000
curl http://localhost:8080/ping

# 5. Push to GitHub
git push origin feature/my-feature

# 6. GitHub Actions runs CI
# (Tests, linting, security scan)

# 7. Merge to main/develop
# (CD automatically deploys to prod/staging)
```

## 📁 Directory Structure

```
fullstack-docker-project/
├── .github/
│   ├── workflows/
│   │   ├── ci.yml              # CI pipeline (lint, test, scan)
│   │   └── cd.yml              # CD pipeline (build, deploy, smoke test)
│   └── copilot-instructions.md # AI agent guidelines
├── terraform/                  # Infrastructure as Code
│   ├── main.tf                # Main configuration
│   ├── variables.tf           # Input variables
│   ├── outputs.tf             # Output values
│   ├── modules/
│   │   ├── vpc/               # VPC, subnets, NAT
│   │   ├── ecr/               # ECR repositories
│   │   ├── rds/               # RDS PostgreSQL
│   │   ├── redis/             # ElastiCache Redis
│   │   ├── alb/               # Application Load Balancer
│   │   ├── security_groups/   # Security groups
│   │   ├── ecs/               # ECS cluster
│   │   ├── ecs_service/       # ECS services
│   │   ├── iam/               # IAM roles & policies
│   │   ├── cloudwatch/        # CloudWatch logs & alarms
│   │   └── autoscaling/       # Auto scaling policies
│   └── environments/
│       ├── dev/               # Dev environment tfvars
│       ├── staging/           # Staging environment tfvars
│       └── prod/              # Production environment tfvars
├── backend/                    # Go API
│   ├── app.go
│   ├── Dockerfile             # Multi-stage production build
│   ├── router/
│   │   └── router.go          # Route definitions, CORS config (REQUEST_ORIGIN env var)
│   ├── controller/
│   ├── cache/
│   └── pgconnection/
├── frontend/                   # React SPA
│   ├── src/
│   ├── public/
│   ├── Dockerfile             # Multi-stage production build
│   │                          # CRITICAL: REACT_APP_BACKEND_URL must be set during build, not runtime!
│   └── package.json
├── nginx.conf                 # Reverse proxy (local dev only)
├── docker-compose.yml         # Local development stack
├── Makefile                   # Developer shortcuts
├── TERRAFORM_GUIDE.md         # Detailed infrastructure docs
└── README.md                  # This file
```

## 🔐 Security Checklist

- [ ] AWS credentials in GitHub Secrets (never commit)
- [ ] RDS backup retention enabled (7+ days)
- [ ] Multi-AZ enabled in production
- [ ] VPC Flow Logs enabled for network analysis
- [ ] CloudTrail enabled for audit logging
- [ ] HTTPS/SSL configured on ALB (use ACM certificates)
- [ ] WAF enabled on ALB (DDoS protection)
- [ ] Regular security scanning (Trivy, Snyk)
- [ ] Secrets rotated periodically
- [ ] Least-privilege IAM policies reviewed

## 🚨 Troubleshooting

### Common Pitfalls

1. **Frontend build-time vars**: `REACT_APP_*` environment variables must be set during `npm run build`, not at container runtime
2. **CORS origin mismatch**: Backend `REQUEST_ORIGIN` env var must match frontend URL (e.g., `http://localhost` for local dev)
3. **Path routing**: When accessing backend via ALB, routes require `/api` prefix (e.g., `/api/ping` not `/ping`)
4. **Docker build context**: Backend and frontend Dockerfiles assume build context is `./backend/` or `./frontend/`, not repo root

### Services Not Reaching Healthy State

```bash
# Check ECS task logs
aws ecs describe-tasks --cluster fullstack-docker-dev --tasks <task-arn>
aws logs tail /ecs/fullstack-docker-dev-backend --follow

# Check ALB target health
aws elbv2 describe-target-health --target-group-arn <tg-arn>

# Verify security groups allow traffic
aws ec2 describe-security-groups --group-ids <sg-id>
```

### Database Connection Issues

```bash
# Get RDS endpoint
aws rds describe-db-instances --query 'DBInstances[0].Endpoint'

# Test connectivity from backend container
aws ecs execute-command --cluster fullstack-docker-dev \
  --task <task-id> --container backend \
  --interactive --command "/bin/sh -c 'nc -zv $POSTGRES_HOST 5432'"
```

### Terraform State Corruption

```bash
# Refresh state
terraform refresh

# View current state
terraform show

# Force unlock (use with caution)
terraform force-unlock <lock-id>
```

## 📚 Further Reading

- [AWS ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)

## 🤝 Contributing

1. Create a feature branch
2. Make changes
3. Run `make fmt lint test`
4. Push and create PR
5. Wait for GitHub Actions to pass
6. Merge to `develop` (staging) or `main` (production)

## 📝 Learning Outcomes

By studying this project, you'll learn:

- ✅ Terraform modular architecture for scalable IaC
- ✅ ECS Fargate deployment patterns
- ✅ RDS & ElastiCache integration with ECS
- ✅ ALB routing and health checks
- ✅ Auto scaling based on CloudWatch metrics
- ✅ GitHub Actions CI/CD workflows
- ✅ Docker multi-stage builds
- ✅ IAM role-based security
- ✅ CloudWatch observability
- ✅ Cost optimization strategies

## 📞 Support

For issues, questions, or suggestions:
1. Check `TERRAFORM_GUIDE.md` for detailed infrastructure docs
2. Review GitHub Actions logs
3. Check CloudWatch logs for runtime errors
4. See `.github/copilot-instructions.md` for architecture decisions

---

**Made with ❤️ for DevOps Engineers & Cloud Architects**
