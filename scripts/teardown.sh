#!/bin/bash
set -euo pipefail

ENV=${1:?Usage: teardown.sh <dev|prod>}
PROJECT="deploy-sentinel"
REGION="us-east-1"

echo "============================================"
echo "  WARNING: DESTROYING $ENV ENVIRONMENT"
echo "============================================"
echo ""
echo "This will permanently delete ALL resources in the $ENV environment."
echo ""
read -p "Type '$ENV' to confirm: " CONFIRM
if [ "$CONFIRM" != "$ENV" ]; then
  echo "Aborted."
  exit 1
fi

CLUSTER="$PROJECT-$ENV"

# Scale ECS services to 0 first (prevents race conditions)
echo ""
echo "--- Scaling down ECS services ---"
for SERVICE in api worker; do
  aws ecs update-service \
    --cluster $CLUSTER \
    --service $SERVICE \
    --desired-count 0 \
    --region $REGION \
    --no-cli-pager 2>/dev/null || echo "Service $SERVICE not found, skipping"
done

echo "Waiting for tasks to drain..."
sleep 15

# Terraform destroy
echo ""
echo "--- Running Terraform destroy ---"
cd infra/environments/$ENV
terraform init
terraform destroy -auto-approve

# Clean ECR images
echo ""
echo "--- Cleaning ECR repositories ---"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
for SERVICE in api worker; do
  REPO="$PROJECT-$SERVICE-$ENV"
  IMAGE_IDS=$(aws ecr list-images --repository-name $REPO --query 'imageIds' --output json --region $REGION 2>/dev/null || echo "[]")
  if [ "$IMAGE_IDS" != "[]" ] && [ -n "$IMAGE_IDS" ]; then
    aws ecr batch-delete-image \
      --repository-name $REPO \
      --image-ids "$IMAGE_IDS" \
      --region $REGION \
      --no-cli-pager 2>/dev/null || echo "Could not clean $REPO"
  fi
done

echo ""
echo "=== $ENV environment destroyed ==="
echo "Note: TF state bucket and lock table are preserved (managed by bootstrap)."
