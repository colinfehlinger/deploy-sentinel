export interface DeploymentRecord {
  pk: string;                // SERVICE#<service-name>
  sk: string;                // DEPLOY#<timestamp>#<deploy-id>
  deploymentId: string;
  serviceName: string;
  environment: string;
  status: DeploymentStatus;
  commitSha: string;
  ref: string;
  triggeredBy: string;
  description: string;
  startedAt: string;         // ISO 8601
  completedAt?: string;      // ISO 8601
  createdAt: string;         // ISO 8601
  updatedAt: string;         // ISO 8601
  metadata?: Record<string, string>;
}

export type DeploymentStatus =
  | 'pending'
  | 'in_progress'
  | 'success'
  | 'failure'
  | 'error'
  | 'queued';

export interface DeploymentEvent {
  action: string;
  deploymentId: string;
  serviceName: string;
  environment: string;
  commitSha: string;
  ref: string;
  triggeredBy: string;
  description: string;
  status: DeploymentStatus;
  timestamp: string;
  repositoryFullName: string;
  metadata?: Record<string, string>;
}

export interface HealthCheckResult {
  status: 'healthy' | 'degraded' | 'unhealthy';
  checks: {
    dynamodb: { status: string; latencyMs: number };
    sqs: { status: string; latencyMs: number };
  };
  uptime: number;
  version: string;
}

export interface DeploymentQueryParams {
  service?: string;
  environment?: string;
  status?: DeploymentStatus;
  limit?: number;
  cursor?: string;
}
