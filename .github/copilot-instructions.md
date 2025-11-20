# Copilot Instructions for fullstack-docker-project

**TL;DR**: This is a production-grade DevOps showcase combining Docker, Terraform, ECS Fargate, GitHub Actions, auto-scaling, and observability. Start with `GETTING_STARTED.md` or read the short overview below.

## Architecture Overview

This project showcases both **learning-focused Docker composition** AND **production-grade AWS deployment**:

### Local Development (Docker Compose)
- **Frontend**: React app (port 5000) served by Node via `npm run build` + `serve`
- **Backend**: Go API (port 8080) using Gin framework with CORS enabled
- **Reverse Proxy**: Nginx (port 80) routes `/` → frontend, `/api/` → backend
- **Data Services**: PostgreSQL and Redis (optional, feature-gated by environment variables)

### Production Deployment (AWS Terraform)
- **ECS Fargate**: Frontend + Backend services on serverless container platform
- **ALB**: Application Load Balancer with path-based routing (`/api/*` → backend, `/` → frontend)
- **RDS PostgreSQL**: Multi-AZ production database with encryption, backups, secrets management
- **ElastiCache Redis**: Managed caching layer with auth token and monitoring
- **Auto Scaling**: Backend scales 1-5 tasks based on CPU/memory thresholds
- **CloudWatch**: Centralized logging, metrics, alarms, Container Insights
- **GitHub Actions**: CI/CD pipeline (lint → test → build → push → Terraform → deploy → smoke test)

**Key design pattern**: Services boot with optional connections. If `POSTGRES_HOST` or `REDIS_HOST` env vars are absent, those services skip initialization and return friendly "not implemented" responses.

## Build & Run Commands

### Backend (Go)
```bash
cd backend
go build          # Generates binary "server"
go test ./...     # Run all tests
./server          # Execute (listens on $PORT, default 8080)
```

### Frontend (React)
```bash
cd frontend
npm install       # Install dependencies
npm run build     # Build to ./build folder (required for production)
serve -s -l 5000 build  # Serve static files on port 5000
```

### Docker Compose
```bash
docker-compose up --build  # Build and start all services
# Frontend: http://localhost:5000
# Backend: http://localhost:8080
# Nginx proxy: http://localhost (port 80)
```

## Backend Architecture (Go)

**Files**: `backend/app.go`, `backend/router/router.go`, `backend/controller/`, `backend/cache/`, `backend/pgconnection/`

**Key patterns**:
1. **Gin router** in `router/router.go` initializes Redis and Postgres clients on startup (both optional)
2. **Message model** defined in both `controller/messagecontroller.go` and `pgconnection/trypostgres.go` (mirrors for testing vs. production)
3. **Retry logic**: Redis/Postgres init retries 5 times with 2-second delays (see `tryredis.go` and `trypostgres.go`)
4. **Conditional feature testing**: `/ping?redis=true` or `/ping?postgres=true` query params test specific connections
5. **Singleton pattern**: `cache.rdb` and `pgconnection.pgdb` are package-level globals initialized once
6. **CORS**: Configured to allow only `REQUEST_ORIGIN` env var (default: `https://example.com`)

**Message endpoints**:
- `POST /messages` - Create message (requires Postgres)
- `GET /messages` - Fetch all messages (requires Postgres)
- `GET /ping` - Health check (always works)
- `GET /ping?redis=true` - Redis connectivity test
- `GET /ping?postgres=true` - Postgres connectivity test

## Frontend Architecture (React)

**Files**: `frontend/src/App.js`, `frontend/src/components/ExercisesList/`, `frontend/src/util/pingpong.js`

