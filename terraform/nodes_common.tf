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
  security_group_id = aws_security_group.compute_all_to_all.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 0
  to_port           = 65535
}

