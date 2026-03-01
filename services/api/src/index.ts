import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import pinoHttp from 'pino-http';
import { logger } from './logger';
import { healthRouter } from './routes/health';
import { webhookRouter } from './routes/webhooks';
import { deploymentsRouter } from './routes/deployments';
import { errorHandler } from './middleware/error-handler';
import { getConfig } from '@deploy-sentinel/shared';

const config = getConfig();
const app = express();

// Security middleware
app.use(helmet());
app.use(cors());

// Request logging
app.use(
  pinoHttp({
    logger,
    redact: ['req.headers.authorization', 'req.headers["x-hub-signature-256"]'],
  })
);

// Routes
app.use('/health', healthRouter);
app.use('/webhooks', webhookRouter);
app.use('/deployments', deploymentsRouter);

// Error handling
app.use(errorHandler);

app.listen(config.PORT, () => {
  logger.info({ port: config.PORT, env: config.NODE_ENV }, 'Deploy Sentinel API started');
});

export default app;
