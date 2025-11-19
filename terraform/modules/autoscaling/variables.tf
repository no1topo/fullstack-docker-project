variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "service_name" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "min_capacity" {
  type = number
}

variable "max_capacity" {
  type = number
}

variable "target_cpu_utilization" {
  type    = number
  default = 70
}

variable "tags" {
  type = map(string)
}
