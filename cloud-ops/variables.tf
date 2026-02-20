variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "availability_zone" {
  type        = string
  description = "AWS availability zone"
  default     = "us-east-1a"
}

variable "ssh_public_key_path" {
  type        = string
  description = "Path to SSH public key for the deployer key pair"
  default     = "~/.ssh/id_ed25519.pub"
}

variable "environment" {
  type        = string
  description = "Environment name (e.g. dev, staging, prod)"
  default     = "dev"
}

# ---------------------------------------------------------------------------------------------------------------------
# Database Variables
# ---------------------------------------------------------------------------------------------------------------------

variable "db_instance_class" {
  type        = string
  description = "RDS instance class for the SLURM accounting database"
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  type        = number
  description = "Initial allocated storage in GB for the accounting database"
  default     = 20
}

variable "db_max_allocated_storage" {
  type        = number
  description = "Maximum storage in GB for autoscaling"
  default     = 100
}

variable "db_admin_username" {
  type        = string
  description = "Master username for the accounting database"
  default     = "slurm_admin"
}

variable "db_admin_password" {
  type        = string
  description = "Master password for the accounting database"
  sensitive   = true
}
