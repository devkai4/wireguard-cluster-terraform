# Auto Scaling Group Module - Simplified user data handling

# Use datasource to get Ubuntu 22.04 LTS AMI
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
  name  = var.iam_role_name != null ? var.iam_role_name : "${var.instance_name}-role-${random_string.suffix.result}"

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

# Attach EFS policy to IAM role if shared storage is enabled
resource "aws_iam_role_policy_attachment" "efs_policy" {
  count      = var.create_iam_role && var.enable_shared_storage ? 1 : 0
  role       = aws_iam_role.ec2_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonElasticFileSystemClientReadWriteAccess"
}

# Attach additional IAM policies
resource "aws_iam_role_policy_attachment" "additional_policies" {
  count      = var.create_iam_role ? length(var.iam_policies) : 0
  role       = aws_iam_role.ec2_role[0].name
  policy_arn = var.iam_policies[count.index]
}

# User data - Use a simpler approach to avoid templatefile issues
# Create two separate user data scripts based on whether shared storage is enabled
locals {
  user_data_no_efs = <<-EOF
#!/bin/bash
# Initial server setup for VPN server in Auto Scaling Group

set -e

# Log setup progress
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "Starting VPN server setup script - $(date)"

# Update and install required packages
apt-get update
apt-get upgrade -y
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common \
    fail2ban \
    jq \
    unzip \
    wireguard \
    wireguard-tools \
    qrencode

# Set up hostname with instance ID for better identification
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
hostnamectl set-hostname ${var.instance_name}-$INSTANCE_ID

# Configure fail2ban
cat > /etc/fail2ban/jail.local << EOFAIL2BAN
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
EOFAIL2BAN

# Restart fail2ban
systemctl restart fail2ban
echo "Fail2ban configured and restarted"

# Enable IP forwarding for WireGuard
echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-wireguard.conf
sysctl -p /etc/sysctl.d/99-wireguard.conf

# Standard local storage setup
mkdir -p /etc/wireguard/clients
chmod 700 /etc/wireguard

# Generate WireGuard keys
wg genkey | tee /etc/wireguard/server_private_key | wg pubkey > /etc/wireguard/server_public_key
chmod 600 /etc/wireguard/server_private_key
chmod 644 /etc/wireguard/server_public_key

# Create initial WireGuard config
SERVER_PRIVATE_KEY=$(cat /etc/wireguard/server_private_key)
cat > /etc/wireguard/wg0.conf << EOFWG
# WireGuard Server Configuration
[Interface]
Address = 10.8.0.1/24
ListenPort = ${var.wireguard_port}
PrivateKey = $SERVER_PRIVATE_KEY

# PostUp rules
PostUp = iptables -A FORWARD -i %i -j ACCEPT
PostUp = iptables -A FORWARD -o %i -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -s ${var.wireguard_network} -o $(ip route | grep default | awk '{print $5}') -j MASQUERADE

# PostDown rules
PostDown = iptables -D FORWARD -i %i -j ACCEPT
PostDown = iptables -D FORWARD -o %i -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -s ${var.wireguard_network} -o $(ip route | grep default | awk '{print $5}') -j MASQUERADE
EOFWG

# Start WireGuard
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0
echo "WireGuard setup completed"

# Create health check script
cat > /usr/local/bin/wireguard-health-check.sh << 'EOFHC'
#!/bin/bash
# Simple health check for WireGuard

# Check if WireGuard interface is up
if ! ip a show wg0 up > /dev/null 2>&1; then
    echo "WireGuard interface not up, restarting..."
    systemctl restart wg-quick@wg0
    exit 1
fi

# Check if WireGuard is working
if ! wg show wg0 > /dev/null 2>&1; then
    echo "WireGuard not responding, restarting..."
    systemctl restart wg-quick@wg0
    exit 1
fi

echo "WireGuard is running normally"
exit 0
EOFHC

chmod +x /usr/local/bin/wireguard-health-check.sh

# Set up cron job for health check
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/wireguard-health-check.sh > /dev/null 2>&1") | crontab -

echo "VPN server setup completed successfully - $(date)"
EOF

  user_data_with_efs = <<-EOF
#!/bin/bash
# Initial server setup for VPN server in Auto Scaling Group with EFS

set -e

# Log setup progress
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "Starting VPN server setup script - $(date)"

# Update and install required packages
apt-get update
apt-get upgrade -y
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common \
    fail2ban \
    jq \
    unzip \
    wireguard \
    wireguard-tools \
    nfs-common \
    qrencode \
    amazon-efs-utils

# Set up hostname with instance ID for better identification
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
hostnamectl set-hostname ${var.instance_name}-$INSTANCE_ID

# Configure fail2ban
cat > /etc/fail2ban/jail.local << EOFAIL2BAN
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
EOFAIL2BAN

# Restart fail2ban
systemctl restart fail2ban
echo "Fail2ban configured and restarted"

# Enable IP forwarding for WireGuard
echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-wireguard.conf
sysctl -p /etc/sysctl.d/99-wireguard.conf

# Setup shared storage with EFS
echo "Setting up shared storage with EFS ID: ${var.efs_id}"
mkdir -p /mnt/efs

# Mount EFS
echo "${var.efs_id}:/ /mnt/efs efs _netdev,tls,iam 0 0" >> /etc/fstab
mount -a || echo "Error mounting EFS - will try again"

# Try again with a little delay if first mount fails
if [ ! -d "/mnt/efs" ] || ! mountpoint -q /mnt/efs; then
  sleep 10
  mount -a
fi

# Create WireGuard directory in EFS if it doesn't exist
mkdir -p /mnt/efs/wireguard
mkdir -p /mnt/efs/wireguard/clients

# Symlink WireGuard directory to EFS mount
ln -sf /mnt/efs/wireguard /etc/wireguard
chmod 700 /etc/wireguard

# Check if keys exist, create if they don't
if [ ! -f "/etc/wireguard/server_private_key" ]; then
  wg genkey | tee /etc/wireguard/server_private_key | wg pubkey > /etc/wireguard/server_public_key
  chmod 600 /etc/wireguard/server_private_key
  chmod 644 /etc/wireguard/server_public_key
  
  # Create initial WireGuard config
  SERVER_PRIVATE_KEY=$(cat /etc/wireguard/server_private_key)
  cat > /etc/wireguard/wg0.conf << EOFWG
# WireGuard Server Configuration
[Interface]
Address = 10.8.0.1/24
ListenPort = ${var.wireguard_port}
PrivateKey = $SERVER_PRIVATE_KEY

# PostUp rules
PostUp = iptables -A FORWARD -i %i -j ACCEPT
PostUp = iptables -A FORWARD -o %i -j ACCEPT
PostUp = iptables -t nat -A POSTROUTING -s ${var.wireguard_network} -o $(ip route | grep default | awk '{print $5}') -j MASQUERADE

# PostDown rules
PostDown = iptables -D FORWARD -i %i -j ACCEPT
PostDown = iptables -D FORWARD -o %i -j ACCEPT
PostDown = iptables -t nat -D POSTROUTING -s ${var.wireguard_network} -o $(ip route | grep default | awk '{print $5}') -j MASQUERADE
EOFWG
fi

# Start WireGuard
systemctl enable wg-quick@wg0
systemctl start wg-quick@wg0
echo "WireGuard setup completed"

# Create health check script
cat > /usr/local/bin/wireguard-health-check.sh << 'EOFHC'
#!/bin/bash
# Simple health check for WireGuard

# Check if EFS is mounted
if ! mountpoint -q /mnt/efs; then
    echo "EFS not mounted, attempting to mount..."
    mount -a
fi

# Check if WireGuard interface is up
if ! ip a show wg0 up > /dev/null 2>&1; then
    echo "WireGuard interface not up, restarting..."
    systemctl restart wg-quick@wg0
    exit 1
fi

# Check if WireGuard is working
if ! wg show wg0 > /dev/null 2>&1; then
    echo "WireGuard not responding, restarting..."
    systemctl restart wg-quick@wg0
    exit 1
fi

echo "WireGuard is running normally"
exit 0
EOFHC

chmod +x /usr/local/bin/wireguard-health-check.sh

# Set up cron job for health check
(crontab -l 2>/dev/null; echo "*/5 * * * * /usr/local/bin/wireguard-health-check.sh > /dev/null 2>&1") | crontab -

echo "VPN server setup completed successfully - $(date)"
EOF

  # Choose user data based on enable_shared_storage flag
  user_data = var.enable_shared_storage ? local.user_data_with_efs : local.user_data_no_efs
}

# Launch Template
resource "aws_launch_template" "vpn_server" {
  name          = "${var.instance_name}-${var.environment}-${random_string.suffix.result}"
  image_id      = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  user_data     = var.user_data_base64 != null ? var.user_data_base64 : base64encode(local.user_data)
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