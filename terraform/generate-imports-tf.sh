#!/usr/bin/env bash
set -euo pipefail

# Generate imports.auto.tf with "import" blocks for resources that already exist in AWS
# This lets Terraform adopt existing infra automatically at plan/apply time (Terraform >= 1.5)
# Usage: ./generate-imports-tf.sh [env]
#   env: dev|prod (default inferred from GITHUB_REF, else dev)
# Requires: AWS CLI v2 with permissions to Describe/List resources in us-east-1

ENV_IN=${1:-}
if [[ -z "${ENV_IN}" ]]; then
  if [[ "${GITHUB_REF:-}" == "refs/heads/main" ]]; then
    ENV="prod"
  else
    ENV="dev"
  fi
else
  ENV="${ENV_IN}"
fi

AWS_REGION="${AWS_REGION:-us-east-1}"
TFVARS="environments/${ENV}/terraform.tfvars"
OUT="imports.auto.tf"

# naive parser for project_name from tfvars
PROJECT_NAME=$(sed -n "s/^\s*project_name\s*=\s*\"\(.*\)\".*/\1/p" "$TFVARS" | head -1)
if [[ -z "$PROJECT_NAME" ]]; then
  PROJECT_NAME="fullstack-docker"
fi

echo "# Auto-generated import blocks - $(date -Iseconds)" > "$OUT"

echo "Detecting existing resources for project=$PROJECT_NAME env=$ENV in $AWS_REGION"

# helper to append an import block if ID not empty
STATE_LIST=$(terraform state list -no-color 2>/dev/null || true)

add_import() {
  local addr="$1"; shift
  local id="$1"; shift
  if [[ -n "$id" && "$id" != "null" ]]; then
    if echo "$STATE_LIST" | grep -Fqx "$addr"; then
      echo "  [=] skip ${addr} (already in state)"
      return
    fi
    cat >> "$OUT" <<EOF
import {
  to = ${addr}
  id = "${id}"
}

EOF
    echo "  [+] import ${addr} <- ${id}"
  fi
}

# CloudWatch Log Groups
for svc in backend frontend; do
  LG="/ecs/${PROJECT_NAME}-${ENV}-${svc}"
  if aws logs describe-log-groups --log-group-name-prefix "$LG" --region "$AWS_REGION" --query 'logGroups[?logGroupName==`'"$LG"'`].logGroupName' --output text | grep -q "$LG"; then
    add_import "module.cloudwatch.aws_cloudwatch_log_group.${svc}" "$LG"
  fi
done

# ECR repositories (addressable by name)
for svc in backend frontend; do
  REPO_NAME="${PROJECT_NAME}-${svc}"
  if aws ecr describe-repositories --region "$AWS_REGION" --repository-names "$REPO_NAME" >/dev/null 2>&1; then
    add_import "module.ecr.aws_ecr_repository.${svc}" "$REPO_NAME"
  fi
done

# Resolve our Terraform-managed VPC once for VPC-scoped imports
VPC_NAME_TAG="${PROJECT_NAME}-${ENV}-vpc"
VPC_ID_TF=$(aws ec2 describe-vpcs \
  --region "$AWS_REGION" \
  --filters "Name=tag:Name,Values=${VPC_NAME_TAG}" \
  --query 'Vpcs[0].VpcId' \
  --output text 2>/dev/null || true)

# VPC dependent groups (only import if in our VPC)
DB_SUBNET_GRP="${PROJECT_NAME}-${ENV}-db-subnet-group"
if aws rds describe-db-subnet-groups --db-subnet-group-name "$DB_SUBNET_GRP" --region "$AWS_REGION" >/dev/null 2>&1; then
  DB_FIRST_SUBNET=$(aws rds describe-db-subnet-groups \
    --db-subnet-group-name "$DB_SUBNET_GRP" \
    --region "$AWS_REGION" \
    --query 'DBSubnetGroups[0].Subnets[0].SubnetIdentifier' \
    --output text 2>/dev/null || true)
  DB_VPC_ID=""
  if [[ -n "$DB_FIRST_SUBNET" && "$DB_FIRST_SUBNET" != "None" ]]; then
    DB_VPC_ID=$(aws ec2 describe-subnets \
      --subnet-ids "$DB_FIRST_SUBNET" \
      --region "$AWS_REGION" \
      --query 'Subnets[0].VpcId' \
      --output text 2>/dev/null || true)
  fi
  if [[ -n "$VPC_ID_TF" && -n "$DB_VPC_ID" && "$VPC_ID_TF" == "$DB_VPC_ID" ]]; then
    add_import "module.vpc.aws_db_subnet_group.main" "$DB_SUBNET_GRP"
  else
    echo "  [=] skip DB subnet group import (VPC mismatch: tf=$VPC_ID_TF dbsg=$DB_VPC_ID)"
  fi
