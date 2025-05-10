# EC2 Variable definitions
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

# EC2 Instance Configuration
variable "instance_name" {
  description = "Name of the EC2 instance"
  type        = string
  default     = "vpn-server"
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance (Ubuntu 22.04 LTS)"
  type        = string
  # Default to Ubuntu 22.04 LTS in ap-northeast-1 (Tokyo region)
  default     = "ami-0ed99df77a82560e6"  # Ubuntu 22.04 LTS in ap-northeast-1
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "SSH key name for the EC2 instance"
  type        = string
  default     = null
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "subnet_ids" {
  description = "IDs of the subnets where EC2 instances will be launched"
  type        = list(string)
}

variable "security_group_ids" {
  description = "IDs of the security groups to attach to EC2 instances"
  type        = list(string)
}

variable "associate_public_ip" {
  description = "Whether to associate a public IP address with the instance"
  type        = bool
  default     = false
}

variable "root_volume_size" {
  description = "Size of the root volume in GB"
  type        = number
  default     = 20
}

variable "root_volume_type" {
  description = "Type of the root volume"
  type        = string
  default     = "gp3"
}

variable "enable_monitoring" {
  description = "Enable detailed monitoring for the instance"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags for the EC2 instance"
  type        = map(string)
  default     = {}
}

# IAM Role Configuration
variable "create_iam_role" {
  description = "Whether to create an IAM role for the EC2 instance"
  type        = bool
  default     = true
}

variable "iam_role_name" {
  description = "Name of the IAM role for the EC2 instance"
  type        = string
  default     = null
}

variable "iam_policies" {
  description = "List of IAM policies to attach to the IAM role"
  type        = list(string)
  default     = []
}

# User Data Configuration
variable "user_data_vars" {
  description = "Variables to pass to the user data template"
  type        = map(string)
  default     = {}
}

variable "enable_ssm_session_manager" {
  description = "Whether to enable SSM Session Manager for the EC2 instance"
  type        = bool
  default     = true
}