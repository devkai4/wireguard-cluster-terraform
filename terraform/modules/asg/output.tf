# Auto Scaling Group Module Outputs - Fixed

output "asg_id" {
  description = "ID of the Auto Scaling Group"
  value       = aws_autoscaling_group.vpn_server.id
}

output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.vpn_server.name
}

output "asg_arn" {
  description = "ARN of the Auto Scaling Group"
  value       = aws_autoscaling_group.vpn_server.arn
}

output "launch_template_id" {
  description = "ID of the Launch Template"
  value       = aws_launch_template.vpn_server.id
}

output "launch_template_name" {
  description = "Name of the Launch Template"
  value       = aws_launch_template.vpn_server.name
}

output "launch_template_arn" {
  description = "ARN of the Launch Template"
  value       = aws_launch_template.vpn_server.arn
}

output "launch_template_latest_version" {
  description = "Latest version of the Launch Template"
  value       = aws_launch_template.vpn_server.latest_version
}

output "iam_role_name" {
  description = "Name of the IAM role created for the instances"
  value       = var.create_iam_role ? aws_iam_role.ec2_role[0].name : null
}

output "iam_role_arn" {
  description = "ARN of the IAM role created for the instances"
  value       = var.create_iam_role ? aws_iam_role.ec2_role[0].arn : null
}

output "iam_instance_profile_name" {
  description = "Name of the IAM instance profile"
  value       = var.create_iam_role ? aws_iam_instance_profile.ec2_profile[0].name : var.iam_instance_profile
}

output "iam_instance_profile_arn" {
  description = "ARN of the IAM instance profile"
  value       = var.create_iam_role ? aws_iam_instance_profile.ec2_profile[0].arn : null
}

output "scaling_policies" {
  description = "Map of scaling policies created"
  value = {
    scale_out_cpu     = var.enable_cpu_scaling ? aws_autoscaling_policy.scale_out_cpu[0].name : null
    scale_in_cpu      = var.enable_cpu_scaling ? aws_autoscaling_policy.scale_in_cpu[0].name : null
    scale_out_network = var.enable_network_scaling ? aws_autoscaling_policy.scale_out_network[0].name : null
    scale_in_network  = var.enable_network_scaling ? aws_autoscaling_policy.scale_in_network[0].name : null
  }
}

output "cloudwatch_alarms" {
  description = "Map of CloudWatch alarms created"
  value = {
    cpu_high     = var.enable_cpu_scaling ? aws_cloudwatch_metric_alarm.cpu_high[0].alarm_name : null
    cpu_low      = var.enable_cpu_scaling ? aws_cloudwatch_metric_alarm.cpu_low[0].alarm_name : null
    network_high = var.enable_network_scaling ? aws_cloudwatch_metric_alarm.network_high[0].alarm_name : null
    network_low  = var.enable_network_scaling ? aws_cloudwatch_metric_alarm.network_low[0].alarm_name : null
  }
}