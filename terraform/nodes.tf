# ---------------------------------------------------------------------------------------------------------------------
# Nodes AMI
# ---------------------------------------------------------------------------------------------------------------------

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
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
  public_key = file("~/.ssh/id_ed25519.pub")
}


# ---------------------------------------------------------------------------------------------------------------------
# 1. Login Nodes
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_security_group" "login" {
  name        = "login"
  description = "Allow SSH to login nodes"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_ingress_rule" "login_all_ssh" {
  security_group_id = aws_security_group.login.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_network_interface" "login" {
  count = local.num_login_nodes

  subnet_id = aws_subnet.login.id
  security_groups = [
    aws_security_group.login.id,
    aws_security_group.compute_all_to_all.id
  ]
  tags = {
    Name = "login${count.index}"
  }
}

resource "aws_instance" "login" {
  count = local.num_login_nodes

  ami               = data.aws_ami.ubuntu.id
  instance_type     = "t2.small"
  availability_zone = var.availability_zone

  primary_network_interface {
    network_interface_id = aws_network_interface.login[count.index].id
  }

  root_block_device {
    volume_type           = "gp2"
    volume_size           = "10"
    delete_on_termination = true
  }

  key_name = aws_key_pair.deployer.key_name

  tags = {
    Name = "login${count.index}"
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# 2. Controller Nodes
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_network_interface" "controller" {
  count = local.num_controller_nodes

  subnet_id = aws_subnet.compute.id
  private_ips = [
    cidrhost(local.compute_subnet_cidr, count.index + 4) # AWS reserves first 4 IPs in subnet
  ]

  security_groups = [aws_security_group.compute_all_to_all.id]
  tags = {
    Name = "controller${count.index}"
  }
}

resource "aws_instance" "controller" {
  count = local.num_controller_nodes

  ami               = data.aws_ami.ubuntu.id
  instance_type     = "t2.small"
  availability_zone = var.availability_zone

  key_name = aws_key_pair.deployer.key_name

  primary_network_interface {
    network_interface_id = aws_network_interface.controller[count.index].id
  }

  root_block_device {
    volume_type           = "gp2"
    volume_size           = "8"
    delete_on_termination = true
  }

  tags = {
    Name = "controller${count.index}"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# 3. CPU Compute Nodes
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_security_group" "compute_all_to_all" {
  name        = "compute_all_to_all"
  description = "Allow all compute nodes to communicate with each other"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_ingress_rule" "compute_all_to_all_allow_all" {
  security_group_id            = aws_security_group.compute_all_to_all.id
  referenced_security_group_id = aws_security_group.compute_all_to_all.id

  ip_protocol = "tcp"
  from_port   = 0
  to_port     = 65535
}


resource "aws_vpc_security_group_egress_rule" "compute_all_to_all_allow_all" {
  security_group_id = aws_security_group.compute_all_to_all.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 0
  to_port           = 65535
}



resource "aws_network_interface" "compute" {
  count = local.num_compute_nodes

  subnet_id = aws_subnet.compute.id
  private_ips = [
    cidrhost(local.compute_subnet_cidr, count.index + local.num_controller_nodes + 4)
  ]

  security_groups = [aws_security_group.compute_all_to_all.id]

  tags = {
    Name = "compute${count.index}"
  }
}

resource "aws_instance" "compute" {
  count = local.num_compute_nodes

  ami               = data.aws_ami.ubuntu.id
  instance_type     = "t2.small"
  availability_zone = var.availability_zone

  key_name = aws_key_pair.deployer.key_name

  primary_network_interface {
    network_interface_id = aws_network_interface.compute[count.index].id
  }

  root_block_device {
    volume_type           = "gp2"
    volume_size           = "10"
    delete_on_termination = true
  }

  tags = {
    Name = "compute${count.index}"
  }
}


# ---------------------------------------------------------------------------------------------------------------------
# 4. GPU Compute Nodes
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_network_interface" "gpu_compute" {
  count = local.num_gpu_nodes

  subnet_id = aws_subnet.compute.id
  private_ips = [
    cidrhost(
      local.compute_subnet_cidr,
      count.index + local.num_controller_nodes + local.num_compute_nodes + 4
    )
  ]

  security_groups = [aws_security_group.compute_all_to_all.id]

  tags = {
    Name = "gpu-compute${count.index}"
  }
}

resource "aws_instance" "gpu_compute" {
  count = local.num_gpu_nodes

  ami               = data.aws_ami.ubuntu.id
  instance_type     = "g6.xlarge"
  availability_zone = var.availability_zone

  key_name = aws_key_pair.deployer.key_name

  primary_network_interface {
    network_interface_id = aws_network_interface.gpu_compute[count.index].id
  }

  root_block_device {
    volume_type           = "gp2"
    volume_size           = "20"
    delete_on_termination = true
  }

  tags = {
    Name = "gpu-compute${count.index}"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# 5. NFS nodes
# ---------------------------------------------------------------------------------------------------------------------
resource "aws_network_interface" "nfs" {
  count = local.num_nfs_nodes

  subnet_id = aws_subnet.compute.id
  private_ips = [
    cidrhost(local.compute_subnet_cidr, (-count.index - 4))
  ]

  security_groups = [aws_security_group.compute_all_to_all.id]

  tags = {
    Name = "nfs${count.index}"
  }
}

resource "aws_instance" "nfs" {
  count = local.num_nfs_nodes

  ami               = data.aws_ami.ubuntu.id
  instance_type     = "t2.small"
  availability_zone = var.availability_zone

  key_name = aws_key_pair.deployer.key_name

  primary_network_interface {
    network_interface_id = aws_network_interface.nfs[count.index].id
  }

  root_block_device {
    volume_type           = "gp2"
    volume_size           = "10"
    delete_on_termination = true
  }

  tags = {
    Name = "nfs${count.index}"
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# 5. Parallel Filesystem nodes
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_ebs_volume" "filesystem" {
  count = local.num_filesystem_nodes

  availability_zone = var.availability_zone
  size              = 20
  type              = "gp2"

  tags = {
    Name = "filesystem${count.index}"
  }
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
    cidrhost(local.compute_subnet_cidr, (-count.index - 4 - local.num_nfs_nodes))
  ]

  security_groups = [aws_security_group.compute_all_to_all.id]

  tags = {
    Name = "filesystem${count.index}"
  }
}

resource "aws_instance" "filesystem" {
  count = local.num_filesystem_nodes

  ami               = data.aws_ami.ubuntu.id
  instance_type     = "t2.small"
  availability_zone = var.availability_zone

  key_name = aws_key_pair.deployer.key_name

  primary_network_interface {
    network_interface_id = aws_network_interface.filesystem[count.index].id
  }

  root_block_device {
    volume_type           = "gp2"
    volume_size           = "10"
    delete_on_termination = true
  }

  tags = {
    Name = "filesystem${count.index}"
  }
}
