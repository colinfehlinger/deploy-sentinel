#!/bin/bash
set -euo pipefail

echo "=== Deploy Sentinel Bootstrap ==="
echo ""
echo "This script creates the Terraform backend resources and OIDC provider."
echo "Run this ONCE before any other Terraform operations."
echo ""

# Check for required tools
command -v terraform >/dev/null 2>&1 || { echo "Error: terraform is required but not installed."; exit 1; }
command -v aws >/dev/null 2>&1 || { echo "Error: aws CLI is required but not installed."; exit 1; }

# Get AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account: $ACCOUNT_ID"

# Prompt for GitHub org/username
read -p "GitHub org or username: " GITHUB_ORG
read -p "GitHub repo name [deploy-sentinel]: " GITHUB_REPO
GITHUB_REPO=${GITHUB_REPO:-deploy-sentinel}

cd infra/bootstrap

echo ""
echo "Initializing Terraform..."
terraform init

echo ""
echo "Planning..."
terraform plan \
  -var="github_org=$GITHUB_ORG" \
  -var="github_repo=$GITHUB_REPO"

echo ""
read -p "Apply? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "Aborted."
  exit 0
fi

terraform apply \
  -var="github_org=$GITHUB_ORG" \
  -var="github_repo=$GITHUB_REPO" \
  -auto-approve

echo ""
echo "=== Bootstrap Complete ==="
echo ""
echo "Next steps:"
echo "1. Update infra/environments/dev/backend.tf with:"
echo "   bucket = \"deploy-sentinel-tf-state-$ACCOUNT_ID\""
echo ""
echo "2. Update infra/environments/prod/backend.tf with:"
echo "   bucket = \"deploy-sentinel-tf-state-$ACCOUNT_ID\""
echo ""
echo "3. Add the following GitHub repo secret:"
echo "   AWS_ROLE_ARN = $(terraform output -raw gha_role_arn)"
echo ""
