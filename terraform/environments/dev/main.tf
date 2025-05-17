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

  # Tags
  environment = var.environment
  project     = var.project
  owner       = var.owner
}

# Use EC2 Module for VPN Server
module "vpn_server" {
  source = "../../modules/ec2"
  
  # Only create in dev environment for testing
  count = var.environment == "dev" ? 1 : 0
  
  # EC2 Configuration
  instance_name       = "${var.project}-${var.environment}-vpn-server"
  ami_id              = var.vpn_server_ami_id
  instance_type       = var.vpn_server_instance_type
  key_name            = var.ssh_key_name
  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.public_subnet_ids
  security_group_ids  = [module.vpc.vpn_server_security_group_id]
  associate_public_ip = true
  root_volume_size    = 20
  enable_monitoring   = true
  
  # IAM Role Configuration
  create_iam_role          = true
  enable_ssm_session_manager = true
  iam_policies             = [
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  ]
  
  # User Data Configuration
  user_data_vars = {
    hostname                = "${var.project}-${var.environment}-vpn-server"
    install_cloudwatch_agent = "true"
    install_node_exporter   = "true"
    install_wireguard       = "true" 
    log_group_name          = "/vpn-cluster/${var.environment}/vpn-server"
    additional_user_data    = ""
  }
  
  # Tags
  environment = var.environment
  project     = var.project
  owner       = var.owner
  tags        = {
    Service     = "VPN"
    Application = "WireGuard"
  }
}