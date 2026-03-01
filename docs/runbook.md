# Deploy Sentinel Runbook

## Quick Reference

| Action | Command |
|---|---|
| Check API health | `curl https://<alb-dns>/health` |
| View API logs | `aws logs tail /ecs/deploy-sentinel-<env>/api --follow` |
| View worker logs | `aws logs tail /ecs/deploy-sentinel-<env>/worker --follow` |
| Check ECS services | `aws ecs describe-services --cluster deploy-sentinel-<env> --services api worker` |
| Check queue depth | `aws sqs get-queue-attributes --queue-url <url> --attribute-names ApproximateNumberOfMessagesVisible` |
| Check DLQ | `aws sqs get-queue-attributes --queue-url <dlq-url> --attribute-names ApproximateNumberOfMessagesVisible` |
| Rollback API | `aws ecs update-service --cluster deploy-sentinel-<env> --service api --task-definition <prev-revision>` |
| Dashboard | `https://us-east-1.console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards:name=deploy-sentinel-<env>` |

---

## Common Failure Modes

### 1. API Returning 5xx

**Symptoms:** CloudWatch alarm `api-5xx` firing, ALB 5xx count increasing.

**Investigation:**
1. Check API logs for error messages:
   ```bash
   aws logs tail /ecs/deploy-sentinel-dev/api --follow --format short
   ```
2. Is the container OOMKilled? Check stopped task reason:
   ```bash
   aws ecs list-tasks --cluster deploy-sentinel-dev --service-name api --desired-status STOPPED
   aws ecs describe-tasks --cluster deploy-sentinel-dev --tasks <task-arn>
   ```
3. Is DynamoDB throttling? Check `ConsumedReadCapacityUnits` in CloudWatch.
4. Is the container crashing on startup? Check the `startedAt` vs `stoppedAt` timing.

**Resolution:**
- If bad deploy: rollback to previous task definition revision
- If OOM: increase `api_memory` in Terraform variables
- If DynamoDB throttle: table is on-demand, shouldn't throttle — investigate access patterns

---

### 2. Queue Backlog Growing

**Symptoms:** CloudWatch alarm `queue-depth` firing, `ApproximateNumberOfMessagesVisible` > 500.

**Investigation:**
1. Is the worker running?
   ```bash
   aws ecs describe-services --cluster deploy-sentinel-dev --services worker --query 'services[0].{running:runningCount,desired:desiredCount}'
   ```
2. Check worker logs for processing errors
3. Is DynamoDB write throttling? Check `ConsumedWriteCapacityUnits`
4. Check if autoscaling is adding worker tasks

**Resolution:**
- If worker crashed: ECS should auto-restart. Check desired vs running count
- If processing is slow: check DynamoDB latency metrics
- Manual scale: `aws ecs update-service --cluster deploy-sentinel-dev --service worker --desired-count 4`

---

### 3. Dead Letter Queue Has Messages

**Symptoms:** CloudWatch alarm `dlq-nonempty` firing.

**Investigation:**
1. Inspect DLQ messages:
   ```bash
   aws sqs receive-message --queue-url <dlq-url> --max-number-of-messages 5 --attribute-names All --message-attribute-names All
   ```
2. Read the message body — correlate with worker error logs at the timestamp
3. Identify why the message failed 3 times (malformed payload? DynamoDB error? bug?)

**Resolution:**
1. Fix the root cause (deploy a code fix)
2. Redrive messages back to the main queue:
   ```bash
   aws sqs start-message-move-task --source-arn <dlq-arn> --destination-arn <main-queue-arn>
   ```
3. **Never** delete DLQ messages without understanding the failure

---

### 4. Deployment Stuck / Rolling Back

**Symptoms:** ECS service events show repeated task start/stop cycles.

**Investigation:**
1. Check service events:
   ```bash
   aws ecs describe-services --cluster deploy-sentinel-dev --services api --query 'services[0].events[:10]'
   ```
2. Is the new task failing health checks? Check container logs for startup errors
3. Is the image pull failing? Check ECR repository for the expected tag

**Resolution:**
- ECS circuit breaker should auto-rollback after sustained failures
- Manual rollback:
  ```bash
  # Find previous task definition
  aws ecs list-task-definitions --family-prefix deploy-sentinel-api-dev --sort DESC --max-items 5
  # Roll back
  aws ecs update-service --cluster deploy-sentinel-dev --service api --task-definition <prev-revision>
  ```

---

### 5. Terraform Drift Detected

**Symptoms:** Weekly drift detection GitHub Action creates an issue.

**Investigation:**
1. Read the plan output in the GitHub issue
2. Determine source of drift: console change? AWS service update? Deleted resource?

**Resolution:**
- If intentional console change: update Terraform to match
- If unintentional: run `terraform apply` to correct
- **Never** apply without reading the full plan first

---

## Operational Procedures

### Manual Deployment

```bash
# Deploy to dev
make deploy ENV=dev

# Deploy to prod (via GitHub Actions only — requires approval)
# Go to Actions → Deploy to Prod → Run workflow
```

### Scaling

```bash
# Manual scale API
aws ecs update-service --cluster deploy-sentinel-dev --service api --desired-count 3

# Check autoscaling policies
aws application-autoscaling describe-scaling-policies --service-namespace ecs
```

### Secrets Rotation

1. Generate new webhook secret
2. Update in Secrets Manager:
   ```bash
   aws secretsmanager put-secret-value --secret-id deploy-sentinel-dev-webhook-secret --secret-string "new-secret-here"
   ```
3. Update GitHub webhook to use the new secret
4. Force ECS service restart (pulls new secret):
   ```bash
   aws ecs update-service --cluster deploy-sentinel-dev --service api --force-new-deployment
   ```
