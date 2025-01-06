# slurm-on-aws

IaC repositoiry for provisioning SLURM cluster on AWS EC2 with NFS.

![architecture](docs/slurm-architecture.png "Title")

## Provision with Terraform

1. Install `aws` CLI
2. Create an AWS user for `terraform` with `AdministratorAccess` permission
3. Run terraform

```bash
terraform init
terraform apply
```

## Ansible

```bash
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

# Install SLURM
ansible-playbook -i inventory.ini play-install-slurm.yml
```

## To Do

- [ ]  Add GPU partition
