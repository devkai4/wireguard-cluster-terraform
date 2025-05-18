# Network Load Balancer Module Outputs

output "nlb_id" {
  description = "ID of the Network Load Balancer"
  value       = aws_lb.nlb.id
}

output "nlb_arn" {
  description = "ARN of the Network Load Balancer"
  value       = aws_lb.nlb.arn
}

output "nlb_dns_name" {
  description = "DNS name of the Network Load Balancer"
  value       = aws_lb.nlb.dns_name
}

output "nlb_zone_id" {
  description = "Zone ID of the Network Load Balancer"
  value       = aws_lb.nlb.zone_id
}

output "target_group_arn" {
  description = "ARN of the Target Group"
  value       = aws_lb_target_group.wireguard.arn
}

output "target_group_id" {
  description = "ID of the Target Group"
  value       = aws_lb_target_group.wireguard.id
}

output "target_group_name" {
  description = "Name of the Target Group"
  value       = aws_lb_target_group.wireguard.name
}

output "listener_arn" {
  description = "ARN of the Listener"
  value       = aws_lb_listener.wireguard.arn
}

output "listener_id" {
  description = "ID of the Listener"
  value       = aws_lb_listener.wireguard.id
}

output "endpoint" {
  description = "Endpoint for WireGuard client configurations"
  value       = "${aws_lb.nlb.dns_name}:${var.wireguard_port}"
}