# ADR 004: Monorepo Structure

## Status
Accepted

## Context
Deploy Sentinel has 3 code packages (shared, api, worker) and Terraform infrastructure. We need to decide between a monorepo (all code in one repository) or a polyrepo (separate repositories per service + infra).

## Decision
Use a **monorepo**.

## Rationale

**Shared code:** The API and worker share types, config schemas, and the DynamoDB client library. In a polyrepo, we'd need to either:
- Publish `@deploy-sentinel/shared` as an npm package (overhead, versioning complexity)
- Duplicate the shared code (maintenance burden, drift risk)

**Atomic changes:** A single PR can modify Terraform infrastructure AND application code together. This is critical when changes span layers — e.g., adding a new environment variable requires both a Terraform task definition change and an application config schema update.

**Simpler CI/CD:** One repository means one set of GitHub Actions workflows. No cross-repo triggering or dependency management.

**At this scale, polyrepo overhead isn't justified.** Polyrepo shines when teams own different services independently, need separate release cadences, or when the repo size causes performance issues. None of these apply to a 2-service project.

## Consequences
- All services share the same CI pipeline (changes to `shared/` trigger rebuilds of both api and worker)
- Docker builds use the repo root as context (to COPY shared code)
- Folder structure must be clear and well-organized to avoid confusion
