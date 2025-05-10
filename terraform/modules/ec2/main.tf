# EC2 Module for VPN Servers

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
    var.tags
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
    var.tags
  )
}

# Attach SSM policy to IAM role if enabled
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  count      = var.create_iam_role && var.enable_ssm_session_manager ? 1 : 0
  role       = aws_iam_role.ec2_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Attach additional IAM policies
resource "aws_iam_role_policy_attachment" "additional_policies" {
  count      = var.create_iam_role ? length(var.iam_policies) : 0
  role       = aws_iam_role.ec2_role[0].name
  policy_arn = var.iam_policies[count.index]
}

# User data - using modern templatefile function instead of deprecated template_file data source
locals {
  user_data = templatefile("${path.module}/user_data.tpl", var.user_data_vars)
}

# EC2 Instance
resource "aws_instance" "vpn_server" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = var.security_group_ids
  subnet_id              = var.subnet_ids[0]  # Use the first subnet by default
  iam_instance_profile   = var.create_iam_role ? aws_iam_instance_profile.ec2_profile[0].name : null
  user_data              = local.user_data
  monitoring             = var.enable_monitoring

  associate_public_ip_address = var.associate_public_ip

  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    delete_on_termination = true
    encrypted             = true

    tags = merge(
      {
        Name        = "${var.instance_name}-root-volume"
        Environment = var.environment
        Project     = var.project
        Owner       = var.owner
        ManagedBy   = "terraform"
      },
      var.tags
    )
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  tags = merge(
    {
      Name        = "${var.instance_name}-${var.environment}"
      Environment = var.environment
      Project     = var.project
      Owner       = var.owner
      ManagedBy   = "terraform"
    },
    var.tags
  )

  lifecycle {
    create_before_destroy = true
  }
}