fi

CACHE_SUBNET_GRP="${PROJECT_NAME}-${ENV}-cache-subnet-group"
if aws elasticache describe-cache-subnet-groups --cache-subnet-group-name "$CACHE_SUBNET_GRP" --region "$AWS_REGION" >/dev/null 2>&1; then
  CACHE_FIRST_SUBNET=$(aws elasticache describe-cache-subnet-groups \
    --cache-subnet-group-name "$CACHE_SUBNET_GRP" \
    --region "$AWS_REGION" \
    --query 'CacheSubnetGroups[0].Subnets[0].SubnetIdentifier' \
    --output text 2>/dev/null || true)
  CACHE_VPC_ID=""
  if [[ -n "$CACHE_FIRST_SUBNET" && "$CACHE_FIRST_SUBNET" != "None" ]]; then
    CACHE_VPC_ID=$(aws ec2 describe-subnets \
      --subnet-ids "$CACHE_FIRST_SUBNET" \
      --region "$AWS_REGION" \
      --query 'Subnets[0].VpcId' \
      --output text 2>/dev/null || true)
  fi
  if [[ -n "$VPC_ID_TF" && -n "$CACHE_VPC_ID" && "$VPC_ID_TF" == "$CACHE_VPC_ID" ]]; then
    add_import "module.vpc.aws_elasticache_subnet_group.main" "$CACHE_SUBNET_GRP"
  else
    echo "  [=] skip Cache subnet group import (VPC mismatch: tf=$VPC_ID_TF cache=$CACHE_VPC_ID)"
  fi
fi

# Redis param/logs
REDIS_PG="${PROJECT_NAME}-${ENV}-redis-params"
if aws elasticache describe-cache-parameter-groups --region "$AWS_REGION" --cache-parameter-group-name "$REDIS_PG" >/dev/null 2>&1; then
  add_import "module.redis.aws_elasticache_parameter_group.redis" "$REDIS_PG"
fi
REDIS_LOG="/aws/elasticache/${PROJECT_NAME}-${ENV}-redis"
if aws logs describe-log-groups --log-group-name-prefix "$REDIS_LOG" --region "$AWS_REGION" --query 'logGroups[?logGroupName==`'"$REDIS_LOG"'`].logGroupName' --output text | grep -q "$REDIS_LOG"; then
  add_import "module.redis.aws_cloudwatch_log_group.redis" "$REDIS_LOG"
fi

# ECS cluster by name
ECS_CLUSTER_NAME="${PROJECT_NAME}-${ENV}"
if aws ecs describe-clusters \
      --clusters "$ECS_CLUSTER_NAME" \
      --region "$AWS_REGION" \
      --query 'clusters[?status==`ACTIVE`].clusterName' \
      --output text \
    | grep -qx "$ECS_CLUSTER_NAME"; then
  add_import "module.ecs.aws_ecs_cluster.main" "$ECS_CLUSTER_NAME"
fi

# ALB by tag Name
ALB_NAME_TAG="${PROJECT_NAME}-${ENV}-alb"
ALB_ARN=$(aws elbv2 describe-load-balancers --region "$AWS_REGION" --query 'LoadBalancers[*].LoadBalancerArn' --output text | tr '\t' '\n' | while read -r arn; do
  [[ -z "$arn" ]] && continue
  NAME=$(aws elbv2 describe-tags --resource-arns "$arn" --region "$AWS_REGION" --query 'TagDescriptions[0].Tags[?Key==`Name`].Value|[0]' --output text 2>/dev/null || true)
  if [[ "$NAME" == "$ALB_NAME_TAG" ]]; then echo "$arn"; break; fi
done)
if [[ -n "$ALB_ARN" ]]; then
  add_import "module.alb.aws_lb.main" "$ALB_ARN"
fi

# Target groups by tag Name
for item in frontend backend; do
  TG_NAME_TAG="${PROJECT_NAME}-${ENV}-${item}-tg"
  TG_ARN=$(aws elbv2 describe-target-groups --region "$AWS_REGION" --query 'TargetGroups[*].TargetGroupArn' --output text | tr '\t' '\n' | while read -r tarn; do
    [[ -z "$tarn" ]] && continue
    NAME=$(aws elbv2 describe-tags --resource-arns "$tarn" --region "$AWS_REGION" --query 'TagDescriptions[0].Tags[?Key==`Name`].Value|[0]' --output text 2>/dev/null || true)
    if [[ "$NAME" == "$TG_NAME_TAG" ]]; then echo "$tarn"; break; fi
  done)
  if [[ -n "$TG_ARN" ]]; then
    add_import "module.alb.aws_lb_target_group.${item}" "$TG_ARN"
  fi
done

