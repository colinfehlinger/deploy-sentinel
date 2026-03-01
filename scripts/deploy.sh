#!/bin/bash
set -euo pipefail

ENV=${1:?Usage: deploy.sh <dev|prod>}
PROJECT="deploy-sentinel"
REGION="us-east-1"

echo "=== Deploying $PROJECT to $ENV ==="

# Get current git SHA for image tag
IMAGE_TAG=$(git rev-parse --short HEAD)
echo "Image tag: $IMAGE_TAG"

# Build and push images
echo ""
echo "--- Building and pushing Docker images ---"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_REGISTRY

for SERVICE in api worker; do
  echo "Building $SERVICE..."
  docker build -t "$ECR_REGISTRY/$PROJECT-$SERVICE-$ENV:$IMAGE_TAG" -f services/$SERVICE/Dockerfile .
  docker tag "$ECR_REGISTRY/$PROJECT-$SERVICE-$ENV:$IMAGE_TAG" "$ECR_REGISTRY/$PROJECT-$SERVICE-$ENV:latest"
  docker push "$ECR_REGISTRY/$PROJECT-$SERVICE-$ENV:$IMAGE_TAG"
  docker push "$ECR_REGISTRY/$PROJECT-$SERVICE-$ENV:latest"
done

# Apply Terraform
echo ""
echo "--- Applying Terraform ---"
cd infra/environments/$ENV
terraform init
terraform plan -var="image_tag=$IMAGE_TAG" -out=tfplan
terraform apply -auto-approve tfplan

# Update ECS services
echo ""
echo "--- Updating ECS services ---"
CLUSTER="$PROJECT-$ENV"
for SERVICE in api worker; do
  aws ecs update-service \
    --cluster $CLUSTER \
    --service $SERVICE \
    --force-new-deployment \
    --region $REGION \
    --no-cli-pager
done

echo ""
echo "--- Waiting for services to stabilize ---"
aws ecs wait services-stable \
  --cluster $CLUSTER \
  --services api worker \
  --region $REGION

echo ""
echo "=== Deployment complete ==="
ALB_DNS=$(terraform output -raw alb_dns_name)
echo "API: https://$ALB_DNS"
echo "Health: https://$ALB_DNS/health"
