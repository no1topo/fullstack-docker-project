# Architecture Diagrams & Flow Charts

## System Architecture - AWS Deployment

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              INTERNET (0.0.0.0/0)                          │
└────────────────────────────────────────┬────────────────────────────────────┘
                                         │ HTTP:80 / HTTPS:443
                                         ▼
                          ┌──────────────────────────────┐
                          │  AWS CloudFront (Optional)   │
                          │  Global Caching Layer        │
                          └──────────────────┬───────────┘
                                             │
                                             ▼
                          ┌──────────────────────────────┐
                          │  Application Load Balancer   │
                          │  (Public Subnet)             │
                          │  - Port 80 (HTTP)            │
                          │  - Port 443 (HTTPS-Optional) │
                          │  - Health Checks             │
                          └─────┬──────────────┬─────────┘
                                │              │
                ┌───────────────┘              └───────────────┐
                │                                              │
                │ "/" (root)                      "/api/*"     │
                │ Path Routing                    Path Routing │
                ▼                                              ▼
    ┌────────────────────────────┐        ┌────────────────────────────┐
    │  Frontend Target Group     │        │  Backend Target Group      │
    │  (Port 5000)               │        │  (Port 8080)               │
    └────────────┬───────────────┘        └────────────┬───────────────┘
                 │                                     │
    ┌────────────▼────────────┐          ┌────────────▼────────────┐
    │  Private Subnet AZ-1    │          │  Private Subnet AZ-1   │
    │  ┌──────────────────┐   │          │  ┌──────────────────┐  │
    │  │ ECS Task (React) │   │          │  │ ECS Task (Go)   │  │
    │  │ Container        │   │          │  │ Container       │  │
    │  │ Frontend:5000    │   │          │  │ Backend:8080    │  │
    │  └──────────────────┘   │          │  └──────────────────┘  │
    └────────────┬────────────┘          └────────────┬────────────┘
                 │                                     │
    ┌────────────▼────────────┐          ┌────────────▼────────────┐
    │  Private Subnet AZ-2    │          │  Private Subnet AZ-2   │
    │  ┌──────────────────┐   │          │  ┌──────────────────┐  │
    │  │ ECS Task (React) │   │          │  │ ECS Task (Go)   │  │
    │  │ Container        │   │          │  │ Container       │  │
    │  │ Frontend:5000    │   │          │  │ Backend:8080    │  │
    │  └──────────────────┘   │          │  └──────────────────┘  │
    └────────────────────────┘          └────────────────────────┘
                                                     │
                                                     │
                    ┌────────────────────────────────┴─────────────────┐
                    │                                                  │
                    ▼                                                  ▼
        ┌──────────────────────────────┐        ┌──────────────────────┐
        │  AWS RDS PostgreSQL          │        │ AWS ElastiCache      │
        │  (Multi-AZ)                  │        │ Redis Cluster        │
        │                              │        │                      │
        │ - Primary Instance AZ-1      │        │ - Primary Node AZ-1  │
        │ - Standby Instance AZ-2      │        │ - Replica AZ-2       │
        │ - Automated Failover         │        │ - Auto Failover      │
        │ - Encrypted Storage          │        │ - Encrypted Storage  │
        │ - Daily Backups (7-30 days)  │        │ - CloudWatch Logs    │
        │ - Secrets Manager            │        │ - Secrets Manager    │
        └──────────────────────────────┘        └──────────────────────┘
