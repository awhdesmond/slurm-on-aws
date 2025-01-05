locals {
  vpc_name = "main"
  vpc_cidr = "10.0.0.0/16"

  login_subnet_cidr = "10.0.128.0/18"
  compute_subnet_cidr = "10.0.192.0/18"

  cluster_subnet_az = "us-east-1a"

  num_login_nodes = 1
  num_controller_nodes = 1
  num_compute_nodes = 3
  num_filesystem_nodes = 1
}
