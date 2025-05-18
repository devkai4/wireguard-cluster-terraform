# Dev Environment Outputs - Updated for High Availability with correct module attributes
# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = module.vpc.vpc_cidr
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

# Network Load Balancer Outputs
output "nlb_dns_name" {
  description = "DNS name of the VPN Network Load Balancer"
  value       = module.nlb.nlb_dns_name
}

output "nlb_zone_id" {
  description = "Zone ID of the VPN Network Load Balancer"
  value       = module.nlb.nlb_zone_id
}

output "vpn_endpoint" {
  description = "VPN endpoint for client configuration"
  value       = module.nlb.endpoint
}

# Auto Scaling Group Outputs
output "asg_name" {
  description = "Name of the Auto Scaling Group for VPN servers"
  value       = module.vpn_asg.asg_name
}

output "asg_id" {
  description = "ID of the Auto Scaling Group for VPN servers"
  value       = module.vpn_asg.asg_id
}

output "launch_template_name" {
  description = "Name of the Launch Template for VPN servers"
  value       = module.vpn_asg.launch_template_name
}

output "launch_template_version" {
  description = "Latest version of the Launch Template for VPN servers"
  value       = module.vpn_asg.launch_template_latest_version
}

# Shared Storage Outputs
output "efs_id" {
  description = "ID of the EFS file system for WireGuard configuration"
  value       = var.enable_shared_storage ? module.efs[0].efs_id : null
}

output "efs_dns_name" {
  description = "DNS name of the EFS file system for WireGuard configuration"
  value       = var.enable_shared_storage ? module.efs[0].efs_dns_name : null
}

# Connection Information for Documentation
output "vpn_connection_info" {
  description = "Information for connecting to the VPN"
  value = {
    endpoint     = module.nlb.endpoint
    port         = var.wireguard_port
    protocol     = "UDP (WireGuard)"
    client_setup = "Use the gen-client-config.sh script on any VPN server to generate client configurations."
  }
}