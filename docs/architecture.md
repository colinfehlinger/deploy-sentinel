# Architecture Walkthrough

> Written to read like an interview answer to "Walk me through the architecture."

## The Problem

Platform teams need deployment visibility: what's deployed where, who triggered it, did it succeed, and how long did it take. Without this, debugging production issues means grepping CI logs across repos. Deploy Sentinel solves this by ingesting deployment events from GitHub and providing a single query API.

## Request Flow

A GitHub deployment event hits our **Application Load Balancer** over TLS in a public subnet. The ALB terminates TLS using an ACM certificate and routes to our **API service** running on ECS Fargate in **private subnets** — the API has no direct internet access.

The API validates the webhook's HMAC signature against a secret stored in **AWS Secrets Manager** (injected at container start via ECS task definition `secrets`, never in code). If valid, it transforms the payload into a structured event and enqueues it to **SQS**, returning `202 Accepted` immediately. This decoupling is intentional: ingestion is fast and reliable regardless of processing speed.

A **Worker service** (also ECS Fargate, private subnet) long-polls SQS. For each message, it enriches the event with metadata and writes a structured record to **DynamoDB**. We chose DynamoDB because our access patterns are pure key-value: lookup by deployment ID, or range query by service name + timestamp. No joins, no transactions, no connection pooling headaches.

If the worker fails to process a message after **3 retries**, SQS automatically moves it to a **dead-letter queue**. We alarm on DLQ depth > 0 because poison messages should always be investigated — they represent data we're silently losing.

## Network Architecture

```
Internet
    │
    ▼
┌─────────────────────────────────┐
│  Public Subnets (2 AZs)        │
│  ┌─────────┐    ┌────────────┐ │
│  │   ALB   │    │ NAT Gateway│ │
│  └────┬────┘    └─────┬──────┘ │
│───────│───────────────│────────│
│  Private Subnets (2 AZs)      │
│  ┌────┴────┐    ┌─────┴──────┐ │
│  │ API     │    │  Worker    │ │
│  │ (ECS)   │    │  (ECS)    │ │
│  └─────────┘    └────────────┘ │
└─────────────────────────────────┘
          │              │
    ┌─────┴──────┐  ┌────┴─────┐
    │  DynamoDB  │  │   SQS    │
    └────────────┘  └──────────┘
```

The ALB lives in public subnets because it needs to receive internet traffic. ECS tasks live in private subnets — they reach AWS APIs (DynamoDB, SQS, CloudWatch) through a NAT Gateway. In dev, we use a single NAT Gateway (~$32/mo savings); in prod, we deploy one per AZ for high availability.

Security groups are scoped tightly: the ALB accepts 80/443 from the internet, but only forwards to port 3000 on the ECS security group. The ECS security group allows inbound only from the ALB security group, and outbound only on 443 (HTTPS to AWS APIs).

## IAM Design

Each service has its own task role with explicit, minimal permissions:

- **API task role**: `dynamodb:GetItem`, `dynamodb:Query` (read-only), `sqs:SendMessage` (enqueue only)
- **Worker task role**: `dynamodb:PutItem`, `dynamodb:UpdateItem`, `dynamodb:GetItem`, `dynamodb:Query` (read-write), `sqs:ReceiveMessage`, `sqs:DeleteMessage` (consume only)

The API cannot write to DynamoDB. The Worker cannot send to SQS. Both can push X-Ray traces and CloudWatch metrics (`*` resource is required by AWS for these services — documented exception).

## Autoscaling Strategy

- **API**: Target-tracking on CPU utilization at 70%. Simple, predictable, and correct for a request-driven HTTP service. Min 1 / max 4 tasks.
- **Worker**: Step scaling on SQS `ApproximateNumberOfMessagesVisible`. When queue depth crosses 100 messages, add a task. Above 500, add 3 more. This directly ties compute to work backlog.

ECS services use the **deployment circuit breaker** with `rollback = true`. If new tasks fail health checks during a deployment, ECS automatically rolls back to the previous task definition — no manual intervention needed.

## Observability

7 CloudWatch alarms, each chosen for signal-to-noise ratio:

1. **API 5xx rate** > 10 in 5 min — app errors, likely a bug or downstream failure
2. **API P99 latency** > 2s — performance degradation
3. **Queue depth** > 500 — worker can't keep up
4. **DLQ non-empty** — always investigate, represents data loss
5. **API task count** < 1 — service is down
6. **Worker task count** < 1 — processing stopped
7. **Unhealthy ALB targets** — containers failing health checks

All alarms route to an SNS topic. The CloudWatch dashboard shows ALB metrics, ECS CPU/memory, SQS queue depth, and custom worker metrics (events processed, processing duration, errors) in a single view.

## CI/CD Pipeline

**PR Checks:** lint, unit tests, `terraform fmt`, `terraform validate`, Trivy filesystem scan, tfsec for IaC misconfigurations. All run in parallel.

**Deploy to Dev:** On merge to main — build Docker images with BuildKit caching, push to ECR tagged with git SHA, `terraform apply`, force ECS service update, wait for stability.

**Deploy to Prod:** Manual trigger via `workflow_dispatch` with the image tag to promote. Pulls from dev ECR, re-tags for prod, applies prod Terraform, updates ECS.

**Auth:** GitHub Actions uses OIDC federation to assume an AWS IAM role — no long-lived access keys anywhere. The OIDC trust is scoped to this specific repo.

**Drift Detection:** Weekly cron runs `terraform plan` on both environments. If drift is detected, it automatically opens a GitHub issue with the plan output.

## Cost Optimization

The dev environment costs ~$70/mo (NAT Gateway is ~$32 of that). Cost reduction strategies:
- Tear down dev when not using it (`make teardown ENV=dev`)
- VPC endpoints for DynamoDB and S3 (free, reduces NAT data charges)
- DynamoDB on-demand billing ($0 at idle)
- Fargate Spot for dev worker (up to 70% savings)
- ECR lifecycle policy keeps only 10 images

## Key Tradeoffs

| Decision | Alternative | Why This Choice |
|---|---|---|
| ECS Fargate | EKS | 2 services don't justify Kubernetes operational overhead |
| DynamoDB | RDS Postgres | Key-value access patterns, zero connection management, $0 at idle |
| Single NAT (dev) | Dual NAT | $32/mo savings, acceptable availability tradeoff for dev |
| SQS | EventBridge | Need reliable delivery with DLQ, not event routing/filtering |
| Monorepo | Polyrepo | Shared types/config between services, atomic changes |
