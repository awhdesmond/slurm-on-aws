#!/bin/bash
#SBATCH --job-name=gpu-sample
#SBATCH --partition=gpu
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --time=00:00:30
#SBATCH --gres=gpu:1
#SBATCH --output=/shared_gluster/gpu-sample/stdout.%j
#SBATCH --error=/shared_gluster/gpu-sample/stderr.%j

echo "Job running on nodes: $SLURM_JOB_NODELIST"

# Run nvidia-smi
# This should print output from BOTH nodes
srun --label nvidia-smi
