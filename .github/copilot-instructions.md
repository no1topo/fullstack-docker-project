# Copilot instructions for this repository

Purpose: Enable fast, correct changes by documenting repo-specific patterns and workflows.

Big Picture
- Local: docker-compose runs React (5000), Go/Gin backend (8080), optional Postgres/Redis, and Nginx proxy (80 → `/` frontend, `/api` backend).
- Cloud: Terraform provisions AWS VPC, ALB (path routing), ECS Fargate (frontend/backend), RDS Postgres, ElastiCache Redis, CloudWatch, autoscaling.

Key Paths (source of truth)
- App: `backend/` (Gin; see `router/router.go`, `cache/`, `pgconnection/`), `frontend/` (React).
- Local stack: `docker-compose.yml`, `nginx.conf`.
- Infra: `terraform/main.tf` wiring modules in `terraform/modules/*` (alb, ecs, ecs_service, rds, redis, vpc, security_groups, autoscaling, cloudwatch, ecr, iam). Env in `terraform/environments/{dev,prod}/terraform.tfvars`.
- Automation: Makefile tasks; CI at `.github/workflows/ci.yml`; CD at `.github/workflows/cd.yml`; imports generator `terraform/generate-imports-tf.sh` (emits `imports.auto.tf`).

Developer Workflows
- `make fmt lint test` → format + lint + backend tests + frontend build
- `make docker-compose-up` → proxy at `http://localhost`, backend health `http://localhost:8080/ping`
- Terraform locally: `make tf-init ENV=dev`; `make tf-plan ENV=dev`; `make tf-apply ENV=dev`; logs: `make logs-backend ENV=dev`

Backend Behavior
- Health: `GET /ping` always works; `?redis=true` and `?postgres=true` exercise optional deps.
- Env vars: `REQUEST_ORIGIN`, `POSTGRES_HOST/USER/PASSWORD/DATABASE`, `REDIS_HOST`, `PORT`. Backend runs without Redis/Postgres if unset.

CI/CD Facts
- Build: GHCR images `ghcr.io/<owner>/<repo>/{backend,frontend}` with multiple tags; CD selects a single tag and passes `TF_VAR_backend_image_uri`/`frontend_image_uri`.
- Deploy: main → production tfvars; others → dev tfvars.
- Imports: `terraform/generate-imports-tf.sh` detects existing AWS resources (CloudWatch logs, ECR, VPC groups, ALB/TGs, Redis params/logs, EIP/NAT) and writes `imports.auto.tf`; workflow runs a refresh-only apply to adopt before full plan.
- Rollback: On failure, `terraform destroy` for the selected env.

Infra Patterns & Flags
- Image URIs: `terraform/main.tf` coalesces `var.*_image_uri` with ECR defaults. Prefer passing explicit GHCR URIs from CD.
- VPC: `modules/vpc` supports `single_nat_gateway` (repo sets it true) to avoid EIP limits; routes target NAT[0].
- RDS: `rds_multi_az` (default true outside dev) and `rds_storage_type` (default `gp3`) control availability/storage; master password uses allowed special chars only.
- CloudWatch: Logs for backend/frontend and Redis are created and may be imported; module lifecycles often ignore changes to allow external reuse.

ALB Routing & Health
- `/api/*` → backend TG (8080), `/` → frontend (5000). Health checks: backend `GET /ping`, frontend `GET /`.

Common Pitfalls
- Registry mismatch (GHCR vs ECR) → ensure `*_image_uri` vars match pushed registry to avoid `CannotPullContainerError`.
- Missing imports → verify `imports.auto.tf` contains Redis param group and NAT/EIP before plan.
- EIP quota → use single NAT; import existing EIP/NAT to avoid allocation.
- RDS capacity/password → prefer `gp3`; Multi-AZ only when available; ensure password excludes `/`, `@`, `"`, and space.
- Cross-VPC adoption → do not import pre-existing RDS in a different VPC; create a new one or peer networks.

Useful Examples
- Curl: `curl http://localhost:8080/ping`; `curl "http://localhost:8080/ping?redis=true"`
- Makefile help: `make help`

Read More
- `GETTING_STARTED.md`, `DEVOPS_README.md`, `TERRAFORM_GUIDE.md`, `backend/README.md`, `frontend/README.md`.
