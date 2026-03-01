import { Router, Request, Response, json } from 'express';
import { enqueueDeploymentEvent, type DeploymentEvent, type DeploymentStatus } from '@deploy-sentinel/shared';
import { verifyWebhookSignature } from '../middleware/verify-webhook';
import { logger } from '../logger';

export const webhookRouter = Router();

webhookRouter.use(json());

webhookRouter.post('/github', verifyWebhookSignature, async (req: Request, res: Response) => {
  const eventType = req.headers['x-github-event'] as string;

  if (eventType === 'deployment') {
    const { deployment, repository, sender } = req.body;

    const event: DeploymentEvent = {
      action: 'deployment_created',
      deploymentId: String(deployment.id),
      serviceName: repository.name,
      environment: deployment.environment ?? 'production',
      commitSha: deployment.sha,
      ref: deployment.ref,
      triggeredBy: sender.login,
      description: deployment.description ?? '',
      status: 'pending',
      timestamp: deployment.created_at,
      repositoryFullName: repository.full_name,
    };

    const messageId = await enqueueDeploymentEvent(event);
    logger.info({ deploymentId: event.deploymentId, messageId }, 'Deployment event enqueued');

    res.status(202).json({ accepted: true, messageId });
    return;
  }

  if (eventType === 'deployment_status') {
    const { deployment_status, deployment, repository, sender } = req.body;

    const statusMap: Record<string, DeploymentStatus> = {
      pending: 'pending',
      in_progress: 'in_progress',
      success: 'success',
      failure: 'failure',
      error: 'error',
      queued: 'queued',
    };

    const event: DeploymentEvent = {
      action: 'deployment_status_updated',
      deploymentId: String(deployment.id),
      serviceName: repository.name,
      environment: deployment.environment ?? 'production',
      commitSha: deployment.sha,
      ref: deployment.ref,
      triggeredBy: sender.login,
      description: deployment_status.description ?? '',
      status: statusMap[deployment_status.state] ?? 'pending',
      timestamp: deployment_status.created_at,
      repositoryFullName: repository.full_name,
    };

    const messageId = await enqueueDeploymentEvent(event);
    logger.info(
      { deploymentId: event.deploymentId, status: event.status, messageId },
      'Deployment status event enqueued'
    );

    res.status(202).json({ accepted: true, messageId });
    return;
  }

  // Acknowledge but ignore other event types
  logger.debug({ eventType }, 'Ignoring unhandled GitHub event type');
  res.status(200).json({ ignored: true, eventType });
});
