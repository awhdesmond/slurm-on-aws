#!/bin/bash

#SBATCH --job-name=gpu-sample
#SBATCH --partition=gpu
#SBATCH --nodes=2
#SBATCH --time=00:00:30
#SBATCH --gres=gpu:1
#SBATCH --output=/shared_gluster/gpu-sample/stdout.%j
#SBATCH --error=/shared_gluster/gpu-sample/stderr.%j
#SBATCH --ntasks=2


nvidia-smi
