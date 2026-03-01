import { Router, Request, Response } from 'express';
import { DescribeTableCommand, DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { getConfig, checkQueueHealth, type HealthCheckResult } from '@deploy-sentinel/shared';

export const healthRouter = Router();

const startTime = Date.now();
const VERSION = process.env.npm_package_version ?? '1.0.0';

healthRouter.get('/', async (_req: Request, res: Response) => {
  const config = getConfig();

  // Check DynamoDB
  const ddbStart = Date.now();
  let ddbStatus = 'ok';
  try {
    const client = new DynamoDBClient({
      region: config.AWS_REGION,
      ...(config.DYNAMODB_ENDPOINT && { endpoint: config.DYNAMODB_ENDPOINT }),
    });
    await client.send(new DescribeTableCommand({ TableName: config.DYNAMODB_TABLE }));
  } catch {
    ddbStatus = 'error';
  }
  const ddbLatency = Date.now() - ddbStart;

  // Check SQS
  const sqsResult = await checkQueueHealth();

  const overallStatus =
    ddbStatus === 'ok' && sqsResult.status === 'ok' ? 'healthy' : 'degraded';

  const result: HealthCheckResult = {
    status: overallStatus,
    checks: {
      dynamodb: { status: ddbStatus, latencyMs: ddbLatency },
      sqs: { status: sqsResult.status, latencyMs: sqsResult.latencyMs },
    },
    uptime: Math.floor((Date.now() - startTime) / 1000),
    version: VERSION,
  };

  const httpStatus = overallStatus === 'healthy' ? 200 : 503;
  res.status(httpStatus).json(result);
});
