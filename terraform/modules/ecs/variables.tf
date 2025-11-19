variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "cluster_insights_enabled" {
  type    = bool
  default = true
}

variable "tags" {
  type = map(string)
}
