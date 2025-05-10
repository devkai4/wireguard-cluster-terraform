# VPN Server Cluster

A production-ready, highly available VPN server cluster built with modern DevSecOps practices. This project demonstrates enterprise-level infrastructure design with a focus on security, scalability, and automation.

## 🌟 Features

- **Multi-Region Deployment**: Highly available VPN infrastructure across multiple AWS availability zones
- **Auto-Scaling**: Dynamic scaling based on connection load
- **Infrastructure as Code**: Complete infrastructure managed with Terraform
- **Configuration Management**: Automated server configuration with Ansible
- **Comprehensive Monitoring**: Real-time metrics with Prometheus and Grafana
- **Security-First Design**: Automated patching, key rotation, and network segmentation
- **CI/CD Pipeline**: Automated testing and deployment with GitHub Actions

## 🏗️ Architecture

The VPN cluster consists of:
- WireGuard VPN servers in Auto Scaling Groups
- Network Load Balancer for traffic distribution
- Prometheus + Grafana for monitoring
- Automated backup and disaster recovery
- Zero-trust security model implementation

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
   git clone https://github.com/yourusername/wireguard-cluster-terraform.git
   cd wireguard-cluster-terraform
   ```

2. **Initialize Terraform**
   ```bash
   cd terraform/environments/dev
   terraform init
   ```

3. **Configure variables**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

4. **Deploy infrastructure**
   ```bash
   terraform plan
   terraform apply
   ```

5. **Configure VPN servers**
   ```bash
   cd ../../../ansible
   ansible-playbook -i inventory/dev playbooks/vpn-setup.yml
   ```

## 📁 Project Structure

```
vpn-cluster-project/
├── terraform/           # Infrastructure as Code
├── ansible/            # Configuration Management
├── docker/             # Container configurations
├── scripts/            # Utility scripts
├── monitoring/         # Monitoring configurations
├── docs/               # Documentation
└── .github/            # CI/CD workflows
```

## 🔧 Configuration

### Environment Variables

```bash
export AWS_REGION=us-east-1
export AWS_PROFILE=your-profile
export ENVIRONMENT=dev
```

### Terraform Variables

Key variables to configure:
- `vpc_cidr`: VPC CIDR block
- `instance_type`: EC2 instance type
- `instance_count`: Number of VPN servers
- `key_name`: SSH key pair name

## 📊 Monitoring

Access monitoring dashboards:
- Prometheus: `http://monitoring.yourdomain.com:9090`
- Grafana: `http://monitoring.yourdomain.com:3000`

Key metrics monitored:
- Active VPN connections
- Bandwidth usage
- Server health
- Security events

## 🔒 Security

This project implements multiple security layers:
- Network segmentation with VPC
- Security Groups and NACLs
- Automated security patching
- Key rotation mechanism
- WAF protection
- Encryption at rest and in transit

## 🧪 Testing

Run infrastructure tests:
```bash
cd terraform/environments/dev
terraform validate
terraform plan
```

Run Ansible playbook checks:
```bash
ansible-playbook playbooks/vpn-setup.yml --check
```

## 📈 Scaling

The infrastructure automatically scales based on:
- CPU utilization
- Network throughput
- Active connections

Manual scaling:
```bash
# Scale up
aws autoscaling set-desired-capacity --auto-scaling-group-name vpn-asg --desired-capacity 5

# Scale down
aws autoscaling set-desired-capacity --auto-scaling-group-name vpn-asg --desired-capacity 2
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

## 📃 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👤 Author

**Your Name**

- LinkedIn: [Zhengkai Wang](https://jp.linkedin.com/in/zhengkai-wang-433564270)
- GitHub: [@devkai4](https://github.com/devkai4)

## 🙏 Acknowledgments

- AWS Documentation
- WireGuard Documentation
- Terraform AWS Provider
- Ansible Community
---

Built with ❤️ for the DevSecOps community
