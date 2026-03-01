import {
  SQSClient,
  ReceiveMessageCommand,
  DeleteMessageCommand,
} from '@aws-sdk/client-sqs';
import { getConfig } from '@deploy-sentinel/shared';
import { processMessage } from './processor';
import { publishMetric } from './metrics';
import { logger } from './logger';

export async function startPolling(shouldStop: () => boolean): Promise<void> {
  const config = getConfig();
  const client = new SQSClient({
    region: config.AWS_REGION,
    ...(config.SQS_ENDPOINT && { endpoint: config.SQS_ENDPOINT }),
  });

  logger.info('Starting SQS long-poll loop');

  while (!shouldStop()) {
    try {
      const response = await client.send(
        new ReceiveMessageCommand({
          QueueUrl: config.SQS_QUEUE_URL,
          MaxNumberOfMessages: 10,
          WaitTimeSeconds: 20, // Long polling
          VisibilityTimeout: 60,
          MessageAttributeNames: ['All'],
        })
      );

      const messages = response.Messages ?? [];
      if (messages.length === 0) continue;

      logger.info({ count: messages.length }, 'Received messages from SQS');

      for (const message of messages) {
        const start = Date.now();
        try {
          await processMessage(message);
          await client.send(
            new DeleteMessageCommand({
              QueueUrl: config.SQS_QUEUE_URL,
              ReceiptHandle: message.ReceiptHandle!,
            })
          );
          const durationMs = Date.now() - start;
          await publishMetric('EventsProcessed', 1, 'Count');
          await publishMetric('ProcessingDuration', durationMs, 'Milliseconds');
          logger.info({ messageId: message.MessageId, durationMs }, 'Message processed');
        } catch (err) {
          const durationMs = Date.now() - start;
          await publishMetric('EventProcessingErrors', 1, 'Count');
          logger.error(
            { err, messageId: message.MessageId, durationMs },
            'Failed to process message — will be retried by SQS'
          );
          // Don't delete — SQS will retry after visibility timeout expires
        }
      }
    } catch (err) {
      logger.error({ err }, 'Error polling SQS');
      // Back off on polling errors to avoid tight loop
      await new Promise((resolve) => setTimeout(resolve, 5000));
    }
  }

  logger.info('Polling loop stopped');
}
