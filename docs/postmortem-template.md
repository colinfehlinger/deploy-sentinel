# Postmortem: [Title]

**Date:** YYYY-MM-DD | **Severity:** SEV-1/2/3 | **Duration:** Xm

## Summary

One-sentence description of what happened and the impact.

## Impact

- Users/services affected:
- Duration:
- Data loss: yes/no
- Deployment events missed:

## Timeline (all times UTC)

| Time | Event |
|---|---|
| HH:MM | First alert fired |
| HH:MM | On-call acknowledged |
| HH:MM | Investigation began |
| HH:MM | Root cause identified |
| HH:MM | Fix deployed / mitigation applied |
| HH:MM | Verified recovered |
| HH:MM | All-clear declared |

## Root Cause

What actually broke and why. Be specific — name the exact code, config, or infrastructure change that caused the issue.

## Resolution

What was done to fix it. Include commands run, code changes, config updates.

## Detection

How was this incident detected? Was it an alarm, a user report, or discovered incidentally?

- Time to detect:
- Alert that fired:
- Was detection fast enough? If not, what would improve it?

## Lessons Learned

### What went well
-

### What went poorly
-

### Where we got lucky
-

## Action Items

| Priority | Item | Owner | Status |
|---|---|---|---|
| P0 | Prevent recurrence: ... | | |
| P1 | Improve detection: ... | | |
| P2 | Improve process: ... | | |

---

# Simulated Incident: Bad Deploy Causes 5xx Spike

**Date:** 2025-03-15 | **Severity:** SEV-2 | **Duration:** 12m

## Summary

A deploy introduced a bug in the webhook validation path that caused all POST /webhooks/github requests to return 500. GET endpoints were unaffected.

## Impact

- Deployment events from 3 services were not recorded during the 12-minute outage
- No events were permanently lost — GitHub retried webhook deliveries after recovery
- No data corruption

## Timeline (UTC)

| Time | Event |
|---|---|
| 14:32 | Deploy of commit `abc1234` to prod via CI/CD |
| 14:34 | CloudWatch alarm `api-5xx` fired (>10 in 5 min) |
| 14:36 | Checked ALB metrics, confirmed 100% 5xx on POST /webhooks |
| 14:38 | Checked ECS logs, found TypeError in webhook HMAC validation |
| 14:40 | Initiated rollback: updated ECS service to previous task definition |
| 14:42 | New tasks healthy, 5xx rate dropped to 0 |
| 14:44 | Verified: GitHub webhook deliveries succeeding, events flowing into DynamoDB |

## Root Cause

PR #47 refactored the config module and renamed `WEBHOOK_SECRET` to `GITHUB_WEBHOOK_SECRET`. The ECS task definition still referenced the old Secrets Manager key name, so the environment variable was `undefined` at runtime. The zod config schema had `.optional()` on the webhook secret (a convenience for local dev), so the app started successfully but crashed when the HMAC verification function tried to use `undefined` as the secret key.

## Resolution

1. Rolled back ECS service to previous task definition (2 minutes)
2. Fixed config schema to make `WEBHOOK_SECRET` required in production
3. Added integration test verifying all required env vars resolve in task definition
4. Deployed fix in follow-up PR #48

## Detection

CloudWatch alarm `api-5xx` fired within 2 minutes of deployment. Detection time was acceptable.

## Lessons Learned

### What went well
- Alarm fired within 2 minutes of the bad deploy
- Rollback took under 5 minutes
- ECS circuit breaker would have caught this automatically, but manual rollback was faster

### What went poorly
- Config validation didn't catch the missing secret in production because it was marked `.optional()`
- No pre-deploy smoke test to catch this before traffic was routed

### Where we got lucky
- GitHub retries webhook deliveries on 5xx, so no events were permanently lost
- Only POST /webhooks was affected; GET /deployments continued working

## Action Items

| Priority | Item | Owner | Status |
|---|---|---|---|
| P0 | Make WEBHOOK_SECRET required in production config schema | | Done |
| P1 | Add CI test that validates task definition env vars match config schema | | Done |
| P2 | Add pre-deploy smoke test (hit /health + /webhooks with test payload) | | Open |
| P2 | Review all config schema fields for inappropriate `.optional()` usage | | Open |
