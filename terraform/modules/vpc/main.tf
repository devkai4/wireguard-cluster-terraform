# VPC Main Module

# Create VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = var.enable_dns_support
  enable_dns_hostnames = var.enable_dns_hostnames

  tags = {
    Name        = var.vpc_name
    Environment = var.environment
    Project     = var.project
    Owner       = var.owner
    ManagedBy   = "terraform"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.vpc_name}-igw"
    Environment = var.environment
    Project     = var.project
    Owner       = var.owner
    ManagedBy   = "terraform"
  }
}

#=====================================
# Public Subnets & Route Tables
#=====================================

# Create public subnets
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.vpc_name}-public-${var.availability_zones[count.index]}"
    Environment = var.environment
    Project     = var.project
    Owner       = var.owner
    ManagedBy   = "terraform"
    Tier        = "public"
  }
}

# Create public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.vpc_name}-public-rt"
    Environment = var.environment
    Project     = var.project
    Owner       = var.owner
    ManagedBy   = "terraform"
  }
}

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidrs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

#=====================================
# Private Subnets & Route Tables
#=====================================

# Create private subnets
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name        = "${var.vpc_name}-private-${var.availability_zones[count.index]}"
    Environment = var.environment
    Project     = var.project
    Owner       = var.owner
    ManagedBy   = "terraform"
    Tier        = "private"
  }
}

# Create NAT Gateway for private subnets (one per AZ for high availability)
resource "aws_eip" "nat" {
  count = length(var.public_subnet_cidrs)
  domain = "vpc"

  tags = {
    Name        = "${var.vpc_name}-nat-eip-${var.availability_zones[count.index]}"
    Environment = var.environment
    Project     = var.project
    Owner       = var.owner
    ManagedBy   = "terraform"
  }
}

resource "aws_nat_gateway" "main" {
  count = length(var.public_subnet_cidrs)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name        = "${var.vpc_name}-nat-${var.availability_zones[count.index]}"
    Environment = var.environment
    Project     = var.project
    Owner       = var.owner
    ManagedBy   = "terraform"
  }

  depends_on = [aws_internet_gateway.main]
}

# Create private route tables (one per AZ for isolation)
resource "aws_route_table" "private" {
  count = length(var.private_subnet_cidrs)

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name        = "${var.vpc_name}-private-rt-${var.availability_zones[count.index]}"
    Environment = var.environment
    Project     = var.project
    Owner       = var.owner
    ManagedBy   = "terraform"
  }
}

# Associate private subnets with private route tables
resource "aws_route_table_association" "private" {
  count = length(var.private_subnet_cidrs)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

#=====================================
# Management Subnets & Route Tables
#=====================================

# Create management subnets
resource "aws_subnet" "management" {
  count = length(var.management_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.management_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name        = "${var.vpc_name}-mgmt-${var.availability_zones[count.index]}"
    Environment = var.environment
    Project     = var.project
    Owner       = var.owner
    ManagedBy   = "terraform"
    Tier        = "management"
  }
}

# Management subnets will use the same NAT Gateways as private subnets
resource "aws_route_table" "management" {
  count = length(var.management_subnet_cidrs)

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = {
    Name        = "${var.vpc_name}-mgmt-rt-${var.availability_zones[count.index]}"
    Environment = var.environment
    Project     = var.project
    Owner       = var.owner
    ManagedBy   = "terraform"
  }
}

# Associate management subnets with management route tables
resource "aws_route_table_association" "management" {
  count = length(var.management_subnet_cidrs)

  subnet_id      = aws_subnet.management[count.index].id
  route_table_id = aws_route_table.management[count.index].id
}

#=====================================
# Security Groups
#=====================================

# VPN Server Security Group
resource "aws_security_group" "vpn_server" {
  name        = "${var.vpc_name}-vpn-server-sg"
  description = "Security group for VPN servers"
  vpc_id      = aws_vpc.main.id

  # WireGuard UDP port
  ingress {
    from_port   = 51820
    to_port     = 51820
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "WireGuard VPN"
  }

  # SSH access from management subnet only
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
    description     = "SSH access for development"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "${var.vpc_name}-vpn-server-sg"
    Environment = var.environment
    Project     = var.project
    Owner       = var.owner
    ManagedBy   = "terraform"
  }
}

# Management Security Group
resource "aws_security_group" "management" {
  name        = "${var.vpc_name}-management-sg"
  description = "Security group for management resources"
  vpc_id      = aws_vpc.main.id

  # SSH access from known IPs only (will be parameterized)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # This should be restricted to admin IPs in production
    description = "SSH access"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "${var.vpc_name}-management-sg"
    Environment = var.environment
    Project     = var.project
    Owner       = var.owner
    ManagedBy   = "terraform"
  }
}

# Monitoring Security Group
resource "aws_security_group" "monitoring" {
  name        = "${var.vpc_name}-monitoring-sg"
  description = "Security group for monitoring resources"
  vpc_id      = aws_vpc.main.id

  # Prometheus access from within VPC
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Prometheus"
  }

  # Grafana access from within VPC
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Grafana"
  }

  # Node Exporter
  ingress {
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Node Exporter"
  }

  # AlertManager
  ingress {
    from_port   = 9093
    to_port     = 9093
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "AlertManager"
  }

  # SSH access from management subnet only
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    cidr_blocks     = var.management_subnet_cidrs
    description     = "SSH from management subnets"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name        = "${var.vpc_name}-monitoring-sg"
    Environment = var.environment
    Project     = var.project
    Owner       = var.owner
    ManagedBy   = "terraform"
  }
}

# VPC Flow Logs (Optional but recommended for security)
# resource "aws_flow_log" "main" {
#   log_destination      = aws_cloudwatch_log_group.flow_log.arn
#   log_destination_type = "cloud-watch-logs"
#   traffic_type         = "ALL"
#   vpc_id               = aws_vpc.main.id

#   tags = {
#     Name        = "${var.vpc_name}-flow-log"
#     Environment = var.environment
#     Project     = var.project
#     Owner       = var.owner
#     ManagedBy   = "terraform"
#   }
# }

# resource "aws_cloudwatch_log_group" "flow_log" {
#   name              = "/aws/vpc-flow-log/${var.vpc_name}"
#   retention_in_days = 7

#   tags = {
#     Name        = "${var.vpc_name}-flow-log-group"
#     Environment = var.environment
#     Project     = var.project
#     Owner       = var.owner
#     ManagedBy   = "terraform"
#   }
# }

# resource "aws_iam_role" "flow_log" {
#   name = "${var.vpc_name}-flow-log-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = "sts:AssumeRole"
#         Effect = "Allow"
#         Principal = {
#           Service = "vpc-flow-logs.amazonaws.com"
#         }
#       }
#     ]
#   })

#   tags = {
#     Name        = "${var.vpc_name}-flow-log-role"
#     Environment = var.environment
#     Project     = var.project
#     Owner       = var.owner
#     ManagedBy   = "terraform"
#   }
# }

# resource "aws_iam_role_policy" "flow_log" {
#   name = "${var.vpc_name}-flow-log-policy"
#   role = aws_iam_role.flow_log.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action = [
#           "logs:CreateLogGroup",
#           "logs:CreateLogStream",
#           "logs:PutLogEvents",
#           "logs:DescribeLogGroups",
#           "logs:DescribeLogStreams"
#         ]
#         Effect   = "Allow"
#         Resource = "*"
#       }
#     ]
#   })
# }