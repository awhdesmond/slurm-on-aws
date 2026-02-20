# slurm-on-aws

IaC repository for provisioning a SLURM cluster on AWS EC2 instances.

## Cluster Architecture

| Node Role | Count | Instance Type | Notes |
|---|---|---|---|
| Login | 1 | `t2.small` | Public subnet, SSH access |
| Controller | 2 | `t2.small` | 1 primary + 1 backup, lifecycle-protected |
| CPU Compute | 3 | `t2.small` | Cluster placement group |
| GPU Compute | 2 | `p4d.24xlarge` | 8× A100 GPUs, EFA networking, cluster placement group |
| NFS | 1 | `t2.small` | Shared storage, lifecycle-protected |
| GlusterFS | 3 | `t2.small` | Parallel filesystem with 20 GB EBS each |
| Database | 1 | `db.t3.micro` | RDS MySQL 8.0 for SLURM accounting (module) |

![architecture](docs/slurm-architecture.png)

### Infrastructure Highlights

- **OS**: Ubuntu 24.04 LTS (Noble) on all nodes
- **EBS**: gp3 volumes throughout (better IOPS at lower cost)
- **Networking**: Cluster placement group for compute nodes, EFA-enabled ENIs for GPU nodes (400 Gbps)
- **Security**: IMDSv2 enforced, SSH restricted to login nodes, all-protocol intra-cluster SG
- **Database**: RDS MySQL 8.0 with gp3 encrypted storage, automated backups, and autoscaling
- **Tagging**: Consistent `Project`, `Environment`, `ManagedBy` tags on all resources

## Provision with Terraform

### Prerequisites

1. Install the `aws` CLI
2. Create an AWS user/profile named `terraform` with `AdministratorAccess`
3. Ensure your service quota covers `p4d.24xlarge` instances (On-Demand P Instances)

### Deploy

```bash
cd terraform

# Copy and customise variables
cp terraform.tfvars.example terraform.tfvars

terraform init
terraform plan    # Review the changeset
terraform apply
```

Useful outputs after apply:

```bash
terraform output login_public_ips
terraform output controller_private_ips
terraform output compute_private_ips
terraform output gpu_compute_private_ips
```

## Ansible

Configure the provisioned hosts and install SLURM & filesystem components:

```bash
export LOGIN_NODE_IP=<login-node-ip>

# Update /etc/hosts
ansible-playbook -i inventory.ini play-hostnames.yml

# Install NFS
ansible-playbook -i inventory.ini play-install-nfs.yml

# Install Gluster
ansible-playbook -i inventory.ini play-install-gluster.yml

sudo gluster volume create gv0 replica 3 \
    gluster0:/export/xvdh1/brick \
    gluster1:/export/xvdh1/brick \
    gluster2:/export/xvdh1/brick

sudo gluster volume start gv0
sudo gluster volume status
sudo gluster volume info gv0

# Install NVIDIA drivers
ansible-playbook -i inventory.ini play-install-nvidia-drivers.yml

# Install SLURM
ansible-playbook -i inventory.ini play-install-slurm.yml
```

## Submit a SLURM Job

```bash
# Login to the login node
mkdir -p /shared_gluster/date/
mkdir -p /shared_gluster/gpu-sample/

sbatch scripts/sample.slurm
sbatch scripts/gpu-sample.slurm
```

## TODO

1. Add CloudWatch alarms for GPU nodes.
2. Configure S3 + DynamoDB backend for remote Terraform state.
