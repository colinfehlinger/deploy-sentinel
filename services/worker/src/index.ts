import { getConfig } from '@deploy-sentinel/shared';
import { logger } from './logger';
import { startPolling } from './poller';

const config = getConfig();

logger.info(
  { env: config.NODE_ENV, queueUrl: config.SQS_QUEUE_URL },
  'Deploy Sentinel Worker starting'
);

// Graceful shutdown
let shutdownRequested = false;

process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  shutdownRequested = true;
});

process.on('SIGINT', () => {
  logger.info('SIGINT received, shutting down gracefully');
  shutdownRequested = true;
});

startPolling(() => shutdownRequested);
