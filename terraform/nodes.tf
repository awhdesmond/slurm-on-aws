data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# Key Pair

resource "aws_key_pair" "deployer" {
  key_name   = "deployer"
  public_key = file("~/.ssh/id_ed25519.pub")
}

# Security Groups
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


resource "aws_security_group" "compute_all_to_all" {
  name        = "compute_all_to_all"
  description = "Allow all nodes to communicate"
  vpc_id      = aws_vpc.main.id
}

resource "aws_vpc_security_group_ingress_rule" "compute_all_to_all_allow_all" {
  security_group_id = aws_security_group.compute_all_to_all.id
  referenced_security_group_id = aws_security_group.compute_all_to_all.id

  ip_protocol       = "tcp"
  from_port         = 0
  to_port           = 65535
}


resource "aws_vpc_security_group_egress_rule" "compute_all_to_all_allow_all" {
  security_group_id = aws_security_group.login.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 0
  to_port           = 65535
}


# Login Node

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

  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.small"
  availability_zone = local.cluster_subnet_az

  network_interface {
    network_interface_id = aws_network_interface.login[count.index].id
    device_index = 0
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


# Controller Nodes

resource "aws_network_interface" "controller" {
  count = local.num_controller_nodes

  subnet_id = aws_subnet.compute.id
  private_ips = [
    cidrhost(local.compute_subnet_cidr, count.index + 4) # AWS reserves first 4 IPs in subnet
  ]

  security_groups = [ aws_security_group.compute_all_to_all.id ]
  tags = {
    Name = "controller${count.index}"
  }
}

resource "aws_instance" "controller" {
  count = local.num_controller_nodes

  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.small"
  availability_zone = local.cluster_subnet_az

  key_name = aws_key_pair.deployer.key_name

  network_interface {
    network_interface_id = aws_network_interface.controller[count.index].id
    device_index = 0
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

# Compute Nodes

resource "aws_network_interface" "compute" {
  count = local.num_compute_nodes

  subnet_id = aws_subnet.compute.id
  private_ips = [
    cidrhost(local.compute_subnet_cidr, count.index + local.num_controller_nodes + 4)
  ]

  security_groups = [ aws_security_group.compute_all_to_all.id ]

  tags = {
    Name = "compute${count.index}"
  }
}

resource "aws_instance" "compute" {
  count = local.num_compute_nodes

  ami = data.aws_ami.ubuntu.id
  instance_type = "t2.small"
  availability_zone = local.cluster_subnet_az

  key_name = aws_key_pair.deployer.key_name

  network_interface {
    network_interface_id = aws_network_interface.compute[count.index].id
    device_index = 0
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

# NFS Nodes

resource "aws_network_interface" "filesystem" {
  count = local.num_filesystem_nodes

  subnet_id = aws_subnet.compute.id
  private_ips = [
    cidrhost(local.compute_subnet_cidr, (-count.index - 4))
  ]

  security_groups = [ aws_security_group.compute_all_to_all.id ]

  tags = {
    Name = "filesystem${count.index}"
  }
}

resource "aws_instance" "filesystem" {
  count = local.num_filesystem_nodes

  ami = data.aws_ami.ubuntu.id
  instance_type = "t2.small"
  availability_zone = local.cluster_subnet_az

  key_name = aws_key_pair.deployer.key_name

  network_interface {
    network_interface_id = aws_network_interface.filesystem[count.index].id
    device_index = 0
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
