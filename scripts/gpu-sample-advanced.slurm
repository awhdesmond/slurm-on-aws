#!/bin/bash
#SBATCH --job-name=gpu-advanced-demo
#SBATCH --partition=gpu
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=4
#SBATCH --gpus-per-task=1          # Ensure 1 GPU allocated per task
#SBATCH --cpus-per-task=8          # Allocate CPUs per task for dataloading
#SBATCH --time=01:00:00
#SBATCH --output=/shared_gluster/%x/stdout.%j
#SBATCH --error=/shared_gluster/%x/stderr.%j
#SBATCH --exclusive                # Often useful for multi-node jobs

# Ensure output directory exists (using job name macro %x)
mkdir -p "/shared_gluster/$SLURM_JOB_NAME"

echo "=========================================="
echo "Job started on $(date)"
echo "Running on nodes: $SLURM_JOB_NODELIST"
echo "Allocated nodes: $SLURM_JOB_NUM_NODES"
echo "Allocated tasks: $SLURM_NTASKS"
echo "=========================================="

# 1. Load any necessary modules
# (Uncomment and adjust based on your cluster's module system)
# module load python/3.10 cuda/12.1

# 2. Ensure a Python environment exists and is activated
# We put this on a shared filesystem so all nodes see exactly the same env
VENV_PATH="/shared_gluster/venv-pytorch"
if [ ! -d "$VENV_PATH" ]; then
    echo "Creating virtual environment at $VENV_PATH..."
    python3 -m venv "$VENV_PATH"
fi
source "$VENV_PATH/bin/activate"

# 3. Install required packages 
# (It is recommended to run this outside of the SLURM job, but included here for completeness)
pip install -q torch

# 4. Set PyTorch Distributed Data Parallel (DDP) Environment Variables
export MASTER_PORT=29500
# Get the first node in the list of allocated nodes
export MASTER_ADDR=$(scontrol show hostnames $SLURM_JOB_NODELIST | head -n 1)

# NCCL configuration for multi-node on AWS
export NCCL_DEBUG=INFO
# If using EFA (Elastic Fabric Adapter) on AWS:
# export FI_PROVIDER=efa
# export FI_EFA_USE_DEVICE_RDMA=1

echo "PyTorch distributed master node is: $MASTER_ADDR"

# 5. Create a simple multi-node PyTorch script if it doesn't exist
DUMMY_SCRIPT="/shared_gluster/$SLURM_JOB_NAME/train.py"
cat << 'EOF' > $DUMMY_SCRIPT
import os
import socket
import torch
import torch.distributed as dist

def main():
    # SLURM typically doesn't automatically set LOCAL_RANK for srun like torchrun does,
    # so we will pass it explicitly in the srun command
    rank = int(os.environ["RANK"])
    world_size = int(os.environ["WORLD_SIZE"])
    local_rank = int(os.environ["LOCAL_RANK"])
    
    # Initialize the process group using NCCL backend
    dist.init_process_group("nccl", rank=rank, world_size=world_size)
    
    # Bind process to a specific GPU
    torch.cuda.set_device(local_rank)
    device = torch.device(f"cuda:{local_rank}")

    hostname = socket.gethostname()
    gpu_name = torch.cuda.get_device_name(device)
    
    print(f"[{hostname}] Rank {rank}/{world_size} (Local {local_rank}) using GPU: {gpu_name}")

    # Synchronize all processes before completing
    dist.barrier()
    
    # Clean up
    dist.destroy_process_group()

if __name__ == "__main__":
    main()
EOF

# 6. Execute the workload via MPI/Slurm Integration
# We map Slurm variables to PyTorch DDP variables
echo "Starting multi-node PyTorch job with srun..."
srun bash -c '
    export LOCAL_RANK=$SLURM_LOCALID
    export RANK=$SLURM_PROCID
    export WORLD_SIZE=$SLURM_NTASKS
    python /shared_gluster/'$SLURM_JOB_NAME'/train.py
'

echo "=========================================="
echo "Job completed on $(date)"
