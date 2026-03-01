# Deploy Sentinel

Production-grade deployment event pipeline and status API built on AWS with Terraform IaC.

Ingests GitHub deployment webhooks, processes events asynchronously via SQS, stores structured deployment records in DynamoDB, and exposes a query API for deployment visibility across services.

## Why This Exists

Every platform team needs a single source of truth for "what's deployed where." Deploy Sentinel is that system — built with the same infrastructure patterns used by real production teams: event-driven architecture, least-privilege IAM, multi-environment promotion, automated rollback, and full observability.

## Architecture

```
GitHub Webhooks ──→ ALB (TLS) ──→ ECS Fargate API ──→ SQS Queue ──→ ECS Fargate Worker ──→ DynamoDB
                                       │                                                       │
                                       └────── GET /deployments ◄──────── Query ◄──────────────┘
```

**Key design decisions:**
- [ECS Fargate over EKS](docs/adr/001-ecs-over-eks.md) — right-sized for 2 services, no K8s overhead
- [DynamoDB over RDS](docs/adr/002-dynamodb-over-rds.md) — key-value access patterns, $0 at low traffic
- [Single NAT Gateway in dev](docs/adr/003-single-nat-gateway.md) — saves $32/mo, dual NAT in prod
- [Monorepo structure](docs/adr/004-monorepo.md) — shared types, atomic infra+app changes

## What This Demonstrates

| Skill Area | Implementation |
|---|---|
| **IaC** | Terraform modules (networking, compute, data, IAM, observability, security), remote state with S3+DynamoDB locking, dev/prod env separation |
| **CI/CD** | GitHub Actions with OIDC auth (no long-lived keys), PR checks (lint/test/tfsec/trivy), automated dev deploy, manual prod promotion |
| **Networking** | VPC with public/private subnets across 2 AZs, NAT Gateway, ALB with TLS, security groups scoped per service |
| **Compute** | ECS Fargate with autoscaling (CPU-based for API, queue-depth for worker), deployment circuit breaker with auto-rollback |
| **Async** | SQS with DLQ (maxReceiveCount=3), visibility timeout, structured retry handling |
| **Observability** | CloudWatch dashboard, 7 targeted alarms (5xx rate, P99 latency, queue depth, DLQ, task count, unhealthy hosts), structured JSON logs, custom metrics |
| **Security** | Least-privilege IAM per service, HMAC webhook verification, Secrets Manager injection, WAF rate limiting, private networking, Trivy+tfsec in CI |

## Quick Start

### Prerequisites
- AWS account with CLI configured
- Terraform >= 1.5
- Docker
- Node.js 20
- GitHub CLI (`gh`)

### Local Development
```bash
# Start local DynamoDB + SQS + services
make dev-up

# View logs
make dev-logs

# Test the API
curl http://localhost:3000/health

# Send a test webhook
curl -X POST http://localhost:3000/webhooks/github \
  -H "Content-Type: application/json" \
  -H "X-GitHub-Event: deployment" \
  -H "X-Hub-Signature-256: sha256=$(echo -n '{}' | openssl dgst -sha256 -hmac 'local-dev-secret-min16' | awk '{print $2}')" \
  -d '{"deployment":{"id":1,"sha":"abc123","ref":"main","environment":"production","description":"Test","created_at":"2025-01-01T00:00:00Z"},"repository":{"name":"my-service","full_name":"org/my-service"},"sender":{"login":"developer"}}'

# Query deployments
curl http://localhost:3000/deployments
```

### AWS Deployment
```bash
# 1. Bootstrap (one-time): creates S3 state bucket, DynamoDB lock, OIDC provider
make bootstrap

# 2. Deploy to dev
make deploy ENV=dev

# 3. Promote to prod (manual via GitHub Actions workflow_dispatch)
```

### Teardown
```bash
# Destroy a single environment
make teardown ENV=dev

# Destroys all resources except TF state bucket and lock table
```

## Project Structure

```
deploy-sentinel/
├── infra/
│   ├── bootstrap/           # One-time: S3 bucket, DynamoDB lock, OIDC
│   ├── modules/
│   │   ├── networking/      # VPC, subnets, NAT, IGW, security groups
│   │   ├── compute/         # ECS, ALB, ECR, autoscaling
│   │   ├── data/            # DynamoDB, SQS, Secrets Manager
│   │   ├── iam/             # Task roles, execution roles (least privilege)
│   │   ├── observability/   # CloudWatch dashboard, alarms, SNS
│   │   └── security/        # WAF web ACL
│   └── environments/
│       ├── dev/             # Dev env config (1 NAT, smaller tasks)
│       └── prod/            # Prod env config (2 NAT, WAF, larger tasks)
├── services/
│   ├── api/                 # Express API: webhooks + deployments endpoints
│   ├── worker/              # SQS poller + event processor
│   └── shared/              # Shared types, config, DynamoDB client
├── .github/workflows/       # CI, deploy-dev, deploy-prod, drift detection
├── scripts/                 # bootstrap, deploy, teardown
├── docs/                    # Architecture, ADRs, runbook, postmortem
├── docker-compose.yml       # Local dev environment
└── Makefile                 # All commands
```

## Cost Estimate (Dev)

| Service | Monthly Cost |
|---|---|
| NAT Gateway | ~$32 |
| ALB | ~$16 |
| ECS Fargate (2 tasks) | ~$18 |
| CloudWatch | ~$3 |
| DynamoDB (on-demand) | ~$0 |
| SQS | ~$0 |
| **Total** | **~$70/mo** |

Tear down when not in use: `make teardown ENV=dev` — rebuild takes ~5 minutes.

## Documentation

- [Architecture Walkthrough](docs/architecture.md) — interview-ready deep dive
- [Runbook](docs/runbook.md) — operational procedures and debugging
- [Postmortem Template](docs/postmortem-template.md) — incident response process
- [ADR: ECS over EKS](docs/adr/001-ecs-over-eks.md)
- [ADR: DynamoDB over RDS](docs/adr/002-dynamodb-over-rds.md)
- [ADR: Single NAT Gateway](docs/adr/003-single-nat-gateway.md)
- [ADR: Monorepo](docs/adr/004-monorepo.md)
