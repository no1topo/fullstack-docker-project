# AI Coding Assistant Instructions

## Project Overview

This is a **production-grade DevOps showcase** demonstrating a fullstack application (Go backend + React frontend) deployed to AWS ECS using Infrastructure as Code, CI/CD automation, and enterprise observability patterns.

**Architecture**: 3-tier application with React frontend (port 5000), Go/Gin backend (port 8080), PostgreSQL database, and Redis cache, all containerized and deployed to AWS Fargate with ALB routing.

## Repository Structure

```
├── backend/              # Go 1.16 backend (Gin framework)
│   ├── app.go           # Main entry point
│   ├── router/          # Route definitions & CORS setup
│   ├── controller/      # Message CRUD handlers
│   ├── pgconnection/    # PostgreSQL client initialization
│   └── cache/           # Redis client initialization
├── frontend/            # React frontend (Node 14)
│   └── src/components/  # UI components & API integration
├── terraform/           # AWS infrastructure modules
│   ├── main.tf          # Root orchestration (VPC, ECS, RDS, Redis, ALB)
│   ├── modules/         # Reusable IaC components (10+ modules)
│   └── environments/    # Environment-specific tfvars (dev/staging/prod)
├── .github/workflows/   # CI/CD pipelines
│   ├── ci.yml           # Lint, test, security scan on PRs
│   └── cd.yml           # Build, push ECR, terraform apply on merge
├── docker-compose.yml   # Local development stack
├── nginx.conf           # Reverse proxy config (path-based routing)
└── Makefile             # 30+ automation commands
```

## Key Development Workflows

### Local Development
```bash
# Start full stack locally (no AWS required)
docker-compose up --build

# Run tests before committing
make test              # Runs backend Go tests + frontend build
make lint              # Runs golangci-lint, terraform fmt, eslint

# Common iterations
cd backend && go test -v ./...            # Test Go code
cd frontend && npm install && npm start   # Run React dev server (port 3000)
```

### Deployment Flow
- **PRs**: Trigger `ci.yml` (lint, test, Terraform validate, security scan)
- **Merge to `develop`**: Auto-deploy to dev environment via `cd.yml`
- **Merge to `main`**: Auto-deploy to prod environment via `cd.yml`
- **Manual**: `make tf-plan ENV=dev` → review → `make tf-apply ENV=dev`

### Infrastructure Management
```bash
# Initialize Terraform for specific environment
cd terraform/environments/dev && terraform init

# Use Makefile for safer operations
make tf-plan ENV=dev    # Preview changes
make tf-apply ENV=dev   # Apply with approval
make tf-output ENV=dev  # Get ALB URL, log groups, etc.
```

## Project-Specific Patterns

### Backend (Go)
- **Router pattern**: `router/router.go` defines all routes with CORS config from `REQUEST_ORIGIN` env var
- **Health checks**: `/ping` endpoint supports `?redis=true` and `?postgres=true` query params for dependency checks
- **Environment vars**: Required vars in `backend/README.md` - critical: `REDIS_HOST`, `POSTGRES_*` for connections
- **Multi-stage Dockerfile**: Builds with `golang:1.16`, runs in `scratch` image (minimal footprint)
- **Database**: Uses `go-pg` ORM, models in `controller/` (e.g., `Message` struct with JSON tags)

### Frontend (React)
- **Build-time config**: `REACT_APP_BACKEND_URL` must be set during `npm run build` (not runtime!)
- **API integration**: Backend URL defaults to `/api` (proxied by ALB in production)
- **Multi-stage Dockerfile**: Builds with `node:14`, serves with `serve` package on port 5000
- **Components**: Organized in `src/components/` with exercise-based naming (e.g., `PostgresConnection.js`)

### Terraform Modules
- **Modular design**: Each AWS service is a module (`modules/vpc/`, `modules/ecs/`, `modules/rds/`, etc.)
- **Environment parity**: Same code, different `terraform/environments/{env}/terraform.tfvars` configs
- **Security groups**: Centralized in `modules/security_groups/` with least-privilege rules
- **Secrets**: RDS passwords & Redis auth tokens stored in AWS Secrets Manager, referenced in ECS task definitions
- **Outputs**: All modules export key values (IDs, ARNs, endpoints) used by dependent modules

### Docker Compose Patterns
- **Service dependencies**: `backend_server` depends_on `postgres_server` and `redis_server`
- **Environment injection**: Backend receives `POSTGRES_HOST=postgres_server` (Docker DNS resolution)
- **Nginx routing**: `/` → frontend, `/api/` → backend (matches ALB routing in AWS)
- **Volume persistence**: PostgreSQL data persists in named volume `database`

### CI/CD Specifics
- **AWS ECR for images**: Docker images pushed to AWS Elastic Container Registry
- **Image tagging**: Git SHA-based tags (e.g., `abc123def456`)
- **AWS authentication**: Uses AWS access keys in GitHub secrets
- **Terraform backend**: S3 + DynamoDB locking (configured in `terraform/main.tf` backend block)
- **Multi-environment**: Branch name determines target (`main` → prod, `develop` → dev)

