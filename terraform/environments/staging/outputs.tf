output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.alb.alb_dns_name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = module.alb.alb_arn
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs.cluster_name
}

output "backend_service_name" {
  description = "Name of the backend ECS service"
  value       = module.ecs_backend.service_name
}

output "frontend_service_name" {
  description = "Name of the frontend ECS service"
  value       = module.ecs_frontend.service_name
}

output "rds_endpoint" {
  description = "RDS database endpoint"
  value       = module.rds.endpoint
  sensitive   = true
}

output "rds_database_name" {
  description = "RDS database name"
  value       = module.rds.database_name
}

output "redis_endpoint" {
  description = "ElastiCache Redis primary endpoint"
  value       = module.redis.primary_endpoint_address
  sensitive   = true
}

output "ecr_backend_repository_url" {
  description = "ECR repository URL for backend"
  value       = module.ecr.backend_image_uri
}

output "ecr_frontend_repository_url" {
  description = "ECR repository URL for frontend"
  value       = module.ecr.frontend_image_uri
}

output "backend_log_group" {
  description = "CloudWatch log group for backend"
  value       = module.cloudwatch.backend_log_group
}

output "frontend_log_group" {
  description = "CloudWatch log group for frontend"
  value       = module.cloudwatch.frontend_log_group
}
