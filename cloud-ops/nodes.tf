locals {
  num_login_nodes      = 1
  num_controller_nodes = 2
  num_compute_nodes    = 3
  num_gpu_nodes        = 2
  num_nfs_nodes        = 1
  num_filesystem_nodes = 3

  # Instance types per node role
  login_instance_type      = "t2.small"
  controller_instance_type = "t2.small"
  compute_instance_type    = "t2.small"
  gpu_instance_type        = "p4d.24xlarge"
  nfs_instance_type        = "t2.small"
  filesystem_instance_type = "t2.small"
}

# ---------------------------------------------------------------------------------------------------------------------
# Nodes AMI
# ---------------------------------------------------------------------------------------------------------------------

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# ---------------------------------------------------------------------------------------------------------------------
# Demo key pair
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_key_pair" "deployer" {
  key_name   = "deployer"
  public_key = file(var.ssh_public_key_path)

  tags = local.common_tags
}

# ---------------------------------------------------------------------------------------------------------------------
# 1. Shared Security Group — Compute All-to-All
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "compute_all_to_all" {
  name        = "compute_all_to_all"
  description = "Allow all compute nodes to communicate with each other"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "compute-all-to-all"
  })
}

resource "aws_vpc_security_group_ingress_rule" "compute_all_to_all_allow_all" {
  security_group_id            = aws_security_group.compute_all_to_all.id
  referenced_security_group_id = aws_security_group.compute_all_to_all.id

  ip_protocol = "-1" # All protocols (TCP, UDP, ICMP) — required for Slurm/MPI
}

resource "aws_vpc_security_group_egress_rule" "compute_all_to_all_allow_all" {
  security_group_id = aws_security_group.compute_all_to_all.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # All protocols
}

# ---------------------------------------------------------------------------------------------------------------------
# 2. Login Nodes
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "login" {
  name        = "login"
  description = "Allow SSH to login nodes"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "login"
  })
}

# NOTE: Restrict cidr_ipv4 to your known IP ranges in production.
resource "aws_vpc_security_group_ingress_rule" "login_all_ssh" {
  security_group_id = aws_security_group.login.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "login_allow_all_egress" {
  security_group_id = aws_security_group.login.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_network_interface" "login" {
  count = local.num_login_nodes

  subnet_id = aws_subnet.login.id
  security_groups = [
    aws_security_group.login.id,
    aws_security_group.compute_all_to_all.id
  ]

  tags = merge(local.common_tags, {
    Name = "login${count.index}"
  })
}

resource "aws_instance" "login" {
  count = local.num_login_nodes

  ami               = data.aws_ami.ubuntu.id
  instance_type     = local.login_instance_type
  availability_zone = var.availability_zone

  network_interface {
    network_interface_id = aws_network_interface.login[count.index].id
    device_index         = 0
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 10
    delete_on_termination = true
  }

  metadata_options {
    http_tokens   = "required" # Enforce IMDSv2
    http_endpoint = "enabled"
  }

  key_name = aws_key_pair.deployer.key_name

  tags = merge(local.common_tags, {
    Name = "login${count.index}"
  })
}

# ---------------------------------------------------------------------------------------------------------------------
# 3. Controller Nodes
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_network_interface" "controller" {
  count = local.num_controller_nodes

  subnet_id = aws_subnet.compute.id
  private_ips = [
    cidrhost(local.compute_subnet_cidr, count.index + 4) # AWS reserves first 4 IPs in subnet
  ]

  security_groups = [aws_security_group.compute_all_to_all.id]

  tags = merge(local.common_tags, {
    Name = "controller${count.index}"
  })
}

resource "aws_instance" "controller" {
  count = local.num_controller_nodes

  ami               = data.aws_ami.ubuntu.id
  instance_type     = local.controller_instance_type
  availability_zone = var.availability_zone

  key_name = aws_key_pair.deployer.key_name

  network_interface {
    network_interface_id = aws_network_interface.controller[count.index].id
    device_index         = 0
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    delete_on_termination = true
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  lifecycle {
    prevent_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = "controller${count.index}"
  })
}

# ---------------------------------------------------------------------------------------------------------------------
# 4. Cluster Placement Group (shared by compute + GPU nodes)
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_placement_group" "compute_cluster" {
  name     = "slurm-compute-cluster"
  strategy = "cluster"

  tags = merge(local.common_tags, {
    Name = "slurm-compute-cluster"
  })
}

# ---------------------------------------------------------------------------------------------------------------------
# 5. CPU Compute Nodes
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_network_interface" "compute" {
  count = local.num_compute_nodes

  subnet_id = aws_subnet.compute.id
  private_ips = [
    cidrhost(local.compute_subnet_cidr, count.index + local.num_controller_nodes + 4)
  ]

  security_groups = [aws_security_group.compute_all_to_all.id]

  tags = merge(local.common_tags, {
    Name = "compute${count.index}"
  })
}

