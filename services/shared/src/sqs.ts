import { SQSClient, SendMessageCommand, GetQueueAttributesCommand } from '@aws-sdk/client-sqs';
import { getConfig } from './config';
import { DeploymentEvent } from './types';

let sqsClient: SQSClient | undefined;

export function getSqsClient(): SQSClient {
  if (!sqsClient) {
    const config = getConfig();
    sqsClient = new SQSClient({
      region: config.AWS_REGION,
      ...(config.SQS_ENDPOINT && { endpoint: config.SQS_ENDPOINT }),
    });
  }
  return sqsClient;
}

export async function enqueueDeploymentEvent(event: DeploymentEvent): Promise<string> {
  const config = getConfig();
  const client = getSqsClient();

  const result = await client.send(
    new SendMessageCommand({
      QueueUrl: config.SQS_QUEUE_URL,
      MessageBody: JSON.stringify(event),
      MessageAttributes: {
        eventType: {
          DataType: 'String',
          StringValue: event.action,
        },
        serviceName: {
          DataType: 'String',
          StringValue: event.serviceName,
        },
      },
    })
  );

  return result.MessageId!;
}

export async function checkQueueHealth(): Promise<{ status: string; latencyMs: number }> {
  const config = getConfig();
  const client = getSqsClient();
  const start = Date.now();

  try {
    await client.send(
      new GetQueueAttributesCommand({
        QueueUrl: config.SQS_QUEUE_URL,
        AttributeNames: ['ApproximateNumberOfMessages'],
      })
    );
    return { status: 'ok', latencyMs: Date.now() - start };
  } catch (err) {
    return { status: 'error', latencyMs: Date.now() - start };
  }
}
