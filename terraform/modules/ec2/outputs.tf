# EC2 Module Outputs

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.vpn_server.id
}

output "private_ip" {
  description = "Private IP of the EC2 instance"
  value       = aws_instance.vpn_server.private_ip
}

output "public_ip" {
  description = "Public IP of the EC2 instance (if available)"
  value       = aws_instance.vpn_server.public_ip
}

output "instance_state" {
  description = "Current state of the EC2 instance"
  value       = aws_instance.vpn_server.instance_state
}

output "iam_role_name" {
  description = "Name of the IAM role"
  value       = var.create_iam_role ? aws_iam_role.ec2_role[0].name : null
}

output "iam_role_arn" {
  description = "ARN of the IAM role"
  value       = var.create_iam_role ? aws_iam_role.ec2_role[0].arn : null
}

output "instance_profile_name" {
  description = "Name of the IAM instance profile"
  value       = var.create_iam_role ? aws_iam_instance_profile.ec2_profile[0].name : null
}

output "instance_profile_arn" {
  description = "ARN of the IAM instance profile"
  value       = var.create_iam_role ? aws_iam_instance_profile.ec2_profile[0].arn : null
}

output "security_group_ids" {
  description = "IDs of the security groups attached to the EC2 instance"
  value       = var.security_group_ids
}

output "subnet_id" {
  description = "ID of the subnet where the EC2 instance is launched"
  value       = var.subnet_ids[0]
}