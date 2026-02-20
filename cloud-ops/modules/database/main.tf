# ---------------------------------------------------------------------------------------------------------------------
# Database Subnets (RDS requires at least 2 AZs)
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_subnet" "db_az1" {
  vpc_id = var.vpc_id

  cidr_block        = var.db_subnet_cidr_az1
  availability_zone = var.primary_az

  tags = merge(var.common_tags, {
    Name = "${var.vpc_name}-db-az1"
  })
}

resource "aws_subnet" "db_az2" {
  vpc_id = var.vpc_id

  cidr_block        = var.db_subnet_cidr_az2
  availability_zone = var.secondary_az

  tags = merge(var.common_tags, {
    Name = "${var.vpc_name}-db-az2"
  })
}

resource "aws_db_subnet_group" "slurm" {
  name       = "slurm-db"
  subnet_ids = [aws_subnet.db_az1.id, aws_subnet.db_az2.id]

  tags = merge(var.common_tags, {
    Name = "slurm-db"
  })
}

# ---------------------------------------------------------------------------------------------------------------------
# Database Security Group
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_security_group" "slurm_db" {
  name        = "slurm-db"
  description = "Allow MySQL access from compute nodes (slurmdbd)"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "slurm-db"
  })
}

resource "aws_vpc_security_group_ingress_rule" "slurm_db_mysql" {
  security_group_id            = aws_security_group.slurm_db.id
  referenced_security_group_id = var.compute_security_group_id

  ip_protocol = "tcp"
  from_port   = 3306
  to_port     = 3306
}

# ---------------------------------------------------------------------------------------------------------------------
# RDS MySQL Instance
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_db_instance" "slurm_accounting" {
  identifier     = "slurm-accounting"
  engine         = "mysql"
  engine_version = "8.0"

  instance_class        = var.instance_class
  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = "slurm_acct_db"
  username = var.admin_username
  password = var.admin_password

  db_subnet_group_name   = aws_db_subnet_group.slurm.name
  vpc_security_group_ids = [aws_security_group.slurm_db.id]

  multi_az            = false
  publicly_accessible = false
  skip_final_snapshot = var.environment == "dev" ? true : false

  final_snapshot_identifier = var.environment != "dev" ? "slurm-accounting-final" : null

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  deletion_protection = var.environment != "dev"

  tags = merge(var.common_tags, {
    Name = "slurm-accounting"
  })

  lifecycle {
    prevent_destroy = true
  }
}
