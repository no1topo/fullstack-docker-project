variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "private_subnet_cidrs" {
  type = list(string)
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway for all private subnets to reduce EIP usage"
  type        = bool
  default     = true
}

variable "tags" {
  type = map(string)
}

variable "azs" {
  type = list(string)
  default = [
    "us-east-1a",
    "us-east-1c",
    "us-east-1d"
  ]
}