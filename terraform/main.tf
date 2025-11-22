# Main Terraform Configuration
terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment for remote state (use S3 + DynamoDB for production)
   backend "s3" {
     bucket         = "fullstack-docker-terraform-state-962495091047"
     # key            = "fullstack-docker/dev/terraform.tfstate"
     region         = "us-east-1"
     encrypt        = true
     dynamodb_table = "terraform-locks"
   }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.common_tags
  }
}

# ============================================================================
# VPC and Networking
module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  vpc_cidr             = var.vpc_cidr
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  single_nat_gateway   = true

  tags = var.common_tags
}

# ECR Repositories
module "ecr" {
  source = "./modules/ecr"

  project_name = var.project_name
  environment  = var.environment
  services     = ["backend", "frontend"]

  tags = var.common_tags
}

# RDS PostgreSQL
module "rds" {
  source = "./modules/rds"

  project_name           = var.project_name
  environment            = var.environment
  allocated_storage      = var.rds_allocated_storage
  instance_class         = var.rds_instance_class
  backup_retention_days  = var.rds_backup_retention
  vpc_security_group_ids = [module.security_groups.rds_sg_id]
  db_subnet_group_name   = module.vpc.db_subnet_group_name
  multi_az               = coalesce(var.rds_multi_az, var.environment != "dev")
  storage_type           = var.rds_storage_type

  tags = var.common_tags
}

# ElastiCache Redis
module "redis" {
  source = "./modules/redis"

  project_name           = var.project_name
  environment            = var.environment
  node_type              = var.redis_node_type
  vpc_security_group_ids = [module.security_groups.redis_sg_id]
  subnet_group_name      = module.vpc.cache_subnet_group_name

  tags = var.common_tags
}

# Security Groups
module "security_groups" {
  source = "./modules/security_groups"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id

  tags = var.common_tags
}

# Application Load Balancer
module "alb" {
  source = "./modules/alb"

  project_name           = var.project_name
  environment            = var.environment
  vpc_id                 = module.vpc.vpc_id
  public_subnet_ids      = module.vpc.public_subnet_ids
  alb_security_group_id  = module.security_groups.alb_sg_id

  tags = var.common_tags
}

# IAM Roles
module "iam" {
  source = "./modules/iam"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region
  tags = var.common_tags
}

# ECS Cluster
module "ecs" {
  source = "./modules/ecs"

  project_name               = var.project_name
  environment                = var.environment
  cluster_name               = "${var.project_name}-${var.environment}"
  cluster_insights_enabled  = true

  tags = var.common_tags
}

# ECS Backend Service
module "ecs_backend" {
  source = "./modules/ecs_service"

  project_name              = var.project_name
  environment               = var.environment
  service_name              = "backend"
  cluster_id                = module.ecs.cluster_id
  cluster_name              = module.ecs.cluster_name
  task_family               = "${var.project_name}-backend"
  ecr_image_uri             = coalesce(var.backend_image_uri, "${module.ecr.backend_image_uri}:latest")
  container_port            = var.container_port_backend
  task_cpu                  = var.backend_cpu
  task_memory               = var.backend_memory
  desired_count             = var.backend_desired_count
  execution_role_arn        = module.iam.ecs_task_execution_role_arn
  task_role_arn             = module.iam.ecs_backend_task_role_arn
  target_group_arn          = module.alb.backend_target_group_arn
  vpc_id                    = module.vpc.vpc_id
  private_subnet_ids        = module.vpc.private_subnet_ids
  security_group_ids        = [module.security_groups.ecs_sg_id]
  rds_endpoint              = module.rds.endpoint
  rds_database              = module.rds.database_name
  rds_secret_arn            = module.rds.secret_arn
  redis_endpoint            = module.redis.primary_endpoint_address
  cloudwatch_log_group      = module.cloudwatch.backend_log_group

  tags = var.common_tags

  depends_on = [
    module.rds,
    module.redis,
    module.alb
  ]
}

# ECS Frontend Service
module "ecs_frontend" {
  source = "./modules/ecs_service"

  project_name              = var.project_name
  environment               = var.environment
  service_name              = "frontend"
  cluster_id                = module.ecs.cluster_id
  cluster_name              = module.ecs.cluster_name
  task_family               = "${var.project_name}-frontend"
  ecr_image_uri             = coalesce(var.frontend_image_uri, "${module.ecr.frontend_image_uri}:latest")
  container_port            = var.container_port_frontend
  task_cpu                  = var.frontend_cpu
  task_memory               = var.frontend_memory
  desired_count             = var.frontend_desired_count
  execution_role_arn        = module.iam.ecs_task_execution_role_arn
  task_role_arn             = module.iam.ecs_frontend_task_role_arn
  target_group_arn          = module.alb.frontend_target_group_arn
  vpc_id                    = module.vpc.vpc_id
  private_subnet_ids        = module.vpc.private_subnet_ids
  security_group_ids        = [module.security_groups.ecs_sg_id]
  cloudwatch_log_group      = module.cloudwatch.frontend_log_group

  tags = var.common_tags

  depends_on = [module.alb]
}

# Auto Scaling for Backend
module "autoscaling" {
  source = "./modules/autoscaling"

  project_name            = var.project_name
  environment             = var.environment
  service_name            = module.ecs_backend.service_name
  cluster_name            = module.ecs.cluster_name
  min_capacity            = var.backend_min_capacity
  max_capacity            = var.backend_max_capacity
  target_cpu_utilization  = var.backend_target_cpu

  tags = var.common_tags
}

# CloudWatch Logs and Monitoring
module "cloudwatch" {
  source = "./modules/cloudwatch"

  project_name = var.project_name
  environment  = var.environment

  tags = var.common_tags
}
