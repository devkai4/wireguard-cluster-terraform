provider "aws" {
  region  = var.region
  profile = var.aws_profile
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"  # Tokyo region
}

variable "aws_profile" {
  description = "AWS CLI profile to use"
  type        = string
  default     = "vpn-project"
}

# EC2 Variables
# AMI ID for Tokyo region (ap-northeast-1)
variable "vpn_server_ami_id" {
  description = "AMI ID for the VPN server (Ubuntu 22.04 LTS in Tokyo region)"
  type        = string
  default     = "ami-0bc4853c891c551f8"
}

# Availability Zones for Tokyo region
variable "availability_zones" {
  description = "List of availability zones in Tokyo region"
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
}

variable "vpn_server_instance_type" {
  description = "EC2 instance type for the VPN server"
  type        = string
  default     = "t3.micro"
}

variable "ssh_key_name" {
  description = "SSH key name for the EC2 instance"
  type        = string
  default     = null  # Will need to be set in terraform.tfvars
}
# WireGuard Variables
variable "wireguard_port" {
  description = "UDP port for WireGuard"
  type        = number
  default     = 51820
}

variable "wireguard_network" {
  description = "Internal network CIDR for WireGuard"
  type        = string
  default     = "10.8.0.0/24"
}

variable "project" {
  description = "Project name"
  type        = string
  default     = "vpn-cluster"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "devkai4"
}