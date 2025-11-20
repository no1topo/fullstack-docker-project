#!/usr/bin/env bash
set -euo pipefail

# Import existing AWS resources into Terraform state to prevent "already exists" errors
# Runs idempotently: skips resources already in state, imports missing ones
# Usage: ./import-existing-resources.sh
# Environment: AWS credentials must be configured (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION)

TF_DIR="${1:-.}"
cd "$TF_DIR"

echo "=========================================="
echo "Importing existing AWS resources..."
echo "=========================================="

echo "Initializing Terraform..."
terraform init -input=false -no-color

# Map Terraform resource address => existing AWS resource id/arn
declare -A IMPORTS=(
  ["module.cloudwatch.aws_cloudwatch_log_group.backend"]="/ecs/fullstack-docker-prod-backend"
  ["module.cloudwatch.aws_cloudwatch_log_group.frontend"]="/ecs/fullstack-docker-prod-frontend"
  ["module.ecr.aws_ecr_repository.backend"]="fullstack-docker-backend"
  ["module.ecr.aws_ecr_repository.frontend"]="fullstack-docker-frontend"
  ["module.redis.aws_elasticache_parameter_group.redis"]="fullstack-docker-prod-redis-params"
  ["module.redis.aws_cloudwatch_log_group.redis"]="/aws/elasticache/fullstack-docker-prod-redis"
  ["module.vpc.aws_db_subnet_group.main"]="fullstack-docker-prod-db-subnet-group"
  ["module.vpc.aws_elasticache_subnet_group.main"]="fullstack-docker-prod-cache-subnet-group"
)

IMPORT_COUNT=0
SKIP_COUNT=0

echo ""
echo "Checking and importing resources..."
for ADDR in "${!IMPORTS[@]}"; do
  if terraform state list -no-color 2>/dev/null | grep -Fqx "$ADDR"; then
    echo "  [SKIP] $ADDR (already in state)"
    ((SKIP_COUNT++))
    continue
  fi

  ID="${IMPORTS[$ADDR]}"
  echo "  [IMPORT] $ADDR <- $ID"
  
  if terraform import -no-color "$ADDR" "$ID" 2>&1; then
    echo "    ✓ Successfully imported"
    ((IMPORT_COUNT++))
  else
    echo "    ✗ Warning: import failed for $ADDR (resource may not exist or address mismatch)"
  fi
done

echo ""
echo "=========================================="
echo "Import summary: $IMPORT_COUNT imported, $SKIP_COUNT skipped"
echo "=========================================="
echo "Ready for terraform plan"
