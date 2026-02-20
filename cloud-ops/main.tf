locals {
  # Common tags applied to all resources
  common_tags = {
    Project     = "slurm-cluster"
    ManagedBy   = "terraform"
    Environment = var.environment
  }
}
