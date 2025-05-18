# Network Load Balancer Variables

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

variable "name" {
  description = "Name for the Network Load Balancer"
  type        = string
  default     = "vpn-nlb"
}

variable "vpc_id" {
  description = "ID of the VPC where the NLB will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the NLB"
  type        = list(string)
}

variable "internal" {
  description = "Whether the NLB is internal or internet-facing"
  type        = bool
  default     = false
}

variable "enable_deletion_protection" {
  description = "Enable deletion protection for the NLB"
  type        = bool
  default     = false
}

variable "enable_cross_zone_load_balancing" {
  description = "Enable cross-zone load balancing"
  type        = bool
  default     = true
}

# Target Group Configuration
variable "target_type" {
  description = "Type of target for the target group (instance, ip, alb, lambda)"
  type        = string
  default     = "instance"
}

variable "deregistration_delay" {
  description = "Time in seconds before deregistering a target"
  type        = number
  default     = 300
}

variable "health_check_enabled" {
  description = "Whether health checks are enabled for the target group"
  type        = bool
  default     = true
}

variable "health_check_interval" {
  description = "Interval in seconds between health checks"
  type        = number
  default     = 30
}

variable "health_check_path" {
  description = "Path for HTTP health checks"
  type        = string
  default     = "/"
}

variable "health_check_port" {
  description = "Port for health checks"
  type        = string
  default     = "traffic-port"
}

variable "health_check_protocol" {
  description = "Protocol for health checks (TCP, HTTP, HTTPS)"
  type        = string
  default     = "TCP"
}

variable "health_check_timeout" {
  description = "Timeout in seconds for health checks"
  type        = number
  default     = 10
}

variable "healthy_threshold" {
  description = "Number of consecutive successful health checks to mark a target as healthy"
  type        = number
  default     = 3
}

variable "unhealthy_threshold" {
  description = "Number of consecutive failed health checks to mark a target as unhealthy"
  type        = number
  default     = 3
}

# WireGuard Configuration
variable "wireguard_port" {
  description = "UDP port for WireGuard"
  type        = number
  default     = 51820
}

# Tags
variable "additional_tags" {
  description = "Additional tags for NLB resources"
  type        = map(string)
  default     = {}
}