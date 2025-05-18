# Shared Storage Module Outputs

output "efs_id" {
  description = "ID of the EFS file system"
  value       = aws_efs_file_system.this.id
}

output "efs_arn" {
  description = "ARN of the EFS file system"
  value       = aws_efs_file_system.this.arn
}

output "efs_dns_name" {
  description = "DNS name of the EFS file system"
  value       = aws_efs_file_system.this.dns_name
}

output "mount_target_ids" {
  description = "IDs of the EFS mount targets"
  value       = aws_efs_mount_target.this[*].id
}

output "mount_target_ips" {
  description = "IPs of the EFS mount targets"
  value       = aws_efs_mount_target.this[*].ip_address
}

output "security_group_id" {
  description = "ID of the security group created for EFS"
  value       = var.create_security_group ? aws_security_group.efs[0].id : null
}

output "access_point_id" {
  description = "ID of the EFS access point for WireGuard"
  value       = aws_efs_access_point.wireguard.id
}

output "access_point_arn" {
  description = "ARN of the EFS access point for WireGuard"
  value       = aws_efs_access_point.wireguard.arn
}