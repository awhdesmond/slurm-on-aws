# NFS Nodes

resource "aws_network_interface" "nfs" {
  count = local.num_nfs_nodes

  subnet_id = aws_subnet.compute.id
  private_ips = [
    cidrhost(local.compute_subnet_cidr, (-count.index - 4))
  ]

  security_groups = [ aws_security_group.compute_all_to_all.id ]

  tags = {
    Name = "nfs${count.index}"
  }
}

resource "aws_instance" "nfs" {
  count = local.num_nfs_nodes

  ami = data.aws_ami.ubuntu.id
  instance_type = "t2.small"
  availability_zone = local.cluster_subnet_az

  key_name = aws_key_pair.deployer.key_name

  network_interface {
    network_interface_id = aws_network_interface.nfs[count.index].id
    device_index = 0
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

# Filesystem nodes

resource "aws_ebs_volume" "filesystem" {
  count = local.num_filesystem_nodes

  availability_zone = local.cluster_subnet_az
  size              = 20
  type = "gp2"

  tags = {
    Name = "filesystem${count.index}"
  }
}

resource "aws_volume_attachment" "filesystem_attach" {
  count = local.num_filesystem_nodes
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