# GitHub Actions & AWS Setup Guide

This guide walks you through configuring GitHub Actions to automatically deploy your infrastructure to AWS.

## Prerequisites

- AWS Account with appropriate permissions
- GitHub repository admin access
- Terraform state bucket (S3) - can be created manually or via script

## Step 1: Create AWS Terraform State Bucket

```bash
# Set variables
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="fullstack-docker-terraform-state-${AWS_ACCOUNT_ID}"
REGION="us-east-1"

# Create S3 bucket with versioning
aws s3 mb s3://${BUCKET_NAME} --region ${REGION}
aws s3api put-bucket-versioning \
  --bucket ${BUCKET_NAME} \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket ${BUCKET_NAME} \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block public access
aws s3api put-public-access-block \
  --bucket ${BUCKET_NAME} \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ${REGION}

echo "✓ Terraform state infrastructure created:"
echo "  S3 Bucket: ${BUCKET_NAME}"
echo "  DynamoDB Table: terraform-locks"
```

## Step 2: Create GitHub OIDC Identity Provider in AWS

This allows GitHub Actions to assume an IAM role without storing long-lived AWS credentials.

```bash
# Set variables
GITHUB_ORG="your-github-org"        # e.g., "no1topo"
GITHUB_REPO="fullstack-docker-project"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# 1. Create OIDC Provider
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

# 2. Create IAM Role for GitHub Actions
ROLE_NAME="github-actions-role"

cat > /tmp/trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${AWS_ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:${GITHUB_ORG}/${GITHUB_REPO}:*"
          ]
        }
      }
    }
  ]
}
EOF

aws iam create-role \
  --role-name ${ROLE_NAME} \
  --assume-role-policy-document file:///tmp/trust-policy.json

# 3. Attach Permissions Policy
cat > /tmp/permissions-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ECSAccess",
      "Effect": "Allow",
      "Action": [
        "ecs:*",
        "ec2:*",
        "ecr:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "RDSAccess",
      "Effect": "Allow",
      "Action": [
        "rds:*",
        "rds-db:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ElastiCacheAccess",
      "Effect": "Allow",
      "Action": [
        "elasticache:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ALBAccess",
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "VPCAccess",
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "ec2:CreateSecurityGroup",
        "ec2:DeleteSecurityGroup",
        "ec2:AuthorizeSecurityGroup*",
        "ec2:RevokeSecurityGroup*",
        "ec2:CreateVpc",
        "ec2:DeleteVpc",
        "ec2:CreateSubnet",
        "ec2:DeleteSubnet",
        "ec2:CreateRouteTable",
        "ec2:DeleteRouteTable",
        "ec2:CreateRoute",
        "ec2:DeleteRoute",
        "ec2:CreateInternetGateway",
        "ec2:DeleteInternetGateway",
        "ec2:AttachInternetGateway",
        "ec2:DetachInternetGateway",
        "ec2:AllocateAddress",
        "ec2:ReleaseAddress",
        "ec2:CreateNatGateway",
        "ec2:DeleteNatGateway"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IAMAccess",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:GetRole",
        "iam:PutRolePolicy",
        "iam:DeleteRolePolicy",
        "iam:CreatePolicy",
        "iam:DeletePolicy",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:ListAttachedRolePolicies"
      ],
      "Resource": "*"
    },
    {
      "Sid": "CloudWatchAccess",
      "Effect": "Allow",
      "Action": [
        "logs:*",
        "cloudwatch:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "SecretsManagerAccess",
      "Effect": "Allow",
      "Action": [
        "secretsmanager:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "AppAutoScalingAccess",
      "Effect": "Allow",
      "Action": [
        "application-autoscaling:*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "TerraformStateAccess",
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::fullstack-docker-terraform-state-*",
        "arn:aws:s3:::fullstack-docker-terraform-state-*/*"
      ]
    },
    {
      "Sid": "DynamoDBAccess",
      "Effect": "Allow",
      "Action": [
        "dynamodb:DescribeTable",
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/terraform-locks"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name ${ROLE_NAME} \
  --policy-name github-actions-policy \
  --policy-document file:///tmp/permissions-policy.json

echo "✓ IAM role created: arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}"
```

## Step 3: Configure GitHub Secrets

Go to your GitHub repository **Settings → Secrets and variables → Actions** and add:

```
AWS_ROLE_ARN = arn:aws:iam::YOUR_ACCOUNT_ID:role/github-actions-role
AWS_REGION = us-east-1
TF_STATE_BUCKET = fullstack-docker-terraform-state-YOUR_ACCOUNT_ID
```

**To find these values**:
```bash
# AWS_ROLE_ARN
aws iam get-role --role-name github-actions-role --query 'Role.Arn' --output text

# AWS_ACCOUNT_ID (for TF_STATE_BUCKET)
aws sts get-caller-identity --query Account --output text

# TF_STATE_BUCKET
aws s3 ls | grep terraform-state
```