## Critical Files to Understand

When modifying infrastructure:
- `terraform/main.tf` - Root module orchestration (see how modules connect)
- `terraform/modules/ecs_service/main.tf` - ECS task definitions with ECR image URIs and secrets injection
- `terraform/modules/ecr/main.tf` - ECR repositories with lifecycle policies
- `terraform/variables.tf` + `environments/{env}/*.tfvars` - All configurable parameters
- `.github/workflows/cd.yml` - Build, push to ECR, and deploy pipeline

When debugging runtime issues:
- `backend/router/router.go` - Route definitions and CORS config
- `docker-compose.yml` - Service wiring and environment variables
- `nginx.conf` - Path-based routing logic (critical for frontend/backend separation)

When updating workflows:
- `.github/workflows/cd.yml` - Build & deploy pipeline (note ENV_NAME mapping)
- `Makefile` - Reusable command patterns (prefer extending Makefile over custom scripts)

## Integration Points

### GitHub Actions → AWS ECR → ECS
- GitHub Actions builds Docker images after code is pushed
- Images are tagged with git SHA (e.g., `abc123def456`)
- Images pushed to ECR: `<account>.dkr.ecr.us-east-1.amazonaws.com/fullstack-docker-backend:{sha}`
- Terraform receives ECR image URIs via `TF_VAR_backend_image_uri` and `TF_VAR_frontend_image_uri`
- ECS task definitions updated with new ECR image URIs
- ECS pulls images from ECR (not public registries)

### ALB → ECS Services
- ALB forwards `/` to frontend target group (port 5000)
- ALB forwards `/api/*` to backend target group (port 8080)
- Health checks: frontend expects 200 on `/`, backend expects 200 on `/ping`

### Backend → Database/Cache
- PostgreSQL connection via `POSTGRES_HOST` env var (Docker DNS or RDS endpoint)
- Redis connection via `REDIS_HOST` env var (Docker DNS or ElastiCache endpoint)
- Credentials injected via ECS task definition from Secrets Manager in AWS

### Frontend → Backend
- Frontend built with `REACT_APP_BACKEND_URL=/api` (proxied by ALB)
- In local dev: `REACT_APP_BACKEND_URL=http://localhost:8080` (direct connection)

## Environment-Specific Behavior

| Aspect | dev | staging | prod |
|--------|-----|---------|------|
| ECS Tasks | 1-2 | 1-3 | 2-5 |
| RDS Multi-AZ | false | true | true |
| Instance Sizes | t3.micro | t3.small | t3.medium+ |
| Backup Retention | 7 days | 14 days | 30 days |
| Auto-scaling Target | 70% CPU | 70% CPU | 65% CPU |

## Common Pitfalls

1. **Frontend build-time vars**: `REACT_APP_*` env vars must be set during `npm run build`, not container runtime
2. **CORS origin**: Backend `REQUEST_ORIGIN` must match frontend URL (e.g., `http://localhost` in dev)
3. **Terraform state**: Always run `terraform init` after switching environments or updating backend config
4. **Docker build context**: Dockerfiles assume build context is `./backend/` or `./frontend/`, not repo root
5. **Path routing**: Backend routes must include `/api` prefix when accessed via ALB (e.g., `/api/ping`, not `/ping`)
6. **Security group dependencies**: Changing SG rules requires understanding module dependencies (ECS → RDS → Redis chain)

## Testing Philosophy

- **Unit tests**: Go tests in `backend/*_test.go` (run with `go test -v -race ./...`)
- **Integration tests**: Docker Compose stack simulates production environment locally
- **Smoke tests**: Health check endpoints (`/ping?redis=true&postgres=true`) verify service connectivity
- **Infrastructure tests**: Terraform validate in CI prevents invalid configurations

## Documentation Quick Reference

- `DEVOPS_README.md` - High-level architecture & quick start
- `TERRAFORM_GUIDE.md` - Deep dive on infrastructure components
- `GITHUB_ACTIONS_SETUP.md` - AWS OIDC setup & credential configuration
- `ARCHITECTURE_DIAGRAMS.md` - Visual system flows & data paths
- `GETTING_STARTED.md` - Demo scripts & talking points for showcasing
- `Makefile` - All available commands with descriptions (`make help`)

## When Making Changes

✅ **Do**: 
- Use Makefile commands for consistency (`make fmt lint test`)
- Test locally with `docker-compose up` before pushing
- Update environment tfvars when adding new Terraform variables
- Run `terraform fmt -recursive terraform/` before committing
- Follow existing module patterns when adding infrastructure

❌ **Avoid**:
- Hardcoding AWS region/account IDs (use variables)
- Mixing concerns across modules (keep modules single-purpose)
- Breaking environment parity (what works in dev should work in prod)
- Bypassing CI/CD (manual infrastructure changes = drift risk)
- Storing secrets in code (use Secrets Manager or env vars)
