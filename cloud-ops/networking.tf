# ---------------------------------------------------------------------------------------------------------------------
# 1. NETWORKING
# ---------------------------------------------------------------------------------------------------------------------

locals {
  vpc_name = "main"
  vpc_cidr = "10.0.0.0/16"

  login_subnet_cidr   = "10.0.0.0/24"
  compute_subnet_cidr = "10.0.64.0/18"
}

resource "aws_vpc" "main" {
  cidr_block = local.vpc_cidr

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = local.vpc_name
  })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.vpc_name}-igw"
  })
}

resource "aws_subnet" "login" {
  vpc_id = aws_vpc.main.id

  cidr_block        = local.login_subnet_cidr
  availability_zone = var.availability_zone

  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${local.vpc_name}-login"
  })
}

resource "aws_subnet" "compute" {
  vpc_id = aws_vpc.main.id

  cidr_block        = local.compute_subnet_cidr
  availability_zone = var.availability_zone

  tags = merge(local.common_tags, {
    Name = "${local.vpc_name}-compute"
  })
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${local.vpc_name}-nat"
  })
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.login.id

  tags = merge(local.common_tags, {
    Name = "${local.vpc_name}-nat"
  })

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "login" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.vpc_name}-login"
  })
}

resource "aws_route_table" "compute" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = merge(local.common_tags, {
    Name = "${local.vpc_name}-compute"
  })
}

resource "aws_route_table_association" "login" {
  subnet_id      = aws_subnet.login.id
  route_table_id = aws_route_table.login.id
}

resource "aws_route_table_association" "compute" {
  subnet_id      = aws_subnet.compute.id
  route_table_id = aws_route_table.compute.id
}
