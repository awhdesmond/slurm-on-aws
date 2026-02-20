# ---------------------------------------------------------------------------------------------------------------------
# Module: database — RDS MySQL for SLURM Accounting
# ---------------------------------------------------------------------------------------------------------------------

variable "vpc_id" {
  type        = string
  description = "VPC ID to create database resources in"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block"
}

variable "primary_az" {
  type        = string
  description = "Primary availability zone"
}

variable "secondary_az" {
  type        = string
  description = "Secondary availability zone (required for RDS subnet group)"
}

variable "db_subnet_cidr_az1" {
  type        = string
  description = "CIDR block for the database subnet in AZ1"
}

variable "db_subnet_cidr_az2" {
  type        = string
  description = "CIDR block for the database subnet in AZ2"
}

variable "compute_security_group_id" {
  type        = string
  description = "Security group ID of compute nodes allowed to access the database"
}

variable "instance_class" {
  type        = string
  description = "RDS instance class"
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  type        = number
  description = "Initial allocated storage in GB"
  default     = 20
}

variable "max_allocated_storage" {
  type        = number
  description = "Maximum storage in GB for autoscaling"
  default     = 100
}

variable "admin_username" {
  type        = string
  description = "Master username for the database"
  default     = "slurm_admin"
}

variable "admin_password" {
  type        = string
  description = "Master password for the database"
  sensitive   = true
}

variable "environment" {
  type        = string
  description = "Environment name (dev, staging, prod)"
  default     = "dev"
}

variable "common_tags" {
  type        = map(string)
  description = "Common tags to apply to all resources"
  default     = {}
}

variable "vpc_name" {
  type        = string
  description = "VPC name prefix for resource naming"
  default     = "main"
}
