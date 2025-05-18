# Shared Storage Module (EFS)

# Create security group for EFS if needed
resource "aws_security_group" "efs" {
  count       = var.create_security_group ? 1 : 0
  name        = "${var.name}-${var.environment}-efs-sg"
  description = "Security group for EFS mount targets"
  vpc_id      = var.vpc_id

  # Allow NFS traffic from specified CIDR blocks
  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = length(var.allowed_cidr_blocks) > 0 ? var.allowed_cidr_blocks : [data.aws_vpc.selected.cidr_block]
    description = "NFS from allowed CIDR blocks"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    {
      Name        = "${var.name}-${var.environment}-efs-sg"
      Environment = var.environment
      Project     = var.project
      Owner       = var.owner
      ManagedBy   = "terraform"
    },
    var.additional_tags
  )
}

# Get VPC data for CIDR block if allowed_cidr_blocks is empty
data "aws_vpc" "selected" {
  id = var.vpc_id
}

# Create EFS file system
resource "aws_efs_file_system" "this" {
  creation_token = "${var.name}-${var.environment}-${random_string.suffix.result}"
  encrypted      = var.encrypted
  kms_key_id     = var.kms_key_id

  performance_mode                = var.performance_mode
  throughput_mode                 = var.throughput_mode
  provisioned_throughput_in_mibps = var.throughput_mode == "provisioned" ? var.provisioned_throughput_in_mibps : null

  lifecycle_policy {
    transition_to_ia = var.lifecycle_policy
  }

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

# Enable automatic backups
resource "aws_efs_backup_policy" "this" {
  file_system_id = aws_efs_file_system.this.id

  backup_policy {
    status = var.backup_policy
  }
}

# Generate a random suffix for uniqueness
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# Create mount targets in each subnet
resource "aws_efs_mount_target" "this" {
  count           = length(var.subnet_ids)
  file_system_id  = aws_efs_file_system.this.id
  subnet_id       = var.subnet_ids[count.index]
  security_groups = concat(
    var.create_security_group ? [aws_security_group.efs[0].id] : [],
    var.security_group_ids
  )
}

# Create access point for WireGuard
resource "aws_efs_access_point" "wireguard" {
  file_system_id = aws_efs_file_system.this.id

  posix_user {
    gid = 0
    uid = 0
  }

  root_directory {
    path = "/wireguard"
    creation_info {
      owner_gid   = 0
      owner_uid   = 0
      permissions = "0700"
    }
  }

  tags = merge(
    {
      Name        = "${var.name}-${var.environment}-wireguard-ap"
      Environment = var.environment
      Project     = var.project
      Owner       = var.owner
      ManagedBy   = "terraform"
    },
    var.additional_tags
  )
}