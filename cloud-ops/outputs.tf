output "login_public_ips" {
  description = "Public IPs of the login nodes"
  value       = aws_instance.login[*].public_ip
}

output "controller_private_ips" {
  description = "Private IPs of the controller nodes"
  value       = aws_network_interface.controller[*].private_ip
}

output "compute_private_ips" {
  description = "Private IPs of the CPU compute nodes"
  value       = aws_network_interface.compute[*].private_ip
}

output "gpu_compute_private_ips" {
  description = "Private IPs of the GPU compute nodes"
  value       = aws_network_interface.gpu_compute[*].private_ip
}

output "nfs_private_ips" {
  description = "Private IPs of the NFS nodes"
  value       = aws_network_interface.nfs[*].private_ip
}

output "filesystem_private_ips" {
  description = "Private IPs of the parallel filesystem nodes"
  value       = aws_network_interface.filesystem[*].private_ip
}

output "slurm_db_endpoint" {
  description = "RDS endpoint for the SLURM accounting database"
  value       = module.database.endpoint
}

output "slurm_db_name" {
  description = "Database name for the SLURM accounting database"
  value       = module.database.db_name
}