resource "aws_instance" "compute" {
  count = local.num_compute_nodes

  ami               = data.aws_ami.ubuntu.id
  instance_type     = local.compute_instance_type
  availability_zone = var.availability_zone
  placement_group   = aws_placement_group.compute_cluster.id

  key_name = aws_key_pair.deployer.key_name

  network_interface {
    network_interface_id = aws_network_interface.compute[count.index].id
    device_index         = 0
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 10
    delete_on_termination = true
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  tags = merge(local.common_tags, {
    Name = "compute${count.index}"
  })
}

# ---------------------------------------------------------------------------------------------------------------------
# 6. GPU Compute Nodes (with EFA)
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "efa" {
  name        = "efa"
  description = "Allow all traffic for EFA communication between GPU nodes"
  vpc_id      = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "efa"
  })
}

resource "aws_vpc_security_group_ingress_rule" "efa_allow_all" {
  security_group_id            = aws_security_group.efa.id
  referenced_security_group_id = aws_security_group.efa.id
  ip_protocol                  = "-1"
}

resource "aws_vpc_security_group_egress_rule" "efa_allow_all" {
  security_group_id            = aws_security_group.efa.id
  referenced_security_group_id = aws_security_group.efa.id
  ip_protocol                  = "-1"
}

resource "aws_network_interface" "gpu_compute" {
  count = local.num_gpu_nodes

  subnet_id = aws_subnet.compute.id
  private_ips = [
    cidrhost(
      local.compute_subnet_cidr,
      count.index + local.num_controller_nodes + local.num_compute_nodes + 4
    )
  ]

  interface_type = "efa"

  security_groups = [
    aws_security_group.compute_all_to_all.id,
    aws_security_group.efa.id
  ]

  tags = merge(local.common_tags, {
    Name = "gpu-compute${count.index}"
  })
}

resource "aws_instance" "gpu_compute" {
  count = local.num_gpu_nodes

  ami               = data.aws_ami.ubuntu.id
  instance_type     = local.gpu_instance_type
  availability_zone = var.availability_zone
  placement_group   = aws_placement_group.compute_cluster.id

  key_name = aws_key_pair.deployer.key_name

  network_interface {
    network_interface_id = aws_network_interface.gpu_compute[count.index].id
    device_index         = 0
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  tags = merge(local.common_tags, {
    Name = "gpu-compute${count.index}"
  })
}

# ---------------------------------------------------------------------------------------------------------------------
# 7. NFS Nodes
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_network_interface" "nfs" {
  count = local.num_nfs_nodes

  subnet_id = aws_subnet.compute.id
  private_ips = [
    cidrhost(
      local.compute_subnet_cidr,
      count.index + local.num_controller_nodes + local.num_compute_nodes + local.num_gpu_nodes + 4
    )
  ]

  security_groups = [aws_security_group.compute_all_to_all.id]

  tags = merge(local.common_tags, {
    Name = "nfs${count.index}"
  })
}

resource "aws_instance" "nfs" {
  count = local.num_nfs_nodes

  ami               = data.aws_ami.ubuntu.id
  instance_type     = local.nfs_instance_type
  availability_zone = var.availability_zone
  ebs_optimized     = true

  key_name = aws_key_pair.deployer.key_name

  network_interface {
    network_interface_id = aws_network_interface.nfs[count.index].id
    device_index         = 0
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 10
    delete_on_termination = true
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  lifecycle {
    prevent_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = "nfs${count.index}"
  })
}

# ---------------------------------------------------------------------------------------------------------------------
# 8. Parallel Filesystem Nodes
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_ebs_volume" "filesystem" {
  count = local.num_filesystem_nodes

  availability_zone = var.availability_zone
  size              = 20
  type              = "gp3"

  tags = merge(local.common_tags, {
    Name = "filesystem${count.index}"
  })
}

resource "aws_volume_attachment" "filesystem_attach" {
  count       = local.num_filesystem_nodes
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.filesystem[count.index].id

  instance_id = aws_instance.filesystem[count.index].id
}

resource "aws_network_interface" "filesystem" {
  count = local.num_filesystem_nodes

  subnet_id = aws_subnet.compute.id
  private_ips = [
    cidrhost(
      local.compute_subnet_cidr,
      count.index + local.num_controller_nodes + local.num_compute_nodes + local.num_gpu_nodes + local.num_nfs_nodes + 4
    )
  ]

  security_groups = [aws_security_group.compute_all_to_all.id]

  tags = merge(local.common_tags, {
    Name = "filesystem${count.index}"
  })
}

resource "aws_instance" "filesystem" {
  count = local.num_filesystem_nodes

  ami               = data.aws_ami.ubuntu.id
  instance_type     = local.filesystem_instance_type
  availability_zone = var.availability_zone
  ebs_optimized     = true

  key_name = aws_key_pair.deployer.key_name

  network_interface {
    network_interface_id = aws_network_interface.filesystem[count.index].id
    device_index         = 0
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 10
    delete_on_termination = true
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  tags = merge(local.common_tags, {
    Name = "filesystem${count.index}"
  })
}
