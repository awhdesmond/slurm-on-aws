resource "aws_vpc" "main" {
  cidr_block = local.vpc_cidr

  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = local.vpc_name
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${local.vpc_name}-igw"
  }
}

resource "aws_subnet" "login" {
  vpc_id = aws_vpc.main.id

  cidr_block = local.login_subnet_cidr
  availability_zone = local.cluster_subnet_az

  map_public_ip_on_launch = true

  tags = {
    Name = "${local.vpc_name}-login"
  }
}

resource "aws_subnet" "compute" {
  vpc_id = aws_vpc.main.id

  cidr_block = local.compute_subnet_cidr
  availability_zone = local.cluster_subnet_az

  tags = {
    Name = "${local.vpc_name}-compute"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags = {
    Name = "${local.vpc_name}-nat"
  }
}

resource "aws_nat_gateway" "nat_gw" {
	allocation_id = aws_eip.nat.id
	subnet_id = aws_subnet.login.id

  tags = {
    Name = "${local.vpc_name}-nat"
  }

  # NAT gateway may require internet gateway to be
  # created prior to the association
  depends_on = [aws_internet_gateway.igw]
}

# Route Tables

resource "aws_route_table" "login" {
	vpc_id = aws_vpc.main.id
	route {
		cidr_block = "0.0.0.0/0"
		gateway_id = aws_internet_gateway.igw.id
	}
	tags = {
    Name = "${local.vpc_name}-login"
  }
}

resource "aws_route_table" "compute" {
	vpc_id = aws_vpc.main.id
	route {
		cidr_block = "0.0.0.0/0"
		gateway_id = aws_nat_gateway.nat_gw.id
	}

  tags = {
    Name = "${local.vpc_name}-compute"
  }
}

resource "aws_route_table_association" "login" {
  subnet_id      = aws_subnet.login.id
  route_table_id = aws_route_table.login.id
}

resource "aws_route_table_association" "compute" {
  subnet_id      = aws_subnet.compute.id
  route_table_id = aws_route_table.compute.id
}
