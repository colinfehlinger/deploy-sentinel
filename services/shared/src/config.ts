import { z } from 'zod';

const configSchema = z.object({
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  PORT: z.coerce.number().default(3000),
  AWS_REGION: z.string().default('us-east-1'),
  DYNAMODB_TABLE: z.string().min(1),
  SQS_QUEUE_URL: z.string().min(1),
  WEBHOOK_SECRET: z.string().min(16),

  // Local dev overrides — optional, only used when NODE_ENV=development
  DYNAMODB_ENDPOINT: z.string().url().optional(),
  SQS_ENDPOINT: z.string().url().optional(),
});

export type Config = z.infer<typeof configSchema>;

let _config: Config | undefined;

export function getConfig(): Config {
  if (!_config) {
    const result = configSchema.safeParse(process.env);
    if (!result.success) {
      console.error('Invalid configuration:', result.error.flatten().fieldErrors);
      process.exit(1);
    }
    _config = result.data;
  }
  return _config;
}
