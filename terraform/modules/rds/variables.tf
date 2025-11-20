variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "allocated_storage" {
  type = number
}

variable "instance_class" {
  type = string
}

variable "backup_retention_days" {
  type = number
}

variable "vpc_security_group_ids" {
  type = list(string)
}

variable "db_subnet_group_name" {
  type = string
}

variable "tags" {
  type = map(string)
}

variable "multi_az" {
  description = "Whether to enable Multi-AZ for RDS"
  type        = bool
}
