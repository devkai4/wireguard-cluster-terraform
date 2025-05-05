variable "aws_region" {
  description = "AWS region for backend resources"
  type = string
  default = "ap-northeast-1"
}

variable "project_name" {
  description = "Name of the project"
  type = string
  default = "vpn-cluster"
}

variable "environment" {
  description = "Environment name"
  type = string
  default = "global"
}