**Key patterns**:
1. **Exercise-driven UI**: Component hierarchy: `App.js` → `ExercisesList` → multiple `Exercise` components for each Docker exercise milestone (1.12, 1.14, 2.4, 2.6, 2.8)
2. **Axios configuration** in `util/pingpong.js`: Base URL from `REACT_APP_BACKEND_URL` env var (defaults to `/api`)
3. **Utility functions**: `pingpong()`, `pingpongRedis()`, `pingpongPostgres()`, `pingpongNginx()` - each tests a different backend connectivity scenario
4. **Status management**: Components use `useState` to track test results (`message`, `success` boolean)

## Environment Variables

### Backend (docker-compose.yml)
- `PORT` - Server port (default: 8080)
- `REQUEST_ORIGIN` - CORS origin (default: `https://example.com`)
- `REDIS_HOST` - Redis hostname (omit to skip Redis, no default)
- `POSTGRES_HOST` - Postgres hostname (omit to skip Postgres, no default)
- `POSTGRES_USER` - DB user (default: `postgres`)
- `POSTGRES_PASSWORD` - DB password (default: `postgres`)
- `POSTGRES_DATABASE` - DB name (default: `postgres`)

### Frontend (docker-compose.yml)
- `REACT_APP_BACKEND_URL` - Backend URL for axios (default: `/api`)

## Nginx Reverse Proxy (nginx.conf)

Routes incoming traffic:
- `location /` → frontend container on `http://frontend_server:5000/`
- `location /api/` → backend container on `http://backend_server:8080/` (strips `/api/` prefix)

Used in exercise 2.8 to test combined service communication.

## Common Dev Workflows

1. **Test backend in isolation**: `cd backend && go test ./... && go run app.go` (no Redis/Postgres)
2. **Test full stack**: `docker-compose up --build` then visit `http://localhost:5000`
3. **Frontend config**: Set `REACT_APP_BACKEND_URL` before `npm run build` to point to custom backend
4. **Debug Postgres schema**: Schema is auto-created on first connection in `pgconnection.createSchema()`
5. **Redis cache test**: `pingpongRedis()` sets a `ping` key to `pong` on init, then queries it

## Testing Patterns

- **Backend tests**: `backend/*_test.go` files follow Go convention
- **Frontend components**: Render async tests via `ExerciseButton` + status display pattern
- **Integration test**: Frontend's exercise components call backend `/ping` endpoints with query params

## Docker Compose Service Dependencies

```
backend_server → postgres_server (optional, via POSTGRES_HOST env)
             → redis_server (optional, via REDIS_HOST env)
reverse_proxy → frontend_server
             → backend_server
```

