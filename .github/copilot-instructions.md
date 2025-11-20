# Copilot instructions for this repository

Purpose: Help AI agents make correct, fast changes in this codebase. Keep answers specific to this repo’s patterns and workflows.

Big picture
- Local: docker-compose runs React frontend (5000), Go/Gin backend (8080), optional Postgres + Redis, and Nginx proxy (80 routes / → frontend, /api → backend).
- Cloud: Terraform deploys to AWS (VPC, ALB with path routing, ECS Fargate services for frontend/backend, RDS Postgres, ElastiCache Redis, CloudWatch, autoscaling).

Where things live (source of truth)
- App code: backend/ (Go, Gin, optional Redis/Postgres), frontend/ (React). Key backend files: router/router.go, cache/, pgconnection/.
- Local stack: docker-compose.yml, nginx.conf.
- Infra: terraform/main.tf wires modules in terraform/modules/* (alb, ecs, ecs_service, rds, redis, vpc, security_groups, autoscaling, cloudwatch, ecr, iam). Env settings in terraform/environments/{dev,prod}/terraform.tfvars.
- Automation: Makefile for dev tasks; CI at .github/workflows/ci.yml; CD at .github/workflows/cd.yml.

Developer workflows (use Makefile)
- make fmt lint test       → format + lint + run backend tests and frontend build
- make docker-compose-up   → local stack at http://localhost (proxy), http://localhost:8080/ping (backend)
- Terraform locally: make tf-init ENV=dev; make tf-plan ENV=dev; make tf-apply ENV=dev; make logs-backend ENV=dev

Backend behavior you can rely on
- Health: GET /ping always works; /ping?redis=true and /ping?postgres=true exercise optional deps.
- Env vars: REQUEST_ORIGIN, POSTGRES_HOST/USER/PASSWORD/DATABASE, REDIS_HOST, PORT (defaults in backend/README.md). Backend starts without Redis/Postgres if vars absent.

CD pipeline facts you must respect
- build-and-push job builds/pushes images to GHCR (ghcr.io/<owner>/<repo>/{backend,frontend}).
- deploy job (main → production env, others → staging env) runs Terraform with env tfvars path prod vs dev.
- Pre-plan import: terraform/import-existing-resources.sh runs before plan to adopt pre-existing AWS resources into state (idempotent; edit this script to change import IDs).
- Rollback: if the deploy job fails, it runs terraform destroy for the selected env to clean up partial deploys.

Registry alignment (important gotcha)
- Terraform task definitions consume image URIs from module.ecr.* (AWS ECR) and hard-code :latest in terraform/main.tf via ecr_image_uri.
- CI currently pushes to GHCR, not ECR. To fix alignment, choose one:
  1) Switch CD to push to AWS ECR and tag :latest to match module.ecr.* repository_url; or
  2) Plumb image URIs via variables: add variables backend_image_uri/frontend_image_uri, pass them from CD (TF_VAR_*), and use them instead of module.ecr.* in terraform/main.tf and modules/ecs_service.
- If you implement (2), update ecs_service variable names and thread through from root module; remove hard-coded :latest if you want immutable deploys by digest or CI tag.

ALB routing and health checks
- ALB listener routes /api/* → backend target group (8080), / → frontend (5000). Health checks: backend GET /ping, frontend GET /.

Environment mapping in CD
- main branch → prod tfvars (terraform/environments/prod/terraform.tfvars)
- other branches in workflow (develop, etc.) → dev tfvars

Key files to read before changing infra
- terraform/main.tf (wiring and image URIs), terraform/modules/ecs_service/main.tf (container_definitions, env injection), terraform/modules/alb/main.tf (listeners/targets), .github/workflows/cd.yml (imports, rollback, env selection).

Common pitfalls in this repo
- Mixing GHCR and ECR causes ECS tasks to pull the wrong registry. Fix as above before debugging ECS “CannotPullContainerError”.
- Import script imports names for "fullstack-docker-prod-*". If you change var.project_name or environments, update terraform/import-existing-resources.sh accordingly.
- Rollback will fail if any resource uses prevent_destroy=true. ecs_service sets prevent_destroy=false, but review other modules before relying on rollback for prod.

Useful examples
- Local curl: curl http://localhost:8080/ping; curl "http://localhost:8080/ping?redis=true"
- Makefile help: make help (lists all project-specific commands)

For deeper details
- Start with GETTING_STARTED.md and DEVOPS_README.md. Infra nuances: TERRAFORM_GUIDE.md. Backend/Frontend specifics: backend/README.md, frontend/README.md.