```

## CI/CD Pipeline Flow

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                        DEVELOPER WORKFLOW                                    │
└──────────────────────────────────────────────────────────────────────────────┘

1. Write Code & Commit
   └─ git commit -am "feature: add new feature"
      └─ git push origin feature/my-feature
         
2. Create Pull Request
   └─ PR created on GitHub
      └─ Automatically triggers CI Workflow

┌──────────────────────────────────────────────────────────────────────────────┐
│ CI WORKFLOW (.github/workflows/ci.yml)  [RUNS ON PR & EVERY PUSH]           │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│ ┌─────────────────────────────┐ ┌─────────────────────────────┐            │
│ │ Backend Lint & Test         │ │ Frontend Build & Lint       │            │
│ ├─────────────────────────────┤ ├─────────────────────────────┤            │
│ │ 1. Set up Go 1.16           │ │ 1. Set up Node.js 14        │            │
│ │ 2. golangci-lint ./...      │ │ 2. npm ci                   │            │
│ │ 3. go test -v -race ./...   │ │ 3. npm run build            │            │
│ │ 4. Upload coverage          │ │ 4. ESLint (optional)        │            │
│ │ ✓ Success                   │ │ ✓ Success                   │            │
│ └─────────────────────────────┘ └─────────────────────────────┘            │
│ ┌─────────────────────────────┐ ┌─────────────────────────────┐            │
│ │ Terraform Validation        │ │ Security Scanning           │            │
│ ├─────────────────────────────┤ ├─────────────────────────────┤            │
│ │ 1. terraform fmt -check     │ │ 1. Trivy fs scan            │            │
│ │ 2. terraform validate       │ │ 2. Upload to GitHub SARIF   │            │
│ │ 3. All env validation       │ │ 3. GitHub code scanning     │            │
│ │ ✓ Success                   │ │ ✓ Complete                  │            │
│ └─────────────────────────────┘ └─────────────────────────────┘            │
│                                                                              │
│ ✓ ALL CHECKS PASSED                                                         │
│   └─ PR approved by reviewers                                              │
│      └─ Ready to merge                                                     │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘

3. Merge to Develop or Main
   └─ git merge feature/my-feature --squash
      └─ git push origin develop  # Deploy to Staging
         OR
      └─ git push origin main     # Deploy to Production

┌──────────────────────────────────────────────────────────────────────────────┐
│ CD WORKFLOW (.github/workflows/cd.yml)  [RUNS ON MERGE TO main/develop]     │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│ STAGE 1: Build & Push to ECR                                                │
│ ┌────────────────────────────────────────────────────────────────────────┐  │
│ │ 1. Set up Docker Buildx (multi-platform)                              │  │
│ │ 2. Login to GitHub Container Registry (ghcr.io)                       │  │
│ │ 3. Build Backend Image                                                │  │
│ │    - Multi-stage: compile Go → minimal scratch runtime                │  │
│ │    - Tag: ghcr.io/repo/backend:branch-{git_sha}                       │  │
│ │    - Push to registry                                                 │  │
│ │ 4. Build Frontend Image                                               │  │
│ │    - Multi-stage: Node build → Alpine runtime                         │  │
│ │    - Tag: ghcr.io/repo/frontend:branch-{git_sha}                      │  │
│ │    - Push to registry                                                 │  │
│ │ ✓ Images pushed                                                       │  │
│ └────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│ STAGE 2: Terraform Plan & Apply                                             │
│ ┌────────────────────────────────────────────────────────────────────────┐  │
│ │ 1. Configure AWS Credentials (OIDC Federation)                         │  │
│ │ 2. Set up Terraform (version 1.5.0)                                    │  │
│ │ 3. Select Environment:                                                 │  │
│ │    - develop branch → staging environment                              │  │
│ │    - main branch → production environment                              │  │
│ │ 4. Terraform Init (download providers, initialize state)               │  │
│ │ 5. Terraform Plan (show what will change)                              │  │
│ │ 6. Review Plan (manual approval for prod - optional)                   │  │
│ │ 7. Terraform Apply (create/update resources)                           │  │
│ │    - Update ECS task definitions with new image URIs                   │  │
│ │    - Update ECS services (rolling deployment)                          │  │
│ │    - Update ALB targets                                                │  │
│ │ ✓ Infrastructure updated                                              │  │
│ └────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│ STAGE 3: Smoke Tests & Validation                                           │
│ ┌────────────────────────────────────────────────────────────────────────┐  │
│ │ 1. Get ALB DNS Name from Terraform output                              │  │
│ │ 2. Wait for ALB health check (30 retries × 10s = 5 min max)            │  │
│ │ 3. Test Backend: curl -f http://{ALB}/ping                             │  │
│ │    ✓ Health check passed                                               │  │
│ │ 4. Test Frontend: curl http://{ALB}/ | grep "<!DOCTYPE html"           │  │
│ │    ✓ Frontend serving correctly                                        │  │
│ │ 5. Send Notification (success/failure)                                 │  │
│ │ ✓ Deployment verified                                                 │  │
│ └────────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│ ✓ DEPLOYMENT COMPLETE                                                       │
│   └─ Service live at: http://{ALB_DNS}                                     │
│      └─ Monitor in CloudWatch                                              │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Auto-Scaling Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    AUTO-SCALING DECISION CYCLE                              │
└─────────────────────────────────────────────────────────────────────────────┘

Every 60 seconds:
    │
    ▼
┌─────────────────────────────────────┐
│ CloudWatch Metrics Collection       │
│ - CPU Utilization                   │
│ - Memory Utilization                │
│ - (Average over last 60s)          │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────────────────┐
│ Application Auto Scaling Evaluates Policies                         │
├─────────────────────────────────────────────────────────────────────┤
│ Target: 70% CPU Utilization                                        │
│                                                                     │
│ IF (Average CPU > 70%) for 2 minutes                              │
│    └─ SCALE UP (increase desired_count by 1)                      │
│       ├─ New task launched in same AZ                             │
│       ├─ Task definition pulled from ECR                          │
│       ├─ Environment variables injected                           │
│       ├─ Registered with ALB target group                         │
│       └─ Health check begins                                       │
│                                                                     │
│ ELSE IF (Average CPU < 50%) for 5 minutes                         │
│    └─ SCALE DOWN (decrease desired_count by 1)                    │
│       ├─ Existing task receives SIGTERM                           │
│       ├─ Graceful shutdown period (30 seconds)                    │
│       ├─ If still running, SIGKILL sent                           │
│       └─ Task removed from ALB                                     │
│                                                                     │
│ CONSTRAINT: Min: 1 task, Max: 5 tasks (production)               │
│             Never scale below min_capacity                         │
│             Never scale above max_capacity                         │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│ CloudWatch Alarm Triggers (Optional)│
│ - CPU > 80% → SNS notification      │
│ - Memory > 80% → SNS notification   │
│ - Unhealthy targets → Alert         │
└─────────────────────────────────────┘
             │
             ▼
        ┌─────────────┐
        │ Wait 60s    │
        │ for next    │
        │ evaluation  │
        └─────┬───────┘
              │
              └──→ (repeat cycle)
```

