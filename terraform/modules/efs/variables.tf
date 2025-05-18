# Shared Storage Module Variables

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
  description = "Name for the EFS file system"
  type        = string
  default     = "vpn-efs"
}

variable "vpc_id" {
  description = "ID of the VPC where the EFS will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the EFS mount targets"
  type        = list(string)
}

variable "security_group_ids" {
  description = "List of security group IDs to attach to the EFS mount targets"
  type        = list(string)
  default     = []
}

variable "create_security_group" {
  description = "Whether to create a security group for EFS"
  type        = bool
  default     = true
}

variable "allowed_cidr_blocks" {
  description = "List of CIDR blocks allowed to access the EFS"
  type        = list(string)
  default     = []
}

variable "encrypted" {
  description = "Whether the EFS file system is encrypted"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key ID to encrypt the EFS file system"
  type        = string
  default     = null
}

variable "performance_mode" {
  description = "Performance mode for the EFS file system (generalPurpose or maxIO)"
  type        = string
  default     = "generalPurpose"
}

variable "throughput_mode" {
  description = "Throughput mode for the EFS file system (bursting, provisioned, or elastic)"
  type        = string
  default     = "bursting"
}

variable "provisioned_throughput_in_mibps" {
  description = "Provisioned throughput in MiB/s (required if throughput_mode is provisioned)"
  type        = number
  default     = null
}

variable "lifecycle_policy" {
  description = "Lifecycle policy for the EFS file system (AFTER_7_DAYS, AFTER_14_DAYS, AFTER_30_DAYS, AFTER_60_DAYS, AFTER_90_DAYS, AFTER_N_DAYS)"
  type        = string
  default     = "AFTER_30_DAYS"
}

variable "backup_policy" {
  description = "Backup policy for the EFS file system (ENABLED or DISABLED)"
  type        = string
  default     = "ENABLED"
}

# Tags
variable "additional_tags" {
  description = "Additional tags for EFS resources"
  type        = map(string)
  default     = {}
}