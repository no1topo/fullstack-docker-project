output "service_name" {
  value = aws_ecs_service.main.name
}

output "service_arn" {
  value = aws_ecs_service.main.id
}

output "task_definition_arn" {
  value = aws_ecs_task_definition.main.arn
}

variable "rds_endpoint" {
  description = "The hostname (address only, no port) of the RDS instance."
  type        = string
  default     = null
}

variable "rds_port" {
  description = "The port number of the RDS instance."
  type        = number
  default     = 5432
}