## Data Flow - User Request

```
REQUEST PATH: User visits http://example.com/api/messages

┌──────────────────────────────────────────────────────────────────┐
│ 1. User's Browser                                                │
│    └─ GET http://example.com/api/messages                        │
└────────────┬─────────────────────────────────────────────────────┘
             │
             │ HTTP Request
             ▼
┌──────────────────────────────────────────────────────────────────┐
│ 2. AWS ALB (Application Load Balancer)                           │
│    └─ Listener: Port 80                                          │
│       └─ Rule: IF path matches "/api*"                           │
│          └─ Forward to Backend Target Group                      │
└────────────┬─────────────────────────────────────────────────────┘
             │
             │ Route /api/* → Backend
             ▼
┌──────────────────────────────────────────────────────────────────┐
│ 3. Backend Target Group (Port 8080)                              │
│    └─ Load balances across healthy ECS tasks                     │
│       ├─ Check health: GET /ping → expects 200                   │
│       └─ Route to available task                                 │
└────────────┬─────────────────────────────────────────────────────┘
             │
             │ Forward to ECS Container
             ▼
┌──────────────────────────────────────────────────────────────────┐
│ 4. ECS Fargate Task (Go Backend)                                 │
│    ├─ Container: fullstack-docker-backend:latest                │
│    ├─ Port: 8080                                                 │
│    ├─ Handler: GET /messages                                     │
│    │  └─ Gin router processes request                            │
│    └─ Environment Variables:                                     │
│       ├─ POSTGRES_HOST=rds-endpoint                              │
│       ├─ REDIS_HOST=elasticache-endpoint                         │
│       └─ REQUEST_ORIGIN=http://localhost                         │
└────────────┬─────────────────────────────────────────────────────┘
             │
             │ SQL Query: SELECT * FROM messages
             ▼
┌──────────────────────────────────────────────────────────────────┐
│ 5. AWS RDS PostgreSQL (Port 5432)                                │
│    ├─ Database: postgres                                         │
│    ├─ Table: messages (auto-created on first run)                │
│    └─ Query executed                                             │
│       ├─ SELECT id, body FROM messages                           │
│       └─ Return rows                                             │
└────────────┬─────────────────────────────────────────────────────┘
             │
             │ Response: [{"id":1,"body":"pong"}]
             ▼
┌──────────────────────────────────────────────────────────────────┐
│ 6. Go Backend Response                                            │
│    └─ JSON: {"messages": [{"id":1,"body":"pong"}]}               │
│       └─ HTTP 200 OK                                             │
└────────────┬─────────────────────────────────────────────────────┘
             │
             │ HTTP Response (200)
             ▼
┌──────────────────────────────────────────────────────────────────┐
│ 7. ALB (Response Pass-through)                                   │
│    └─ Forward response to client                                 │
└────────────┬─────────────────────────────────────────────────────┘
             │
             │ HTTP Response
             ▼
┌──────────────────────────────────────────────────────────────────┐
│ 8. User's Browser                                                │
│    └─ Display JSON response                                      │
│       {                                                          │
│         "messages": [{"id": 1, "body": "pong"}]                 │
│       }                                                           │
└──────────────────────────────────────────────────────────────────┘

LOGGING:
  └─ CloudWatch Log Group: /ecs/fullstack-docker-dev-backend
     └─ Log Stream: ecs/backend/abc123...
        └─ Log Entry: [INFO] GET /messages - 200 OK - 45ms
```

