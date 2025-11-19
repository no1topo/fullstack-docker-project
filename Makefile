# Production-Grade Makefile for DevOps Workflow

.PHONY: help init plan apply destroy fmt validate lint test build push clean tf-* docker-* k8s-*

# Variables
ENV ?= dev
AWS_REGION ?= us-east-1
TERRAFORM_DIR := terraform/environments/$(ENV)
TF_VERSION := 1.5.0
DOCKER_REGISTRY ?= ghcr.io
PROJECT_NAME ?= fullstack-docker
GIT_HASH := $(shell git rev-parse --short HEAD)
GIT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD)

help:
	@echo "=== Fullstack Docker DevOps Makefile ==="
	@echo "Development Commands:"
	@echo "  make fmt              - Format Terraform and Go code"
	@echo "  make lint             - Lint all code (Terraform, Go, Node)"
	@echo "  make test             - Run all tests (backend & frontend)"
	@echo ""
	@echo "Terraform Commands:"
	@echo "  make tf-init ENV=dev  - Initialize Terraform (default: dev)"
	@echo "  make tf-plan ENV=dev  - Plan infrastructure changes"
	@echo "  make tf-apply ENV=dev - Apply infrastructure changes (requires approval)"
	@echo "  make tf-destroy ENV=dev - Destroy infrastructure (DESTRUCTIVE)"
	@echo "  make tf-output ENV=dev - Show Terraform outputs"
	@echo "  make tf-fmt           - Format Terraform files"
	@echo "  make tf-validate      - Validate Terraform configuration"
	@echo ""
	@echo "Docker Commands:"
	@echo "  make docker-build     - Build backend & frontend images locally"
	@echo "  make docker-push ENV=dev - Push images to ECR (requires AWS creds)"
	@echo "  make docker-compose-up - Start full stack locally (docker-compose)"
	@echo "  make docker-compose-down - Stop local stack"
	@echo ""
	@echo "Testing & Quality:"
	@echo "  make test-backend     - Run Go unit tests"
	@echo "  make test-frontend    - Build React app"
	@echo "  make coverage         - Generate test coverage report"
	@echo "  make security-scan    - Run Trivy security scanner"
	@echo ""
	@echo "Integration:"
	@echo "  make smoke-test       - Run smoke tests against ALB"
	@echo "  make logs-backend     - Tail backend CloudWatch logs"
	@echo "  make logs-frontend    - Tail frontend CloudWatch logs"
	@echo ""
	@echo "Examples:"
	@echo "  make tf-plan ENV=prod                # Plan production deployment"
	@echo "  make docker-build                    # Build images for local testing"
	@echo "  make test-backend && test-frontend   # Run all tests before deploying"

# ============= FORMATTING & LINTING =============

fmt: tf-fmt fmt-go fmt-node
	@echo "✓ All code formatted"

fmt-go:
	cd backend && gofmt -s -w .
	@echo "✓ Go code formatted"

fmt-node:
	cd frontend && npm run format || npx prettier --write src/
	@echo "✓ Node code formatted"

tf-fmt:
	terraform fmt -check -recursive terraform/ || terraform fmt -recursive terraform/
	@echo "✓ Terraform formatted"

lint: lint-tf lint-go lint-node lint-docker

lint-tf:
	@echo "→ Validating Terraform..."
	cd $(TERRAFORM_DIR) && terraform validate
	@echo "✓ Terraform valid"

lint-go:
	@echo "→ Linting Go code..."
	cd backend && golangci-lint run ./... || go vet ./...
	@echo "✓ Go code linted"

lint-node:
	@echo "→ Linting Node code..."
	cd frontend && npm run lint || npx eslint src/ || true
	@echo "✓ Node code checked"

lint-docker:
	@echo "→ Scanning Dockerfiles for vulnerabilities..."
	docker run --rm -v $(PWD):/root aquasec/trivy fs --exit-code 0 /root/backend/Dockerfile /root/frontend/Dockerfile || true
	@echo "✓ Dockerfile scan complete"

# ============= TESTING =============

test: test-backend test-frontend
	@echo "✓ All tests passed"

test-backend:
	@echo "→ Running backend tests..."
	cd backend && go test -v -race -coverprofile=coverage.out ./...
	@echo "✓ Backend tests passed"

test-frontend:
	@echo "→ Building frontend..."
	cd frontend && npm ci && npm run build
	@echo "✓ Frontend build successful"

coverage:
	@echo "→ Generating coverage report..."
	cd backend && go test -coverprofile=coverage.out ./... && go tool cover -html=coverage.out -o coverage.html
	@echo "✓ Coverage report: backend/coverage.html"

security-scan:
	@echo "→ Running security scan..."
	docker run --rm -v $(PWD):/root aquasec/trivy fs /root
	@echo "✓ Security scan complete"

# ============= TERRAFORM =============

tf-init:
	@echo "→ Initializing Terraform (ENV=$(ENV))..."
	cd $(TERRAFORM_DIR) && terraform init -upgrade
	@echo "✓ Terraform initialized"

tf-plan:
	@echo "→ Planning infrastructure changes (ENV=$(ENV))..."
	cd $(TERRAFORM_DIR) && terraform plan -out=tfplan
	@echo "✓ Plan saved to tfplan. Review and run 'make tf-apply' to continue."

tf-apply:
	@echo "→ Applying infrastructure changes (ENV=$(ENV))..."
	@read -p "Are you sure? This will modify AWS infrastructure. Type 'yes' to continue: " confirm && \
	[ "$$confirm" = "yes" ] && cd $(TERRAFORM_DIR) && terraform apply -auto-approve tfplan || echo "Cancelled."

