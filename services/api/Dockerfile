# Build stage
FROM node:20-slim AS builder

WORKDIR /app

# Copy shared package first (dependency)
COPY services/shared/package.json services/shared/
COPY services/shared/tsconfig.json services/shared/
COPY services/shared/src/ services/shared/src/

# Copy API package
COPY services/api/package.json services/api/
COPY services/api/tsconfig.json services/api/

# Install dependencies
WORKDIR /app/services/shared
RUN npm install && npm run build

WORKDIR /app/services/api
RUN npm install && npm run build

# Production stage
FROM node:20-slim

RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy built shared package
COPY --from=builder /app/services/shared/dist/ services/shared/dist/
COPY --from=builder /app/services/shared/package.json services/shared/
COPY --from=builder /app/services/shared/node_modules/ services/shared/node_modules/

# Copy built API
COPY --from=builder /app/services/api/dist/ services/api/dist/
COPY --from=builder /app/services/api/package.json services/api/
COPY --from=builder /app/services/api/node_modules/ services/api/node_modules/

WORKDIR /app/services/api

ENV NODE_ENV=production
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:3000/health || exit 1

USER node
CMD ["node", "dist/index.js"]