## Terraform Deployment State Transitions

```
┌─────────────────────────────────────────────────────────────────────┐
│               STATE: No Infrastructure                              │
│               Action: terraform apply (first time)                  │
└────────────────────────┬────────────────────────────────────────────┘
                         │
                         ▼
                    CREATING RESOURCES
                    ├─ VPC (10.0.0.0/16)
                    ├─ 2 NAT Gateways (high availability)
                    ├─ Security Groups (4 types)
                    ├─ RDS PostgreSQL (db.t3.micro, 7-day backups)
                    ├─ ElastiCache Redis (cache.t3.micro)
                    ├─ ECR Repositories (backend, frontend)
                    ├─ ECS Cluster
                    ├─ ALB (Application Load Balancer)
                    ├─ ECS Services (backend + frontend)
                    ├─ IAM Roles (task execution, task roles)
                    ├─ CloudWatch Log Groups
                    ├─ Auto Scaling Policies
                    └─ (Total: ~50+ resources created)
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│               STATE: Production Infrastructure                       │
│               Action: Deploy new version (push Docker image)         │
└────────────────────────┬────────────────────────────────────────────┘
                         │
                         ▼
                    UPDATING RESOURCES
                    ├─ ECS Task Definition (new image URI)
                    ├─ ECS Service (rolling update)
                    │  ├─ New tasks launched with new version
                    │  ├─ Old tasks gracefully drained
                    │  └─ ALB removes old targets, adds new ones
                    ├─ Blue-Green Deployment (implicit)
                    └─ Zero-downtime deployment
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────────┐
│               STATE: Updated Production Infrastructure               │
│               Services running new version                           │
└─────────────────────────────────────────────────────────────────────┘

SCALING UP EXAMPLE:
terraform apply -var="backend_desired_count=3"

    ├─ Current state: 1 backend task running
    ├─ New state: 3 backend tasks desired
    │  ├─ Task 2 launched in AZ-1
    │  ├─ Task 3 launched in AZ-2
    │  └─ ALB adds 2 new targets
    └─ Rolling update in progress

ROLLBACK EXAMPLE (manual):
git revert abc123def456
terraform apply  # Redeploys previous version

    ├─ Detect task definition change
    ├─ Launch tasks with previous image
    ├─ Gracefully drain current tasks
    └─ Zero-downtime rollback
```

---

These diagrams illustrate the complete flow of your production DevOps infrastructure!
