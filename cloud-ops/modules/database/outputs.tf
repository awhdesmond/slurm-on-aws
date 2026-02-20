output "endpoint" {
  description = "RDS endpoint for the SLURM accounting database"
  value       = aws_db_instance.slurm_accounting.endpoint
}

output "db_name" {
  description = "Database name for SLURM accounting"
  value       = aws_db_instance.slurm_accounting.db_name
}

output "security_group_id" {
  description = "Security group ID of the database"
  value       = aws_security_group.slurm_db.id
}
