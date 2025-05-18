# Auto Scaling Group Module

# Use datasource to get Ubuntu 22.04 LTS AMI if not specified
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# Generate a random suffix for uniqueness
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# IAM Role for EC2 instances
resource "aws_iam_role" "ec2_role" {
  count = var.create_iam_role ? 1 : 0
  name  = "${var.instance_name}-role-${random_string.suffix.result}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(
    {
      Name        = "${var.instance_name}-role"
      Environment = var.environment
      Project     = var.project
      Owner       = var.owner
      ManagedBy   = "terraform"
    },
    var.additional_tags
  )
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  count = var.create_iam_role ? 1 : 0
  name  = "${var.instance_name}-profile-${random_string.suffix.result}"
  role  = aws_iam_role.ec2_role[0].name

  tags = merge(
    {
      Name        = "${var.instance_name}-profile"
      Environment = var.environment
      Project     = var.project
      Owner       = var.owner
      ManagedBy   = "terraform"
    },
    var.additional_tags
  )
}

# Attach SSM policy to IAM role if needed for management
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  count      = var.create_iam_role ? 1 : 0
  role       = aws_iam_role.ec2_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach CloudWatch policy to IAM role for monitoring
resource "aws_iam_role_policy_attachment" "cloudwatch_policy" {
  count      = var.create_iam_role ? 1 : 0
  role       = aws_iam_role.ec2_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Attach additional IAM policies
resource "aws_iam_role_policy_attachment" "additional_policies" {
  count      = var.create_iam_role ? length(var.iam_policies) : 0
  role       = aws_iam_role.ec2_role[0].name
  policy_arn = var.iam_policies[count.index]
}

# User data template for WireGuard setup
locals {
  default_user_data_vars = {
    hostname                = "${var.instance_name}-${var.environment}"
    install_cloudwatch_agent = "true"
    install_node_exporter   = "true"
    install_wireguard       = "true"
    wireguard_port          = var.wireguard_port
    wireguard_network       = var.wireguard_network
    enable_shared_storage   = var.enable_shared_storage ? "true" : "false"
    efs_id                  = var.efs_id
    log_group_name          = "/vpn-cluster/${var.environment}/vpn-server"
    additional_user_data    = ""
  }
  
  user_data_vars = merge(local.default_user_data_vars, var.user_data_vars)
  
  # If user_data_base64 is provided, use it; otherwise, generate from template
  user_data = var.user_data_base64 != null ? var.user_data_base64 : base64encode(templatefile("${path.module}/user_data.tpl", local.user_data_vars))
}

# Launch Template
resource "aws_launch_template" "vpn_server" {
  name          = "${var.instance_name}-${var.environment}-${random_string.suffix.result}"
  image_id      = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  user_data     = local.user_data
  key_name      = var.key_name

  # IAM role
  iam_instance_profile {
    name = var.create_iam_role ? aws_iam_instance_profile.ec2_profile[0].name : var.iam_instance_profile
  }

  # Security groups
  vpc_security_group_ids = var.security_group_ids

  # Block device mappings
  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size           = var.root_volume_size
      volume_type           = var.root_volume_type
      delete_on_termination = true
      encrypted             = true
    }
  }

  # Instance market options - Spot instances
  dynamic "instance_market_options" {
    for_each = var.use_spot_instances ? [1] : []
    content {
      market_type = "spot"
      spot_options {
        max_price = null  # Use default on-demand price as maximum
      }
    }
  }

  # Monitoring
  monitoring {
    enabled = var.enable_monitoring
  }

  # Metadata options for improved security
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  # Tags
  tag_specifications {
    resource_type = "instance"
    tags = merge(
      {
        Name        = "${var.instance_name}-${var.environment}"
        Environment = var.environment
        Project     = var.project
        Owner       = var.owner
        ManagedBy   = "terraform"
        Service     = "VPN"
        Application = "WireGuard"
      },
      var.additional_tags
    )
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(
      {
        Name        = "${var.instance_name}-${var.environment}-volume"
        Environment = var.environment
        Project     = var.project
        Owner       = var.owner
        ManagedBy   = "terraform"
      },
      var.additional_tags
    )
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "vpn_server" {
  name                      = "${var.instance_name}-${var.environment}-asg"
  min_size                  = var.min_size
  max_size                  = var.max_size
  desired_capacity          = var.desired_capacity
  vpc_zone_identifier       = var.subnet_ids
  health_check_type         = var.health_check_type
  health_check_grace_period = var.health_check_grace_period
  default_cooldown          = var.default_cooldown
  target_group_arns         = var.target_group_arns
  
  # Launch template
  launch_template {
    id      = aws_launch_template.vpn_server.id
    version = "$Latest"
  }

  # Instance refresh
  dynamic "instance_refresh" {
    for_each = var.enable_instance_refresh ? [1] : []
    content {
      strategy = var.instance_refresh_strategy
      preferences {
        min_healthy_percentage = var.min_healthy_percentage
        instance_warmup        = var.health_check_grace_period
      }
    }
  }

  # Tags
  dynamic "tag" {
    for_each = merge(
      {
        Name        = "${var.instance_name}-${var.environment}"
        Environment = var.environment
        Project     = var.project
        Owner       = var.owner
        ManagedBy   = "terraform"
        Service     = "VPN"
        Application = "WireGuard"
      },
      var.additional_tags
    )
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [desired_capacity]
  }
}

# CloudWatch Alarm for CPU High
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  count               = var.enable_cpu_scaling ? 1 : 0
  alarm_name          = "${var.instance_name}-${var.environment}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = var.cpu_high_threshold
  alarm_description   = "Scale up when CPU exceeds ${var.cpu_high_threshold}%"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.vpn_server.name
  }
  alarm_actions = [aws_autoscaling_policy.scale_out_cpu[0].arn]
  
  tags = merge(
    {
      Name        = "${var.instance_name}-${var.environment}-cpu-high"
      Environment = var.environment
      Project     = var.project
      Owner       = var.owner
      ManagedBy   = "terraform"
    },
    var.additional_tags
  )
}

