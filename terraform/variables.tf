variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "container_port_backend" {
  description = "Backend container port"
  type        = number
}

variable "container_port_frontend" {
  description = "Frontend container port"
  type        = number
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "backend_cpu" {
  description = "CPU units for backend ECS task (256-4096)"
  type        = number
}

variable "backend_memory" {
  description = "Memory in MB for backend ECS task"
  type        = number
}

variable "frontend_cpu" {
  description = "CPU units for frontend ECS task (256-4096)"
  type        = number
}

variable "frontend_memory" {
  description = "Memory in MB for frontend ECS task"
  type        = number
}

variable "backend_desired_count" {
  description = "Desired number of backend tasks"
  type        = number
}

variable "frontend_desired_count" {
  description = "Desired number of frontend tasks"
  type        = number
}

variable "backend_min_capacity" {
  description = "Minimum number of backend tasks for auto scaling"
  type        = number
}

variable "backend_max_capacity" {
  description = "Maximum number of backend tasks for auto scaling"
  type        = number
}

variable "backend_target_cpu" {
  description = "Target CPU utilization percentage for backend auto scaling"
  type        = number
}

variable "rds_allocated_storage" {
  description = "Allocated storage for RDS in GB"
  type        = number
}

variable "rds_instance_class" {
  description = "RDS instance class (e.g., db.t3.micro)"
  type        = string
}

variable "rds_backup_retention" {
  description = "RDS backup retention days"
  type        = number
}

variable "redis_node_type" {
  description = "ElastiCache node type (e.g., cache.t3.micro)"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
}

// Control RDS Multi-AZ (override default behavior). When null, defaults to
// true for non-dev and false for dev.
variable "rds_multi_az" {
  description = "Enable Multi-AZ for RDS (true/false). Null = default by env."
  type        = bool
  default     = null
}

// Optional image URIs to decouple registry from ECR module
// When null, defaults to ECR repositories created by module.ecr with :latest
variable "backend_image_uri" {
  description = "Full image URI for backend (e.g., ghcr.io/owner/repo/backend:tag or account.dkr.ecr.us-east-1.amazonaws.com/repo:tag)"
  type        = string
  default     = null
}

variable "frontend_image_uri" {
  description = "Full image URI for frontend (e.g., ghcr.io/owner/repo/frontend:tag or account.dkr.ecr.us-east-1.amazonaws.com/repo:tag)"
  type        = string
  default     = null
}
