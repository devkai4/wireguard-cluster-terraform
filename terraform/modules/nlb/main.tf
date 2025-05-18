# Network Load Balancer Module

# Create Network Load Balancer
resource "aws_lb" "nlb" {
  name                             = "${var.name}-${var.environment}"
  internal                         = var.internal
  load_balancer_type               = "network"
  subnets                          = var.subnet_ids
  enable_deletion_protection       = var.enable_deletion_protection
  enable_cross_zone_load_balancing = var.enable_cross_zone_load_balancing

  tags = merge(
    {
      Name        = "${var.name}-${var.environment}"
      Environment = var.environment
      Project     = var.project
      Owner       = var.owner
      ManagedBy   = "terraform"
    },
    var.additional_tags
  )
}

# Create Target Group for WireGuard UDP traffic
resource "aws_lb_target_group" "wireguard" {
  name                 = "${var.name}-${var.environment}-tg"
  port                 = var.wireguard_port
  protocol             = "UDP"
  vpc_id               = var.vpc_id
  target_type          = var.target_type
  deregistration_delay = var.deregistration_delay
  preserve_client_ip   = true

  health_check {
    enabled             = var.health_check_enabled
    interval            = var.health_check_interval
    port                = var.health_check_port
    protocol            = var.health_check_protocol
    healthy_threshold   = var.healthy_threshold
    unhealthy_threshold = var.unhealthy_threshold
  }

  tags = merge(
    {
      Name        = "${var.name}-${var.environment}-tg"
      Environment = var.environment
      Project     = var.project
      Owner       = var.owner
      ManagedBy   = "terraform"
    },
    var.additional_tags
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Create Listener for the NLB
resource "aws_lb_listener" "wireguard" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = var.wireguard_port
  protocol          = "UDP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wireguard.arn
  }

  tags = merge(
    {
      Name        = "${var.name}-${var.environment}-listener"
      Environment = var.environment
      Project     = var.project
      Owner       = var.owner
      ManagedBy   = "terraform"
    },
    var.additional_tags
  )
}

# Create DNS record for the NLB
# Uncomment and modify this section if you want to create a DNS record for the NLB
# resource "aws_route53_record" "nlb" {
#   zone_id = "YOUR_HOSTED_ZONE_ID"
#   name    = "vpn.${var.environment}.yourdomain.com"
#   type    = "A"
#
#   alias {
#     name                   = aws_lb.nlb.dns_name
#     zone_id                = aws_lb.nlb.zone_id
#     evaluate_target_health = true
#   }
# }