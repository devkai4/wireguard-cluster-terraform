
# EC2 Outputs
output "vpn_server_instance_id" {
  description = "ID of the VPN server EC2 instance"
  value       = try(module.vpn_server[0].instance_id, null)
}

output "vpn_server_public_ip" {
  description = "Public IP of the VPN server EC2 instance"
  value       = try(module.vpn_server[0].public_ip, null)
}

output "vpn_server_private_ip" {
  description = "Private IP of the VPN server EC2 instance"
  value       = try(module.vpn_server[0].private_ip, null)
}
