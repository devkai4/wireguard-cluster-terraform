# Auto Scaling Group Variables - Updated with missing variables

variable "project" {
  description = "Project name for resource tagging"
  type        = string
  default     = "vpn-cluster"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Owner of the resources"
  type        = string
  default     = "devkai4"
}

# Launch Template Configuration
variable "instance_name" {
  description = "Base name for the instances"
  type        = string
  default     = "vpn-server"
}

variable "ami_id" {
  description = "AMI ID for VPN server instances"
  type        = string
  # If empty, the module will use the latest Ubuntu 22.04 AMI
  default     = ""
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "SSH key name for instances"
  type        = string
  default     = null
}

variable "vpc_id" {
  description = "ID of the VPC where resources will be created"
  type        = string
}

variable "security_group_ids" {
  description = "Security group IDs to attach to instances"
  type        = list(string)
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

variable "user_data_base64" {
  description = "Base64-encoded user data script (leave empty to use default)"
  type        = string
  default     = null
}

variable "enable_monitoring" {
  description = "Enable detailed monitoring for instances"
  type        = bool
  default     = true
}

variable "use_spot_instances" {
  description = "Whether to use Spot Instances for cost savings (not recommended for production)"
  type        = bool
  default     = false
}

# IAM Configuration
variable "iam_role_name" {
  description = "Name of the IAM role to attach to instances (if not creating a new one)"
  type        = string
  default     = null
}

variable "iam_instance_profile" {
  description = "IAM instance profile name to attach to instances"
  type        = string
  default     = null
}

variable "create_iam_role" {
  description = "Whether to create a new IAM role for the instances"
  type        = bool
  default     = true
}

variable "iam_policies" {
  description = "List of IAM policy ARNs to attach to the IAM role"
  type        = list(string)
  default     = []
}

# Auto Scaling Group Configuration
variable "subnet_ids" {
  description = "List of subnet IDs where instances will be launched"
  type        = list(string)
}

variable "min_size" {
  description = "Minimum number of instances in the ASG"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of instances in the ASG"
  type        = number
  default     = 3
}

variable "desired_capacity" {
  description = "Desired number of instances in the ASG"
  type        = number
  default     = 2
}

variable "health_check_type" {
  description = "Health check type for ASG (EC2 or ELB)"
  type        = string
  default     = "EC2"
}

variable "health_check_grace_period" {
  description = "Time in seconds after instance comes into service before checking health"
  type        = number
  default     = 300
}

variable "target_group_arns" {
  description = "List of target group ARNs to attach the ASG instances to"
  type        = list(string)
  default     = []
}

variable "default_cooldown" {
  description = "Time in seconds the ASG waits before another scaling activity"
  type        = number
  default     = 300
}

# Scaling Policies
variable "enable_cpu_scaling" {
  description = "Enable CPU-based scaling policies"
  type        = bool
  default     = true
}

variable "cpu_high_threshold" {
  description = "CPU utilization percentage to trigger scale-out"
  type        = number
  default     = 70
}

variable "cpu_low_threshold" {
  description = "CPU utilization percentage to trigger scale-in"
  type        = number
  default     = 30
}

variable "enable_network_scaling" {
  description = "Enable network-based scaling policies"
  type        = bool
  default     = true
}

variable "network_in_high_threshold" {
  description = "Network in bytes to trigger scale-out"
  type        = number
  default     = 10000000 # 10 MB/s
}

variable "network_in_low_threshold" {
  description = "Network in bytes to trigger scale-in"
  type        = number
  default     = 2000000  # 2 MB/s
}

# Instance Refresh Configuration
variable "enable_instance_refresh" {
  description = "Enable instance refresh for the ASG"
  type        = bool
  default     = true
}

variable "instance_refresh_strategy" {
  description = "Instance refresh strategy (Rolling or All)"
  type        = string
  default     = "Rolling"
}

variable "min_healthy_percentage" {
  description = "Minimum percentage of healthy instances during instance refresh"
  type        = number
  default     = 90
}

# Tags
variable "additional_tags" {
  description = "Additional tags for ASG resources"
  type        = map(string)
  default     = {}
}

# WireGuard Configuration
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

# Shared Storage Configuration - Added missing variables
variable "enable_shared_storage" {
  description = "Enable shared storage using EFS for WireGuard configuration"
  type        = bool
  default     = false
}

variable "efs_id" {
  description = "ID of the EFS file system for WireGuard configuration (if enable_shared_storage is true)"
  type        = string
  default     = ""
}

# User data variables
variable "user_data_vars" {
  description = "Variables to pass to the user data script"
  type        = map(string)
  default     = {}
}