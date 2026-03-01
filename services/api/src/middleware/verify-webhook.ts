import crypto from 'crypto';
import { Request, Response, NextFunction } from 'express';
import { getConfig } from '@deploy-sentinel/shared';
import { logger } from '../logger';

export function verifyWebhookSignature(req: Request, res: Response, next: NextFunction): void {
  const signature = req.headers['x-hub-signature-256'] as string | undefined;
  if (!signature) {
    logger.warn({ path: req.path }, 'Missing webhook signature');
    res.status(401).json({ error: 'Missing signature' });
    return;
  }

  const config = getConfig();
  const payload = JSON.stringify(req.body);
  const expected =
    'sha256=' + crypto.createHmac('sha256', config.WEBHOOK_SECRET).update(payload).digest('hex');

  if (!crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected))) {
    logger.warn({ path: req.path }, 'Invalid webhook signature');
    res.status(401).json({ error: 'Invalid signature' });
    return;
  }

  next();
}
