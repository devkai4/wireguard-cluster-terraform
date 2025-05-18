# VPN Server Cluster

A production-ready, highly available VPN server cluster built with modern DevSecOps practices. This project demonstrates enterprise-level infrastructure design with a focus on security, scalability, and automation.

## 🌟 Features

- **Multi-AZ Deployment**: Highly available VPN infrastructure across multiple AWS availability zones
- **Auto-Scaling**: Dynamic scaling based on connection load and network traffic
- **Infrastructure as Code**: Complete infrastructure managed with Terraform
- **Configuration Management**: Automated server configuration with Ansible
- **Comprehensive Monitoring**: Real-time metrics with Prometheus and Grafana
- **Security-First Design**: Automated patching, key rotation, and network segmentation
- **CI/CD Pipeline**: Automated testing and deployment with GitHub Actions

## 🏗️ Architecture

The VPN cluster consists of:
- WireGuard VPN servers in Auto Scaling Groups across multiple Availability Zones
- Network Load Balancer for UDP traffic distribution
- Shared EFS storage for WireGuard configuration
- Prometheus + Grafana for monitoring
- Automated backup and disaster recovery
- Zero-trust security model implementation

![VPN Cluster Architecture](docs/images/architecture.png)

## 📋 Prerequisites

- AWS Account with appropriate permissions
- Terraform >= 1.0
- Ansible >= 2.9
- Docker >= 20.10
- AWS CLI configured
- Git

## 🚀 Quick Start

1. **Clone the repository**
   ```bash
   git clone https://github.com/devkai4/vpn-cluster-project.git
   cd vpn-cluster-project
   ```

2. **Initialize Terraform backend**
   ```bash
   cd terraform/backend
   terraform init
   terraform apply
   cd ..
   ./scripts/setup-backend.sh
   ```

3. **Initialize and deploy the dev environment**
   ```bash
   cd environments/dev
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   terraform init
   terraform plan
   terraform apply
   ```

4. **Update Ansible inventory**
   ```bash
   cd ../../..
   ./scripts/update-inventory.sh dev
   ```

5. **Configure VPN servers**
   ```bash
   ansible-playbook -i ansible/inventory/dev ansible/playbooks/setup-wireguard.yml
   ```

6. **Generate client configuration**
   ```bash
   # SSH into one of the VPN servers or use AWS Systems Manager Session Manager
   ssh -i ~/.ssh/your-key.pem ubuntu@<vpn-server-ip>
   
   # Generate client configuration
   sudo /usr/local/bin/gen-client-config.sh my-device 10.8.0.10/24
   
   # Display the client configuration with QR code
   sudo cat /etc/wireguard/clients/my-device.conf
   sudo cat /etc/wireguard/clients/my-device.qrcode.txt
   ```

## 📁 Project Structure

```
vpn-cluster-project/
├── terraform/           # Infrastructure as Code
│   ├── backend/         # S3 backend for Terraform state
│   ├── environments/    # Environment-specific configurations
│   │   ├── dev/
│   │   ├── staging/
│   │   └── prod/
│   └── modules/         # Reusable Terraform modules
│       ├── vpc/         # VPC and networking
│       ├── asg/         # Auto Scaling Group for VPN servers
│       ├── nlb/         # Network Load Balancer
│       └── efs/         # Shared storage for configuration
├── ansible/             # Configuration Management
│   ├── playbooks/       # Ansible playbooks
│   ├── roles/           # Ansible roles
│   │   └── wireguard/   # WireGuard installation and configuration
│   └── inventory/       # Inventory for environments
├── scripts/             # Utility scripts
│   ├── deploy.sh        # Deployment script
│   ├── backup.sh        # Backup script
│   └── health-check.sh  # Health check script
├── docs/                # Documentation
│   ├── architecture.md  # Architecture documentation
│   ├── deployment.md    # Deployment guide
│   └── troubleshooting.md # Troubleshooting guide
└── .github/             # GitHub Actions workflows
```

## 🔧 Configuration

### Environment Variables

```bash
export AWS_REGION=ap-northeast-1
export AWS_PROFILE=vpn-project
export ENVIRONMENT=dev
```

### Terraform Variables

Key variables to configure:
- `vpc_cidr`: VPC CIDR block
- `instance_type`: EC2 instance type
- `asg_min_size`, `asg_max_size`, `asg_desired_capacity`: Auto Scaling Group settings
- `wireguard_port`: UDP port for WireGuard (default: 51820)
- `wireguard_network`: Internal network CIDR for WireGuard (default: 10.8.0.0/24)
- `enable_shared_storage`: Enable shared EFS storage for WireGuard configuration

## 📊 Monitoring

Access monitoring dashboards:
- Prometheus: `http://monitoring.yourdomain.com:9090`
- Grafana: `http://monitoring.yourdomain.com:3000`

Key metrics monitored:
- Active VPN connections
- Bandwidth usage
- Server health
- Security events
- Auto Scaling Group activities

## 🔒 Security

This project implements multiple security layers:
- Network segmentation with VPC
- Security groups and NACLs
- Automated security patching
- Key rotation mechanism
- WAF protection
- Encryption at rest and in transit
- Instance metadata security

## 🧪 Testing

Run infrastructure tests:
```bash
cd terraform/environments/dev
terraform validate
terraform plan
```

Run Ansible playbook checks:
```bash
ansible-playbook ansible/playbooks/setup-wireguard.yml --check
```

## 📈 Scaling

The infrastructure automatically scales based on:
- CPU utilization
- Network throughput
- Active connections

Manual scaling:
```bash
# Scale up
aws autoscaling set-desired-capacity --auto-scaling-group-name vpn-cluster-dev-vpn-server-asg --desired-capacity 5

# Scale down
aws autoscaling set-desired-capacity --auto-scaling-group-name vpn-cluster-dev-vpn-server-asg --desired-capacity 2
```

## 🔄 CI/CD

GitHub Actions workflows:
- `terraform-validate.yml`: Validates Terraform configurations
- `ansible-lint.yml`: Lints Ansible playbooks
- `deploy.yml`: Automated deployment pipeline

## 📝 Documentation

- [Architecture Overview](docs/architecture.md)
- [Deployment Guide](docs/deployment.md)
- [Troubleshooting Guide](docs/troubleshooting.md)

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please see [CONTRIBUTING.md](CONTRIBUTING.md) for more details.

## 📃 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👤 Author

**Zhengkai Wang**

- LinkedIn: [Zhengkai Wang](https://jp.linkedin.com/in/zhengkai-wang-433564270)
- GitHub: [@devkai4](https://github.com/devkai4)