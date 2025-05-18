# Dev Environment - Updated for High Availability

provider "aws" {
  region  = var.region
  profile = var.aws_profile
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  # VPC Configuration
  vpc_name             = "${var.project}-${var.environment}-vpc"
  vpc_cidr             = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Availability Zones and Subnets
  availability_zones     = var.availability_zones
  public_subnet_cidrs    = var.public_subnet_cidrs
  private_subnet_cidrs   = var.private_subnet_cidrs
  management_subnet_cidrs = var.management_subnet_cidrs

  # Tags
  environment = var.environment
  project     = var.project
  owner       = var.owner
}

# Shared Storage with EFS (for WireGuard configuration)
module "efs" {
  source = "../../modules/efs"
  count  = var.enable_shared_storage ? 1 : 0

  name        = "${var.project}-wireguard-config"
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.private_subnet_ids

  # Allow access from VPC CIDR
  allowed_cidr_blocks = [var.vpc_cidr]
  
  # Use default security group settings
  create_security_group = true
  
  # Enable encryption and backups
  encrypted      = true
  backup_policy  = "ENABLED"
  
  # Tags
  environment    = var.environment
  project        = var.project
  owner          = var.owner
  additional_tags = {
    Service     = "VPN"
    Application = "WireGuard"
  }
}

# Network Load Balancer for WireGuard Traffic
module "nlb" {
  source = "../../modules/nlb"

  name       = "${var.project}-vpn"
  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnet_ids
  
  # NLB settings
  internal    = false
  enable_cross_zone_load_balancing = true
  
  # WireGuard settings
  wireguard_port = var.wireguard_port
  
  # Health check settings - TCP check on WireGuard port
  health_check_protocol = "TCP"
  health_check_port     = var.wireguard_port
  health_check_interval = 30
  healthy_threshold     = 2
  unhealthy_threshold   = 2
  
  # Tags
  environment    = var.environment
  project        = var.project
  owner          = var.owner
  additional_tags = {
    Service     = "VPN"
    Application = "WireGuard"
  }
}

# Auto Scaling Group for VPN Servers
module "vpn_asg" {
  source = "../../modules/asg"

  # Instance settings
  instance_name    = "${var.project}-vpn-server"
  ami_id           = var.vpn_server_ami_id != "" ? var.vpn_server_ami_id : ""
  instance_type    = var.vpn_server_instance_type
  key_name         = var.ssh_key_name
  vpc_id           = module.vpc.vpc_id
  subnet_ids       = var.environment == "dev" ? module.vpc.public_subnet_ids : module.vpc.private_subnet_ids
  security_group_ids = [module.vpc.vpn_server_security_group_id]
  root_volume_size = 20
  enable_monitoring = true
  
  # ASG settings
  min_size         = var.asg_min_size
  max_size         = var.asg_max_size
  desired_capacity = var.asg_desired_capacity
  
  # Health check settings
  health_check_type = "ELB"
  health_check_grace_period = 300
  target_group_arns = [module.nlb.target_group_arn]
  
  # IAM settings
  create_iam_role = true
  iam_policies    = [
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
  
  # Scaling policies
  enable_cpu_scaling = true
  cpu_high_threshold = 70
  cpu_low_threshold  = 30
  enable_network_scaling = true
  network_in_high_threshold = var.network_in_high_threshold
  network_in_low_threshold  = var.network_in_low_threshold
  
  # Shared storage settings
  enable_shared_storage = var.enable_shared_storage
  efs_id                = var.enable_shared_storage ? module.efs[0].efs_id : ""
  
  # WireGuard settings
  wireguard_port    = var.wireguard_port
  wireguard_network = var.wireguard_network
  
  # User data variables
  user_data_vars = {
    hostname                = "${var.project}-${var.environment}-vpn-server"
    install_cloudwatch_agent = "true"
    install_node_exporter   = "true"
    install_wireguard       = "true" 
    wireguard_port          = tostring(var.wireguard_port)
    wireguard_network       = var.wireguard_network
    enable_shared_storage   = var.enable_shared_storage ? "true" : "false"
    efs_id                  = var.enable_shared_storage ? module.efs[0].efs_id : ""
    log_group_name          = "/vpn-cluster/${var.environment}/vpn-server"
    additional_user_data    = "echo \"${module.nlb.nlb_dns_name}\" > /etc/wireguard/nlb_endpoint"
  }
  
  # Tags
  environment    = var.environment
  project        = var.project
  owner          = var.owner
  additional_tags = {
    Service     = "VPN"
    Application = "WireGuard"
  }
}