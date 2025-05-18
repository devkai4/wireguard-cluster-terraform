# High Availability VPN Architecture

This document provides an overview of the high availability architecture for the VPN Server Cluster.

## Architecture Overview

The VPN Server Cluster is designed as a highly available, auto-scaling solution deployed across multiple AWS Availability Zones. This architecture ensures reliability, scalability, and resilience against infrastructure failures.

![VPN Cluster Architecture](images/architecture.svg)

## Components

### Network Load Balancer

The Network Load Balancer (NLB) is the entry point for VPN clients and provides:

- UDP protocol support for WireGuard traffic (port 51820)
- Distribution of traffic across multiple VPN servers
- Health checks to detect and route around server failures
- Static endpoint for client configurations
- Cross-zone load balancing for improved availability

### Auto Scaling Group

The Auto Scaling Group (ASG) manages VPN server instances and provides:

- Dynamic scaling based on CPU utilization and network traffic
- Multi-AZ deployment for high availability
- Automated instance replacement if failures occur
- Launch Template defining VPN server configuration
- Health checks to ensure proper functioning

### Shared Storage (EFS)

Amazon Elastic File System (EFS) provides shared storage for VPN configuration:

- Consistent WireGuard configuration across all instances
- Persistent client configurations
- Shared server keys for continuous connection support
- Automatic mounting on instance launch
- High availability with Multi-AZ replication

### VPN Servers

Each VPN server (EC2 instance) includes:

- WireGuard VPN software installation
- Configuration synchronized via shared storage
- Health monitoring agents
- CloudWatch integration for logging and metrics
- Amazon Linux 2 or Ubuntu 22.04 LTS operating system

## Failover Mechanism

The system has automatic failover capabilities:

1. **Instance Failure**: If a VPN server fails, the NLB detects this through health checks and stops sending traffic to the failed instance. The ASG automatically launches a replacement instance.

2. **Availability Zone Failure**: With instances spread across multiple AZs, the system continues to function even if an entire AZ becomes unavailable.

3. **Connection Persistence**: WireGuard clients maintain their connections even during instance replacements due to shared configuration on EFS.

## Scaling Mechanisms

The system scales automatically based on:

- **CPU Utilization**: Adds instances when CPU usage exceeds 70% and removes instances when it drops below 30%
- **Network Traffic**: Scales out when network traffic exceeds 10 MB/s and scales in when it drops below 2 MB/s
- **Manual Adjustment**: Can be manually scaled for anticipated load increases

## Client Handling

Client connections are managed through:

- Static endpoint (NLB DNS name) for all client configurations
- Client public keys stored in shared configuration
- Persistent connection support across instance changes
- Automatic reconnection to available servers

## Security Considerations

The high availability architecture includes:

- Network isolation with VPC and subnets
- Security groups limiting traffic to necessary ports
- IAM roles with least privilege
- Encrypted storage for WireGuard configuration
- Consistent firewall rules across instances
- Multi-factor authentication for administrative access

## Monitoring and Alerting

The system is monitored through:

- CloudWatch metrics for CPU, memory, and network utilization
- Custom CloudWatch dashboards for VPN performance
- Automated health checks on each VPN server
- Prometheus and Grafana for detailed monitoring (upcoming)
- AlertManager for notifications (upcoming)

## Recovery Procedures

In case of failures, recovery procedures include:

1. **Instance Recovery**: Automatic via ASG
2. **Configuration Recovery**: Automatic via shared EFS storage
3. **Manual Recovery**: If needed, run `deploy.sh` script with HA mode
4. **Client Recovery**: Automatic reconnection to available servers

## Deployment Steps

To deploy the high availability architecture:

1. Update `terraform.tfvars` with desired settings
2. Run `./scripts/deploy.sh --environment dev`
3. Generate client configurations on any VPN server
4. Distribute configurations to clients

## Limitations and Considerations

- WireGuard doesn't have built-in clustering support, so we use shared configuration
- Client handover is managed by the NLB and client reconnection
- Initial client connection setup requires access to one server
- User permission changes require updates to all server configurations

## Future Improvements

Planned improvements include:

- Centralized client management interface
- API for client configuration generation
- Enhanced monitoring with Prometheus and Grafana
- Key rotation automation
- Integration with identity providers

## Troubleshooting

Common issues and solutions:

1. **Client Connection Issues**:
   - Ensure NLB endpoint is used in client config
   - Check that client public key is in server configuration
   - Verify network connectivity to NLB
   
2. **Scaling Issues**:
   - Verify CloudWatch alarms are properly configured
   - Check instance launch template settings
   - Ensure IAM roles have proper permissions

3. **EFS Mounting Issues**:
   - Check security group rules allow NFS traffic
   - Verify instance role permissions for EFS
   - Check mount target availability

For more detailed troubleshooting, refer to the [Troubleshooting Guide](troubleshooting.md).