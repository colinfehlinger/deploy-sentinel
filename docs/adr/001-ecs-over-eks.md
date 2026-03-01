# ADR 001: ECS Fargate over EKS

## Status
Accepted

## Context
We need a container orchestration platform for 2 services (API + worker). Options considered: ECS Fargate, EKS (managed Kubernetes), and plain EC2.

## Decision
Use **ECS Fargate**.

## Rationale

**EKS is overkill for 2 services.** Kubernetes brings powerful abstractions (CRDs, operators, service mesh, pod autoscaling) that we don't need. Our workload is 2 Fargate services with simple autoscaling rules. EKS adds:
- ~$75/mo for the control plane alone
- Operational burden: cluster upgrades, node groups, kubectl management, RBAC
- Learning curve overhead that doesn't translate to business value at this scale

**ECS Fargate gives us everything we need:**
- Zero cluster management (no nodes to patch)
- Native ALB integration via target groups
- Built-in deployment circuit breaker with automatic rollback
- Terraform-native (no Helm charts, no kubectl)
- Cost: pay only for running tasks, no control plane fee

**EC2 was rejected** because we'd need to manage instances, AMI updates, and capacity. Fargate removes all of that.

## Tradeoff
If this system grew to 10+ services, multi-region, or needed service mesh capabilities, EKS would be worth reconsidering. At 2 services, ECS is the right-sized choice.

## Consequences
- Simpler Terraform (no EKS module, no node groups, no K8s provider)
- Faster deployment (no rolling update across nodes)
- Limited to ECS-native features (no K8s ecosystem tools like ArgoCD, Istio)
