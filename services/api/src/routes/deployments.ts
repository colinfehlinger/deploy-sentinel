import { Router, Request, Response } from 'express';
import { getDeploymentById, queryDeployments, type DeploymentStatus } from '@deploy-sentinel/shared';
import { logger } from '../logger';

export const deploymentsRouter = Router();

deploymentsRouter.get('/', async (req: Request, res: Response) => {
  try {
    const { service, environment, status, limit, cursor } = req.query;

    const result = await queryDeployments({
      service: service as string | undefined,
      environment: environment as string | undefined,
      status: status as DeploymentStatus | undefined,
      limit: limit ? parseInt(limit as string, 10) : 20,
      cursor: cursor as string | undefined,
    });

    res.json({
      deployments: result.items,
      cursor: result.cursor,
      count: result.items.length,
    });
  } catch (err) {
    logger.error({ err }, 'Failed to query deployments');
    res.status(500).json({ error: 'Failed to query deployments' });
  }
});

deploymentsRouter.get('/:id', async (req: Request, res: Response) => {
  try {
    const deployment = await getDeploymentById(req.params.id);

    if (!deployment) {
      res.status(404).json({ error: 'Deployment not found' });
      return;
    }

    res.json(deployment);
  } catch (err) {
    logger.error({ err, deploymentId: req.params.id }, 'Failed to get deployment');
    res.status(500).json({ error: 'Failed to get deployment' });
  }
});
