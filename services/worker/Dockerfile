# Build stage
FROM node:20-slim AS builder

WORKDIR /app

# Copy shared package first (dependency)
COPY services/shared/package.json services/shared/
COPY services/shared/tsconfig.json services/shared/
COPY services/shared/src/ services/shared/src/

# Copy worker package
COPY services/worker/package.json services/worker/
COPY services/worker/tsconfig.json services/worker/

# Install dependencies
WORKDIR /app/services/shared
RUN npm install && npm run build

WORKDIR /app/services/worker
RUN npm install && npm run build

# Production stage
FROM node:20-slim

WORKDIR /app

# Copy built shared package
COPY --from=builder /app/services/shared/dist/ services/shared/dist/
COPY --from=builder /app/services/shared/package.json services/shared/
COPY --from=builder /app/services/shared/node_modules/ services/shared/node_modules/

# Copy built worker
COPY --from=builder /app/services/worker/dist/ services/worker/dist/
COPY --from=builder /app/services/worker/package.json services/worker/
COPY --from=builder /app/services/worker/node_modules/ services/worker/node_modules/

WORKDIR /app/services/worker

ENV NODE_ENV=production

USER node
CMD ["node", "dist/index.js"]
