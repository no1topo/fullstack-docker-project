variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "node_type" {
  type = string
}

variable "vpc_security_group_ids" {
  type = list(string)
}

variable "subnet_group_name" {
  type = string
}

variable "tags" {
  type = map(string)
}
