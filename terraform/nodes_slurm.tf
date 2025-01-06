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


# GPU Nodes

resource "aws_network_interface" "gpu_compute" {
  count = local.num_gpu_nodes

  subnet_id = aws_subnet.compute.id
  private_ips = [
    cidrhost(
      local.compute_subnet_cidr,
      count.index + local.num_controller_nodes + local.num_compute_nodes + 4
    )
  ]

  security_groups = [ aws_security_group.compute_all_to_all.id ]

  tags = {
    Name = "gpu-compute${count.index}"
  }
}

resource "aws_instance" "gpu_compute" {
  count = local.num_gpu_nodes

  ami = data.aws_ami.ubuntu.id
  instance_type = "g5.xlarge"
  availability_zone = local.cluster_subnet_az

  key_name = aws_key_pair.deployer.key_name

  network_interface {
    network_interface_id = aws_network_interface.gpu_compute[count.index].id
    device_index = 0
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

