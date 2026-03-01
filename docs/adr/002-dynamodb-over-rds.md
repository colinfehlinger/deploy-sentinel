# ADR 002: DynamoDB over RDS PostgreSQL

## Status
Accepted

## Context
We need persistent storage for deployment records. Access patterns:
1. Get deployment by ID (point read)
2. List deployments by service name, sorted by timestamp (range query)
3. Write deployment records from the worker

No joins, no transactions, no complex aggregations in the critical path.

## Decision
Use **DynamoDB** with on-demand billing mode.

## Rationale

**Access patterns are key-value.** Our two query patterns (lookup by ID, range query by service+timestamp) map directly to DynamoDB's partition key + sort key model. A GSI on `deploymentId` handles direct lookups.

**Operational simplicity:**
- No connection pooling (critical for Fargate — task count fluctuates with autoscaling)
- No VPC database subnet, security group, or subnet group
- No patching, backups configuration, or version upgrades
- No RDS proxy ($$$) to handle connection management

**Cost at low traffic: $0.** On-demand billing means we pay per request. At portfolio-project traffic levels, this is essentially free. RDS would cost ~$15/mo minimum for the smallest instance.

**Point-in-time recovery** is enabled for data protection.

## Tradeoff
If we needed:
- Complex queries (joins across tables, full-text search)
- ACID transactions across multiple records
- Rich analytics/reporting (GROUP BY, window functions)

...then RDS PostgreSQL would be the right choice. Our access patterns don't require any of these.

## Consequences
- Table design uses single-table pattern with composite keys (`SERVICE#name` / `DEPLOY#timestamp#id`)
- No ORM — we use the AWS SDK DynamoDB Document Client directly
- Analytics/reporting would need a separate solution (export to S3 + Athena) if required later