## Step 4: Update Backend Configuration

Add S3 backend configuration to Terraform (optional but recommended for team environments):

Update `terraform/main.tf`:
```hcl
terraform {
  # ... existing config ...

  backend "s3" {
    # These will be overridden by -backend-config flags in GitHub Actions
    bucket         = "fullstack-docker-terraform-state-123456789"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}
```

## Step 5: Test the Pipeline

1. **Create a test branch**:
   ```bash
   git checkout -b test/pipeline
   ```

2. **Make a trivial change** (e.g., update a comment):
   ```bash
   echo "# Test pipeline" >> README.md
   git add README.md
   git commit -m "test: trigger CI pipeline"
   git push origin test/pipeline
   ```

3. **Create a PR** and watch GitHub Actions run the CI workflow
4. **Check logs** in the Actions tab for any failures
5. **Merge to develop** and watch the CD workflow deploy to staging

## Step 6: Configure Continuous Deployment

### Option A: Automatic Deployment (Recommended)

The default workflow automatically deploys on push to `main` (prod) or `develop` (staging).

### Option B: Manual Approval

Add this to `.github/workflows/cd.yml` for manual approval before production deployment:

```yaml
deploy:
  needs: build-and-push
  environment:
    name: production
    approval_timeout: 3600  # 1 hour to approve
  runs-on: ubuntu-latest
  # ... rest of job ...
```

Then require approval in **Settings → Environments → Production → Add deployment protection rules**.

## Troubleshooting

### GitHub Action Fails: "OIDC Provider Not Found"

```bash
# Verify OIDC provider exists
aws iam list-open-id-connect-providers

# Recreate if missing
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

### "Access Denied" in Terraform Apply

```bash
# Verify IAM role has correct policies
aws iam list-role-policies --role-name github-actions-role

# Add missing permissions
aws iam put-role-policy --role-name github-actions-role --policy-name missing-service --policy-document file://policy.json
```

### Terraform State Lock Stuck

```bash
# Force unlock (use with caution!)
terraform force-unlock <lock-id>

# Or from AWS CLI
aws dynamodb delete-item \
  --table-name terraform-locks \
  --key '{"LockID":{"S":"fullstack-docker-terraform-state/<env>/terraform.tfstate"}}'
```

### ECR Login Fails in GitHub Actions

The ECR repositories are automatically created by Terraform when you run `terraform apply`. If you encounter login issues:

```bash
# Verify ECR repositories exist
aws ecr describe-repositories --repository-names fullstack-docker-backend fullstack-docker-frontend

# If missing, apply Terraform first to create them
cd terraform/environments/dev
terraform apply

# Repositories created by Terraform:
# - fullstack-docker-backend (with lifecycle policy, scan on push)
# - fullstack-docker-frontend (with lifecycle policy, scan on push)
```

## Container Registry (ECR)

**Important**: This project uses **AWS Elastic Container Registry (ECR)** for Docker images. The Terraform ECR module automatically creates:
- `fullstack-docker-backend` repository
- `fullstack-docker-frontend` repository

Both repositories have:
- Image scanning on push enabled
- Lifecycle policies (keeps last 10 images, removes older ones)
- Automatic cleanup of untagged images

Images are pushed during the CD workflow with git SHA tags (e.g., `abc123def456`), and ECS task definitions reference these ECR URIs.

## Monitoring & Alerts

### CloudWatch Alarms for Deployments

```bash
# Create SNS topic for notifications
aws sns create-topic --name github-actions-alerts

# Create CloudWatch alarm for ALB unhealthy targets
aws cloudwatch put-metric-alarm \
  --alarm-name fullstack-docker-unhealthy-targets \
  --alarm-description "Alert when ALB has unhealthy targets" \
  --metric-name UnHealthyHostCount \
  --namespace AWS/ApplicationELB \
  --statistic Average \
  --period 300 \
  --threshold 1 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --alarm-actions arn:aws:sns:us-east-1:123456789:github-actions-alerts
```

### Review Deployments

```bash
# List recent GitHub Actions runs
gh run list --repo YOUR_ORG/fullstack-docker-project --limit 10

# View specific run logs
gh run view <run-id> --repo YOUR_ORG/fullstack-docker-project --log
```

## Next Steps

- [ ] Set up Slack notifications on deployment failures
- [ ] Configure manual approval for production deployments
- [ ] Set up AWS Budgets alerts for cost monitoring
- [ ] Add scheduled backups of RDS/Redis
- [ ] Implement cross-region disaster recovery
- [ ] Set up automated security scanning with Snyk

---

**See also**: `TERRAFORM_GUIDE.md` and `DEVOPS_README.md` for detailed infrastructure documentation.
