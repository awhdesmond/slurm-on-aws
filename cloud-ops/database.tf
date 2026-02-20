# ---------------------------------------------------------------------------------------------------------------------
# SLURM Accounting Database
# ---------------------------------------------------------------------------------------------------------------------

module "database" {
  source = "./modules/database"

  vpc_id   = aws_vpc.main.id
  vpc_cidr = local.vpc_cidr
  vpc_name = local.vpc_name

  primary_az         = var.availability_zone
  secondary_az       = "us-east-1b"
  db_subnet_cidr_az1 = "10.0.128.0/24"
  db_subnet_cidr_az2 = "10.0.129.0/24"

  compute_security_group_id = aws_security_group.compute_all_to_all.id

  instance_class        = var.db_instance_class
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  admin_username        = var.db_admin_username
  admin_password        = var.db_admin_password

  environment = var.environment
  common_tags = local.common_tags
}