The `depends_on` clause ensures Postgres/Redis start before backend, but **backend gracefully degrades** if connections fail (doesn't crash).

---

## Production Infrastructure (AWS Terraform)

**Key Files**: `terraform/main.tf`, `terraform/modules/`, `terraform/environments/{dev,staging,prod}/terraform.tfvars`

### Infrastructure Components

1. **VPC & Networking** (`modules/vpc`):
   - Private subnets (ECS, RDS, Redis)
   - Public subnets (ALB, NAT Gateways)
   - Multi-AZ setup for HA
   - Separate route tables for public/private

2. **ECS Fargate** (`modules/ecs`, `modules/ecs_service`):
   - Serverless containers (no EC2 management)
   - Container Insights enabled
   - Environment-specific task counts (dev: 1, staging: 2, prod: 3)
   - Auto-scaling: min/max capacity per environment

3. **RDS PostgreSQL** (`modules/rds`):
   - Encrypted storage, Multi-AZ in staging/prod
   - 7-day (dev), 14-day (staging), 30-day (prod) backups
   - Password stored in AWS Secrets Manager
   - Security group restricts access to ECS only

4. **ElastiCache Redis** (`modules/redis`):
   - At-rest + in-transit encryption
   - Auth token generation and secret storage
   - CloudWatch logs for troubleshooting

5. **Application Load Balancer** (`modules/alb`):
   - Path-based routing: `/api/*` → backend (8080), `/` → frontend (5000)
   - Health checks: `/ping` (backend), `/` (frontend)
   - Automatic target registration

6. **IAM & Security** (`modules/iam`, `modules/security_groups`):
   - Task execution role: pulls ECR images, writes logs
   - Task roles: minimal permissions per service
   - Security groups enforce least-privilege network access

7. **Observability** (`modules/cloudwatch`):
   - Log groups: 7-day retention by default
   - Alarms: CPU/Memory > 80% thresholds
   - Container Insights: advanced ECS metrics

8. **Auto Scaling** (`modules/autoscaling`):
   - Target CPU utilization: 70%
   - Target memory utilization: 75%
   - Environment-specific min/max (e.g., dev: 1-2, prod: 2-5)

### Deployment Workflows

**Manual Local Deploy**:
```bash
cd terraform/environments/dev
terraform init         # One-time
terraform plan        # Review changes
terraform apply       # Deploy
terraform output      # Get ALB DNS, log groups, etc.
```

**Automated CI/CD** (GitHub Actions):
1. **Push to `develop`** → Deploys to staging
2. **Push to `main`** → Deploys to production
3. Pipeline: Lint → Test → Build → Push ECR → Terraform → Smoke Tests

### Environment Parity

All three environments use identical Terraform code; differences are in `terraform.tfvars`:

| Aspect | Dev | Staging | Prod |
|--------|-----|---------|------|
| Backend tasks | 1 | 2 | 3 |
| Backend scaling | 1-2 | 1-3 | 2-5 |
| RDS instance | db.t3.micro | db.t3.small | db.t3.medium |
| Redis node | cache.t3.micro | cache.t3.small | cache.t3.medium |
| Backups | 7 days | 14 days | 30 days |
| Multi-AZ | false | true | true |
| Storage | 20 GB | 50 GB | 100 GB |

### Cost Optimization

- **Dev (~$103/mo)**: Minimal resources, single tasks
- **Staging (~$180/mo)**: Medium resources, 2-3 tasks
- **Prod (~$250+/mo)**: Larger resources, 3-5 tasks, HA

Strategies: FARGATE_SPOT (70% savings), scheduled scaling, adjusted storage retention

---

## CI/CD Pipeline

**Files**: `.github/workflows/ci.yml`, `.github/workflows/cd.yml`

### CI Workflow (On PR & Push)

1. **Lint & Format** (golangci-lint, Terraform, Node.js)
2. **Unit Tests** (Go: `go test ./...`, React: `npm run build`)
3. **Terraform Validation** (`terraform validate`, `terraform fmt -check`)
4. **Security Scanning** (Trivy: container images, dependencies)
5. **Code Coverage** (Backend: upload to codecov)

### CD Workflow (After Merge)

1. **Build Docker Images**:
   - Backend: Go binary (scratch base for minimal size)
   - Frontend: React SPA (served by `serve`)
2. **Push to ECR**: Tag with branch + git SHA
3. **Terraform Plan**: Show changes before applying
4. **Terraform Apply**: Update infrastructure (auto-approve on main/develop)
5. **Smoke Tests**: Wait for ALB health, test `/ping` endpoints
6. **Notifications**: Success/failure reporting

### Secrets Required in GitHub

```
AWS_ROLE_ARN           # IAM role for OIDC federation
AWS_REGION             # AWS region (default: us-east-1)
TF_STATE_BUCKET        # S3 bucket for Terraform state
```

---

## Developer Workflows

### Using Makefile

**Essential commands**:
```bash
make fmt               # Format all code
make lint              # Lint Terraform, Go, Docker
make test              # Run all tests
make docker-compose-up # Local full stack
make tf-init ENV=dev   # Initialize Terraform
make tf-plan ENV=dev   # Plan infrastructure
make tf-apply ENV=dev  # Deploy to AWS
make smoke-test        # Test ALB endpoints
make logs-backend      # Tail CloudWatch logs
```

**Full reference**: `make help`

### Local Development Loop

1. **Code → Format → Lint → Test**:
   ```bash
   make fmt lint test
   ```
2. **Test locally**:
   ```bash
   make docker-compose-up
   curl http://localhost:5000  # Frontend
   curl http://localhost:8080/ping  # Backend
   ```
3. **Push → GitHub Actions CI runs**
4. **Review & merge → CD deploys to staging/prod**

### Terraform Import Workflow
When adopting existing AWS resources:
```bash
cd terraform/environments/prod
terraform plan -var-file="terraform.tfvars" -out=tfplan  # Shows resources to import
terraform apply tfplan                                   # Imports into state
terraform state list                                     # Verify all imported
```

### Debugging Failed Services
```bash
make logs-backend ENV=prod                    # CloudWatch logs
aws ecs execute-command --cluster fullstack-docker-prod --task <task-id> --container backend --interactive --command "/bin/sh"  # Shell into running task
terraform state show 'module.rds.aws_db_instance.postgres'  # Verify resource configuration
```

---

## Key Patterns & Conventions

### Terraform Patterns

1. **Modular structure**: Each AWS service is a separate module (vpc, ecs, rds, etc.)
2. **Environment configuration**: `terraform.tfvars` per environment (dev/staging/prod)
3. **Default tags**: Common tags applied to all resources (Environment, Project, ManagedBy)
4. **Variable validation**: Input variables have validation rules (e.g., environment ∈ {dev, staging, prod})
5. **Outputs**: ALB DNS, log groups, RDS endpoint exported for monitoring
6. **Import blocks** (Terraform 1.7+): Adopt existing AWS resources into state to prevent "already exists" errors
   - 8 resources currently imported: log groups, ECR repos, parameter groups, subnet groups
   - Import blocks in `terraform/main.tf` auto-execute before creation
7. **Lifecycle rules**: 
   - `prevent_destroy = true`: Critical resources (RDS, Redis, ALB, ECS cluster, services)
   - `create_before_destroy = true`: Dependent resources (IAM roles, security groups, parameter groups)
   - `ignore_changes = all`: Externally-managed resources (CloudWatch logs, ECR repos, subnet groups)
   - `ignore_changes = [field_list]`: Fields managed externally (RDS password, ALB name_prefix, ECS desired_count)

### Docker Patterns

1. **Multi-stage builds** (both services):
   - Backend: Go compilation stage → scratch runtime (ultra-minimal)
   - Frontend: Node build stage → Alpine runtime (lightweight)
2. **Non-root users**: `appuser` for security
3. **Health checks**: `/ping` for backend, `/` for frontend
4. **Environment variables**: Externalized for config management

---

## Terraform State Management (Import Blocks & Lifecycle Rules)

**Problem Solved**: Terraform now fully manages AWS infrastructure without duplicate creation errors or accidental deletion.

### Import Blocks (terraform/main.tf)
Auto-adopt existing resources into state during `terraform plan`:
- **8 existing resources imported**: CloudWatch logs (3), ECR repos (2), parameter/subnet groups (3)
- **Workflow**: `terraform plan` detects import block → fetches from AWS → shows as "will be read" → `terraform apply` adds to state
- **Key insight**: Prevents "Resource already exists" errors on subsequent applies

### Lifecycle Rules Pattern
All resources configured with appropriate lifecycle rules:
```hcl
# Critical production resources
lifecycle {
  prevent_destroy = true        # Blocks terraform destroy with error
  ignore_changes  = [password]  # Externally-managed fields
}

# Dependent resources (IAM, security groups, parameter groups)
lifecycle {
  create_before_destroy = true  # New resource created before old destroyed
}

# Externally-managed resources
lifecycle {
  ignore_changes = all          # Allows adoption without conflicts
}
```

### When Implementing Terraform Changes

**For new resources**: Add appropriate lifecycle rule based on criticality
- **Critical** (database, cache, load balancer): `prevent_destroy = true`
- **Dependencies** (IAM roles, security groups): `create_before_destroy = true`
- **External** (logs, ECR, managed services): `ignore_changes = all`

**For resource imports**: Add import block to `terraform/main.tf` before creating in module
```hcl
import {
  to = module.service.aws_resource_type.name
  id = "aws-resource-id-from-console"
}
```

**For modifying externally-managed fields**: Use `ignore_changes = [specific_field]` to allow Secrets Manager, Auto Scaling, or AWS naming to manage particular attributes

### Backend (Go) Patterns

1. **Optional service initialization**: Redis/Postgres only if env vars set
2. **Retry logic**: 5 retries with 2-second delays for transient failures
3. **Query-param feature testing**: `/ping?redis=true`, `/ping?postgres=true` for diagnostics
4. **Singleton globals**: `cache.rdb`, `pgconnection.pgdb` initialized once at startup
5. **CORS allowlist**: `REQUEST_ORIGIN` env var controls allowed domains

### Frontend (React) Patterns

1. **Exercise-driven UI**: Components for each Docker milestone (1.12, 1.14, 2.4, 2.6, 2.8)
2. **Axios base URL**: Configurable via `REACT_APP_BACKEND_URL` (default: `/api`)
3. **Utility functions**: Separate testing functions for each backend scenario (Redis, Postgres, Nginx)
4. **Status management**: `useState` tracking success/failure per exercise

---

## Observability & Debugging

### CloudWatch Logs

```bash
# Tail backend logs
aws logs tail /ecs/fullstack-docker-dev-backend --follow

# Search for errors
aws logs filter-log-events --log-group-name /ecs/fullstack-docker-dev-backend --filter-pattern "ERROR"

# Using Makefile
make logs-backend ENV=dev
```

### ECS Task Inspection

```bash
# Describe task
aws ecs describe-tasks --cluster fullstack-docker-dev --tasks <task-arn> --query 'tasks[0].[taskArn,taskStatus,lastStatus]'

# Execute command in running task
aws ecs execute-command --cluster fullstack-docker-dev --task <task-id> --container backend --interactive --command "/bin/sh"
```

### ALB & Target Health

```bash
# Check target health
aws elbv2 describe-target-health --target-group-arn <tg-arn>

# Monitor ALB
aws cloudwatch get-metric-statistics --namespace AWS/ApplicationELB --metric-name TargetResponseTime --dimensions Name=LoadBalancer,Value=<alb-name>
```

---

## Common Pitfalls & Solutions

1. **Service fails to reach healthy state**:
   - Check security group rules (ALB → ECS, ECS → RDS/Redis)
   - Verify environment variables (POSTGRES_HOST, REDIS_HOST)
   - Tail logs: `make logs-backend`

2. **Terraform state conflicts**:
   - Always `terraform refresh` before plan/apply
   - Use remote state (S3 + DynamoDB) for team collaboration
   - Lock file prevents concurrent modifications

3. **Container image size bloat**:
   - Use multi-stage builds to exclude build dependencies
   - Backend: base `scratch` not `golang:1.16-alpine`
   - Frontend: base `alpine` not `node:14`

4. **Auto scaling doesn't trigger**:
   - Verify CloudWatch metrics are publishing (Container Insights enabled)
   - Check scaling policy thresholds match observed metrics
   - Ensure task count is below max_capacity

5. **Database connection refused**:
   - Confirm RDS security group allows ECS source
   - Verify POSTGRES_HOST env var matches RDS endpoint
   - Test from ECS task: `nc -zv $POSTGRES_HOST 5432`

---

## Testing Strategy

- **Backend**: Unit tests in `backend/*_test.go`, run via `go test ./...`
- **Frontend**: Build validation via `npm run build`, no unit tests currently
- **Integration**: Exercise components test live backend endpoints
- **Infrastructure**: Terraform validate + smoke tests on deployment
- **Security**: Trivy scanning on every build, GitHub security advisories