# RDS instance by identifier (only if in our VPC)
RDS_ID="${PROJECT_NAME}-${ENV}-postgres"
if aws rds describe-db-instances --db-instance-identifier "$RDS_ID" --region "$AWS_REGION" >/dev/null 2>&1; then
  VPC_ID_TF=$(aws ec2 describe-vpcs \
    --region "$AWS_REGION" \
    --filters "Name=tag:Name,Values=${PROJECT_NAME}-${ENV}-vpc" \
    --query 'Vpcs[0].VpcId' \
    --output text 2>/dev/null || true)

  DB_SUBNET_GRP=$(aws rds describe-db-instances \
    --db-instance-identifier "$RDS_ID" \
    --region "$AWS_REGION" \
    --query 'DBInstances[0].DBSubnetGroup.DBSubnetGroupName' \
    --output text 2>/dev/null || true)
  RDS_VPC_ID=""
  if [[ -n "$DB_SUBNET_GRP" && "$DB_SUBNET_GRP" != "None" ]]; then
    FIRST_SUBNET=$(aws rds describe-db-subnet-groups \
      --db-subnet-group-name "$DB_SUBNET_GRP" \
      --region "$AWS_REGION" \
      --query 'DBSubnetGroups[0].Subnets[0].SubnetIdentifier' \
      --output text 2>/dev/null || true)
    if [[ -n "$FIRST_SUBNET" && "$FIRST_SUBNET" != "None" ]]; then
      RDS_VPC_ID=$(aws ec2 describe-subnets \
        --subnet-ids "$FIRST_SUBNET" \
        --region "$AWS_REGION" \
        --query 'Subnets[0].VpcId' \
        --output text 2>/dev/null || true)
    fi
  fi

  if [[ -n "$VPC_ID_TF" && -n "$RDS_VPC_ID" && "$VPC_ID_TF" == "$RDS_VPC_ID" ]]; then
    add_import "module.rds.aws_db_instance.postgres" "$RDS_ID"
  else
    echo "  [!] skip module.rds.aws_db_instance.postgres (VPC mismatch: tf=$VPC_ID_TF rds=$RDS_VPC_ID)"
  fi
fi

# Try to import NAT + EIP only if we can confidently resolve NAT in our VPC/subnet
# VPC_ID_TF already resolved above

SUBNET1_NAME_TAG="${PROJECT_NAME}-${ENV}-public-subnet-1"
SUBNET1_ID=$(aws ec2 describe-subnets \
  --region "$AWS_REGION" \
  --filters "Name=tag:Name,Values=${SUBNET1_NAME_TAG}" \
  --query 'Subnets[0].SubnetId' \
  --output text 2>/dev/null || true)

if [[ -n "$VPC_ID_TF" && "$VPC_ID_TF" != "None" && -n "$SUBNET1_ID" && "$SUBNET1_ID" != "None" ]]; then
  NAT_ID=$(aws ec2 describe-nat-gateways \
    --region "$AWS_REGION" \
    --filter "Name=vpc-id,Values=${VPC_ID_TF}" "Name=subnet-id,Values=${SUBNET1_ID}" \
    --query 'NatGateways[?State==`available`][0].NatGatewayId' \
    --output text 2>/dev/null || true)
  if [[ -n "$NAT_ID" && "$NAT_ID" != "None" ]]; then
    add_import "module.vpc.aws_nat_gateway.main[0]" "$NAT_ID"
    # If NAT exists, also import its associated EIP allocation
    EIP_ALLOC_ID=$(aws ec2 describe-nat-gateways \
      --region "$AWS_REGION" \
      --nat-gateway-ids "$NAT_ID" \
      --query 'NatGateways[0].NatGatewayAddresses[0].AllocationId' \
      --output text 2>/dev/null || true)
    if [[ -n "$EIP_ALLOC_ID" && "$EIP_ALLOC_ID" != "None" ]]; then
      add_import "module.vpc.aws_eip.nat[0]" "$EIP_ALLOC_ID"
    fi
  else
    echo "  [=] skip NAT import (no NAT in VPC ${VPC_ID_TF} subnet ${SUBNET1_ID})"
  fi
else
  echo "  [=] skip NAT import (unable to resolve VPC/subnet by tags)"
fi

# ElastiCache cluster (if exists and matches our naming)
REDIS_CLUSTER_ID="${PROJECT_NAME}-${ENV}-redis"
if aws elasticache describe-cache-clusters --cache-cluster-id "$REDIS_CLUSTER_ID" --region "$AWS_REGION" >/dev/null 2>&1; then
  add_import "module.redis.aws_elasticache_cluster.redis" "$REDIS_CLUSTER_ID"
fi

# Write a newline at end (terraform tolerant either way)
: > /dev/null

echo "Wrote import blocks to $OUT"