# CloudWatch Alarm for CPU Low
resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  count               = var.enable_cpu_scaling ? 1 : 0
  alarm_name          = "${var.instance_name}-${var.environment}-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = var.cpu_low_threshold
  alarm_description   = "Scale down when CPU below ${var.cpu_low_threshold}%"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.vpn_server.name
  }
  alarm_actions = [aws_autoscaling_policy.scale_in_cpu[0].arn]
  
  tags = merge(
    {
      Name        = "${var.instance_name}-${var.environment}-cpu-low"
      Environment = var.environment
      Project     = var.project
      Owner       = var.owner
      ManagedBy   = "terraform"
    },
    var.additional_tags
  )
}

# CloudWatch Alarm for Network High
resource "aws_cloudwatch_metric_alarm" "network_high" {
  count               = var.enable_network_scaling ? 1 : 0
  alarm_name          = "${var.instance_name}-${var.environment}-network-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "NetworkIn"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = var.network_in_high_threshold
  alarm_description   = "Scale up when Network In exceeds ${var.network_in_high_threshold} bytes"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.vpn_server.name
  }
  alarm_actions = [aws_autoscaling_policy.scale_out_network[0].arn]
  
  tags = merge(
    {
      Name        = "${var.instance_name}-${var.environment}-network-high"
      Environment = var.environment
      Project     = var.project
      Owner       = var.owner
      ManagedBy   = "terraform"
    },
    var.additional_tags
  )
}

# CloudWatch Alarm for Network Low
resource "aws_cloudwatch_metric_alarm" "network_low" {
  count               = var.enable_network_scaling ? 1 : 0
  alarm_name          = "${var.instance_name}-${var.environment}-network-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "NetworkIn"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = var.network_in_low_threshold
  alarm_description   = "Scale down when Network In below ${var.network_in_low_threshold} bytes"
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.vpn_server.name
  }
  alarm_actions = [aws_autoscaling_policy.scale_in_network[0].arn]
  
  tags = merge(
    {
      Name        = "${var.instance_name}-${var.environment}-network-low"
      Environment = var.environment
      Project     = var.project
      Owner       = var.owner
      ManagedBy   = "terraform"
    },
    var.additional_tags
  )
}

# Auto Scaling Policy - Scale Out CPU
resource "aws_autoscaling_policy" "scale_out_cpu" {
  count                  = var.enable_cpu_scaling ? 1 : 0
  name                   = "${var.instance_name}-${var.environment}-scale-out-cpu"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.vpn_server.name
}

# Auto Scaling Policy - Scale In CPU
resource "aws_autoscaling_policy" "scale_in_cpu" {
  count                  = var.enable_cpu_scaling ? 1 : 0
  name                   = "${var.instance_name}-${var.environment}-scale-in-cpu"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.vpn_server.name
}

# Auto Scaling Policy - Scale Out Network
resource "aws_autoscaling_policy" "scale_out_network" {
  count                  = var.enable_network_scaling ? 1 : 0
  name                   = "${var.instance_name}-${var.environment}-scale-out-network"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.vpn_server.name
}

# Auto Scaling Policy - Scale In Network
resource "aws_autoscaling_policy" "scale_in_network" {
  count                  = var.enable_network_scaling ? 1 : 0
  name                   = "${var.instance_name}-${var.environment}-scale-in-network"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.vpn_server.name
}