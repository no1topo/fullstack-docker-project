variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "service_name" {
  type = string
}

variable "cluster_id" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "task_family" {
  type = string
}

variable "ecr_image_uri" {
  type = string
}

variable "container_port" {
  type = number
}

variable "task_cpu" {
  type = number
}

variable "task_memory" {
  type = number
}

variable "desired_count" {
  type = number
}

variable "execution_role_arn" {
  type = string
}

variable "task_role_arn" {
  type = string
}

variable "target_group_arn" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "security_group_ids" {
  type = list(string)
}

variable "rds_endpoint" {
  type    = string
  default = null
}

variable "rds_database" {
  type    = string
  default = null
}

variable "cloudwatch_log_group" {
  type = string
}

variable "additional_environment_variables" {
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "tags" {
  type = map(string)
}

variable "rds_secret_arn" {
  description = "ARN of Secrets Manager secret containing RDS credentials (username,password,database)"
  type        = string
  default     = null
}
