#!/bin/bash
set -euo pipefail

# Pushes placeholder images to ECR so ECS tasks can start on first deploy.
# Run this AFTER terraform apply creates the ECR repositories, but BEFORE
# ECS tries to pull images.

ENV=${1:?Usage: push-initial-images.sh <dev|prod>}
PROJECT="deploy-sentinel"
REGION="us-east-1"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

echo "Logging into ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REGISTRY

echo "Building and pushing images..."
for SERVICE in api worker; do
  REPO="$ECR_REGISTRY/$PROJECT-$SERVICE-$ENV"
  echo "  Building $SERVICE..."
  docker build -t "$REPO:latest" -f services/$SERVICE/Dockerfile .
  echo "  Pushing $SERVICE..."
  docker push "$REPO:latest"
done

echo ""
echo "Done. Images pushed to ECR. ECS tasks can now start."
