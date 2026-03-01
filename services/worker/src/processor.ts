import { Message } from '@aws-sdk/client-sqs';
import {
  createDeployment,
  updateDeploymentStatus,
  getDeploymentById,
  type DeploymentEvent,
} from '@deploy-sentinel/shared';
import { logger } from './logger';

export async function processMessage(message: Message): Promise<void> {
  if (!message.Body) {
    logger.warn({ messageId: message.MessageId }, 'Empty message body');
    return;
  }

  const event: DeploymentEvent = JSON.parse(message.Body);

  logger.info(
    {
      action: event.action,
      deploymentId: event.deploymentId,
      service: event.serviceName,
      status: event.status,
    },
    'Processing deployment event'
  );

  if (event.action === 'deployment_created') {
    const record = await createDeployment(event);
    logger.info(
      { deploymentId: record.deploymentId, service: record.serviceName },
      'Deployment record created'
    );
    return;
  }

  if (event.action === 'deployment_status_updated') {
    // Check if deployment exists; if not, create it (handles out-of-order delivery)
    const existing = await getDeploymentById(event.deploymentId);
    if (!existing) {
      logger.info(
        { deploymentId: event.deploymentId },
        'Deployment not found, creating from status event'
      );
      await createDeployment(event);
      return;
    }

    const completedAt =
      event.status === 'success' || event.status === 'failure' || event.status === 'error'
        ? event.timestamp
        : undefined;

    await updateDeploymentStatus(
      existing.serviceName,
      existing.startedAt,
      existing.deploymentId,
      event.status,
      completedAt
    );

    logger.info(
      { deploymentId: event.deploymentId, oldStatus: existing.status, newStatus: event.status },
      'Deployment status updated'
    );
    return;
  }

  logger.warn({ action: event.action }, 'Unknown event action');
}
