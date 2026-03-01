import {
  CloudWatchClient,
  PutMetricDataCommand,
  StandardUnit,
} from '@aws-sdk/client-cloudwatch';
import { getConfig } from '@deploy-sentinel/shared';
import { logger } from './logger';

let cwClient: CloudWatchClient | undefined;

function getClient(): CloudWatchClient {
  if (!cwClient) {
    const config = getConfig();
    cwClient = new CloudWatchClient({ region: config.AWS_REGION });
  }
  return cwClient;
}

export async function publishMetric(
  name: string,
  value: number,
  unit: string
): Promise<void> {
  // Skip metrics in development
  if (process.env.NODE_ENV === 'development') return;

  try {
    const client = getClient();
    await client.send(
      new PutMetricDataCommand({
        Namespace: 'DeploySentinel',
        MetricData: [
          {
            MetricName: name,
            Value: value,
            Unit: unit as StandardUnit,
            Timestamp: new Date(),
            Dimensions: [
              { Name: 'Environment', Value: process.env.DEPLOY_ENV ?? 'dev' },
            ],
          },
        ],
      })
    );
  } catch (err) {
    // Don't fail message processing because of metrics
    logger.warn({ err, metric: name }, 'Failed to publish metric');
  }
}
