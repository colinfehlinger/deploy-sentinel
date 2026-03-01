import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import {
  DynamoDBDocumentClient,
  PutCommand,
  GetCommand,
  QueryCommand,
  UpdateCommand,
} from '@aws-sdk/lib-dynamodb';
import { getConfig } from './config';
import { DeploymentRecord, DeploymentEvent, DeploymentQueryParams } from './types';

let docClient: DynamoDBDocumentClient | undefined;

export function getDocClient(): DynamoDBDocumentClient {
  if (!docClient) {
    const config = getConfig();
    const baseClient = new DynamoDBClient({
      region: config.AWS_REGION,
      ...(config.DYNAMODB_ENDPOINT && { endpoint: config.DYNAMODB_ENDPOINT }),
    });
    docClient = DynamoDBDocumentClient.from(baseClient, {
      marshallOptions: { removeUndefinedValues: true },
    });
  }
  return docClient;
}

function buildKeys(serviceName: string, timestamp: string, deploymentId: string) {
  return {
    pk: `SERVICE#${serviceName}`,
    sk: `DEPLOY#${timestamp}#${deploymentId}`,
  };
}

export async function createDeployment(event: DeploymentEvent): Promise<DeploymentRecord> {
  const config = getConfig();
  const client = getDocClient();
  const now = new Date().toISOString();
  const keys = buildKeys(event.serviceName, event.timestamp, event.deploymentId);

  const record: DeploymentRecord = {
    ...keys,
    deploymentId: event.deploymentId,
    serviceName: event.serviceName,
    environment: event.environment,
    status: event.status,
    commitSha: event.commitSha,
    ref: event.ref,
    triggeredBy: event.triggeredBy,
    description: event.description,
    startedAt: event.timestamp,
    createdAt: now,
    updatedAt: now,
    metadata: event.metadata,
  };

  await client.send(
    new PutCommand({
      TableName: config.DYNAMODB_TABLE,
      Item: record,
    })
  );

  return record;
}

export async function updateDeploymentStatus(
  serviceName: string,
  timestamp: string,
  deploymentId: string,
  status: string,
  completedAt?: string
): Promise<void> {
  const config = getConfig();
  const client = getDocClient();
  const keys = buildKeys(serviceName, timestamp, deploymentId);

  await client.send(
    new UpdateCommand({
      TableName: config.DYNAMODB_TABLE,
      Key: keys,
      UpdateExpression: 'SET #status = :status, updatedAt = :now' +
        (completedAt ? ', completedAt = :completedAt' : ''),
      ExpressionAttributeNames: { '#status': 'status' },
      ExpressionAttributeValues: {
        ':status': status,
        ':now': new Date().toISOString(),
        ...(completedAt && { ':completedAt': completedAt }),
      },
    })
  );
}

export async function getDeploymentById(deploymentId: string): Promise<DeploymentRecord | null> {
  const config = getConfig();
  const client = getDocClient();

  const result = await client.send(
    new QueryCommand({
      TableName: config.DYNAMODB_TABLE,
      IndexName: 'gsi1-deployment-id',
      KeyConditionExpression: 'deploymentId = :id',
      ExpressionAttributeValues: { ':id': deploymentId },
      Limit: 1,
    })
  );

  return (result.Items?.[0] as DeploymentRecord) ?? null;
}

export async function queryDeployments(
  params: DeploymentQueryParams
): Promise<{ items: DeploymentRecord[]; cursor?: string }> {
  const config = getConfig();
  const client = getDocClient();
  const limit = params.limit ?? 20;

  if (params.service) {
    const result = await client.send(
      new QueryCommand({
        TableName: config.DYNAMODB_TABLE,
        KeyConditionExpression: 'pk = :pk AND begins_with(sk, :prefix)',
        ExpressionAttributeValues: {
          ':pk': `SERVICE#${params.service}`,
          ':prefix': 'DEPLOY#',
        },
        ScanIndexForward: false,
        Limit: limit,
        ...(params.cursor && {
          ExclusiveStartKey: JSON.parse(Buffer.from(params.cursor, 'base64').toString()),
        }),
      })
    );

    let items = (result.Items ?? []) as DeploymentRecord[];
    if (params.environment) {
      items = items.filter((i) => i.environment === params.environment);
    }
    if (params.status) {
      items = items.filter((i) => i.status === params.status);
    }

    const cursor = result.LastEvaluatedKey
      ? Buffer.from(JSON.stringify(result.LastEvaluatedKey)).toString('base64')
      : undefined;

    return { items, cursor };
  }

  // Without a service filter, scan (acceptable at low scale)
  const result = await client.send(
    new QueryCommand({
      TableName: config.DYNAMODB_TABLE,
      IndexName: 'gsi1-deployment-id',
      KeyConditionExpression: 'begins_with(deploymentId, :prefix)',
      ExpressionAttributeValues: { ':prefix': '' },
      ScanIndexForward: false,
      Limit: limit,
    }).catch(() => null) // Falls back to scan for listing
  );

  // Fallback: simple scan for "list all" queries
  const { ScanCommand } = require('@aws-sdk/lib-dynamodb');
  const scanResult = await client.send(
    new ScanCommand({
      TableName: config.DYNAMODB_TABLE,
      Limit: limit,
      ...(params.cursor && {
        ExclusiveStartKey: JSON.parse(Buffer.from(params.cursor, 'base64').toString()),
      }),
    })
  );

  let items = (scanResult.Items ?? []) as DeploymentRecord[];
  if (params.environment) {
    items = items.filter((i) => i.environment === params.environment);
  }
  if (params.status) {
    items = items.filter((i) => i.status === params.status);
  }

  const cursor = scanResult.LastEvaluatedKey
    ? Buffer.from(JSON.stringify(scanResult.LastEvaluatedKey)).toString('base64')
    : undefined;

  return { items, cursor };
}
