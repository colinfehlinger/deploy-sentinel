# ADR 003: Single NAT Gateway in Dev

## Status
Accepted

## Context
ECS tasks in private subnets need outbound internet access (to reach AWS API endpoints). NAT Gateways cost ~$32/mo each ($0.045/hr + $0.045/GB data processing). We need to balance cost with availability.

## Decision
- **Dev:** 1 NAT Gateway (single AZ)
- **Prod:** 2 NAT Gateways (one per AZ)

## Rationale

A single NAT Gateway is a single point of failure. If the AZ it's in goes down, tasks in the other AZ lose outbound connectivity. This is unacceptable for production but fine for development.

**Cost impact:** Saving ~$32/mo in dev. For a portfolio project, this is significant.

**Prod configuration:** Each private subnet routes through a NAT Gateway in its own AZ. If one AZ fails, tasks in the other AZ continue operating normally.

## Alternatives Considered

**VPC endpoints instead of NAT:** Gateway endpoints for DynamoDB and S3 are free and eliminate NAT traffic for those services. Interface endpoints for SQS cost ~$7/mo/AZ. We enable VPC endpoints in prod to reduce NAT data charges and improve latency. In dev, we skip interface endpoints to save cost.

**No NAT (public subnets for ECS):** Possible for dev by setting `assign_public_ip = true` on ECS tasks. This is a security anti-pattern (tasks get public IPs) but could be acceptable as a documented dev-only cost optimization.

## Consequences
- Dev environment has a single AZ failure mode for outbound traffic
- Cost differential: ~$32/mo between dev and prod for NAT alone
- Documented as a conscious tradeoff, not an oversight
