#!/bin/bash
#SBATCH --job-name=date
#SBATCH --time=1:00:00
#SBATCH --nodes=2
#SBATCH --ntasks=2
#SBTACH --partition=debug
#SBATCH --output=/shared_gluster/date/stdout.%j
#SBATCH --error=/shared_gluster/date/stderr.%j

date
hostname
