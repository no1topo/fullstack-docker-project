aws_region             = "us-east-1"
environment            = "staging"
project_name           = "fullstack-docker"
container_port_backend = 8080
container_port_frontend = 5000

# Networking
vpc_cidr             = "10.0.0.0/16"
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
public_subnet_cidrs  = ["10.0.101.0/24", "10.0.102.0/24"]

# ECS Task Sizing (staging is moderate)
backend_cpu    = 512
backend_memory = 1024
frontend_cpu   = 256
frontend_memory = 512

# Desired Task Counts
backend_desired_count  = 2
frontend_desired_count = 2

# Auto Scaling
backend_min_capacity = 1
backend_max_capacity = 3
backend_target_cpu   = 70

# RDS
rds_allocated_storage = 50
rds_instance_class    = "db.t3.small"
rds_backup_retention  = 14

# Redis
redis_node_type = "cache.t3.small"

# Tags
common_tags = {
  Environment = "staging"
  Project     = "fullstack-docker"
  ManagedBy   = "Terraform"
  CreatedAt   = "2025-11-19"
}