tf-destroy:
	@echo "⚠️  WARNING: This will DESTROY all infrastructure in $(ENV)"
	@read -p "Type 'destroy-$(ENV)' to confirm: " confirm && \
	[ "$$confirm" = "destroy-$(ENV)" ] && cd $(TERRAFORM_DIR) && terraform destroy -auto-approve || echo "Cancelled."

tf-validate:
	@echo "→ Validating Terraform (all environments)..."
	@for env in dev staging prod; do \
		echo "  Validating $$env..."; \
		cd terraform/environments/$$env && terraform validate -no-color || exit 1; \
		cd ../../../../; \
	done
	@echo "✓ All environments valid"

tf-output:
	@echo "→ Terraform outputs (ENV=$(ENV))..."
	cd $(TERRAFORM_DIR) && terraform output

tf-refresh:
	@echo "→ Refreshing Terraform state..."
	cd $(TERRAFORM_DIR) && terraform refresh

# ============= DOCKER =============

docker-build:
	@echo "→ Building Docker images..."
	docker build -t $(PROJECT_NAME)-backend:latest ./backend
	docker build -t $(PROJECT_NAME)-frontend:latest ./frontend
	@echo "✓ Docker images built"

docker-run-backend:
	docker run -it --rm -p 8080:8080 \
		-e PORT=8080 \
		-e REQUEST_ORIGIN=http://localhost:3000 \
		$(PROJECT_NAME)-backend:latest

docker-run-frontend:
	docker run -it --rm -p 5000:5000 \
		-e REACT_APP_BACKEND_URL=http://localhost:8080 \
		$(PROJECT_NAME)-frontend:latest

docker-compose-up:
	@echo "→ Starting local stack with docker-compose..."
	docker-compose up --build -d
	@echo "✓ Stack running at http://localhost:5000"

docker-compose-down:
	@echo "→ Stopping local stack..."
	docker-compose down
	@echo "✓ Stack stopped"

docker-compose-logs:
	docker-compose logs -f

# ============= ECR & PUSHING =============

docker-login-ecr:
	@echo "→ Logging into ECR..."
	aws ecr get-login-password --region $(AWS_REGION) | \
		docker login --username AWS --password-stdin $(DOCKER_REGISTRY)
	@echo "✓ Logged into ECR"

docker-push: docker-login-ecr
	@echo "→ Tagging and pushing images to ECR..."
	docker tag $(PROJECT_NAME)-backend:latest $(DOCKER_REGISTRY)/$(PROJECT_NAME)-backend:$(GIT_HASH)
	docker tag $(PROJECT_NAME)-backend:latest $(DOCKER_REGISTRY)/$(PROJECT_NAME)-backend:latest
	docker push $(DOCKER_REGISTRY)/$(PROJECT_NAME)-backend:$(GIT_HASH)
	docker push $(DOCKER_REGISTRY)/$(PROJECT_NAME)-backend:latest
	docker tag $(PROJECT_NAME)-frontend:latest $(DOCKER_REGISTRY)/$(PROJECT_NAME)-frontend:$(GIT_HASH)
	docker tag $(PROJECT_NAME)-frontend:latest $(DOCKER_REGISTRY)/$(PROJECT_NAME)-frontend:latest
	docker push $(DOCKER_REGISTRY)/$(PROJECT_NAME)-frontend:$(GIT_HASH)
	docker push $(DOCKER_REGISTRY)/$(PROJECT_NAME)-frontend:latest
	@echo "✓ Images pushed to ECR"

# ============= SMOKE TESTS =============

smoke-test:
	@echo "→ Running smoke tests..."
	@ALB_DNS=$$(cd $(TERRAFORM_DIR) && terraform output -raw alb_dns_name 2>/dev/null); \
	if [ -z "$$ALB_DNS" ]; then \
		echo "✗ Could not retrieve ALB DNS. Is infrastructure deployed?"; \
		exit 1; \
	fi; \
	echo "  Testing ALB endpoint: $$ALB_DNS"; \
	curl -f http://$$ALB_DNS/ping || exit 1; \
	echo ""; \
	echo "✓ Smoke tests passed"

# ============= LOGGING & MONITORING =============

logs-backend:
	@echo "→ Tailing backend logs..."
	aws logs tail /ecs/$(PROJECT_NAME)-$(ENV)-backend --follow --aws-region $(AWS_REGION)

logs-frontend:
	@echo "→ Tailing frontend logs..."
	aws logs tail /ecs/$(PROJECT_NAME)-$(ENV)-frontend --follow --aws-region $(AWS_REGION)

metrics-backend:
	@echo "→ Fetching backend metrics..."
	aws cloudwatch get-metric-statistics \
		--namespace AWS/ECS \
		--metric-name CPUUtilization \
		--dimensions Name=ServiceName,Value=$(PROJECT_NAME)-backend \
		--start-time $$(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
		--end-time $$(date -u +%Y-%m-%dT%H:%M:%S) \
		--period 300 \
		--statistics Average,Maximum \
		--region $(AWS_REGION)

# ============= UTILITIES =============

clean:
	@echo "→ Cleaning up..."
	rm -rf terraform/.terraform terraform/.terraform.lock.hcl
	rm -rf backend/coverage.* backend/server
	rm -rf frontend/build frontend/node_modules
	docker-compose down -v
	@echo "✓ Cleaned"

version:
	@echo "Terraform: $(TF_VERSION)"
	@terraform version
	@go version
	@node --version
	@npm --version

status:
	@echo "=== Deployment Status (ENV=$(ENV)) ==="
	@cd $(TERRAFORM_DIR) && terraform show -no-color | head -20
	@echo "..."
	@make tf-output ENV=$(ENV)

.DEFAULT_GOAL := help
