
# EC2 Variables
variable "vpn_server_ami_id" {
  description = "AMI ID for the VPN server (Ubuntu 22.04 LTS)"
  type        = string
  default     = "ami-0ed99df77a82560e6"  # Ubuntu 22.04 LTS in us-east-1 (update for your region)
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
