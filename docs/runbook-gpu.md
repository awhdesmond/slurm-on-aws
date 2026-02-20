# NVIDIA GPU Runbook

Operational reference for GPU compute nodes (`gpu-compute0`, `gpu-compute1`) running p4d.24xlarge with 8× A100 40GB GPUs.

## Component Stack

| Component | Purpose |
|---|---|
| NVIDIA Driver + CUDA | GPU compute and kernel execution |
| Fabric Manager | NVSwitch inter-GPU communication |
| Persistence Daemon | Keeps driver loaded between jobs |
| AWS EFA | 400 Gbps network for multi-node training |
| NCCL + aws-ofi-nccl | Collective operations over EFA |
| DCGM | GPU health monitoring and telemetry |

## Quick Health Check

```bash
# GPU status overview
nvidia-smi

# Detailed per-GPU query
nvidia-smi --query-gpu=index,name,temperature.gpu,utilization.gpu,memory.used,memory.total,ecc.errors.uncorrected.aggregate.total,power.draw --format=csv

# EFA status
/opt/amazon/efa/bin/fi_info -p efa

# DCGM health check
dcgmi health -c -j

# Fabric Manager status
systemctl status nvidia-fabricmanager

# NVLink status
nvidia-smi nvlink -s
nvidia-smi nvlink -c
```

## GPU Configuration Reference

| Setting | Value | Command to verify |
|---|---|---|
| Compute mode | EXCLUSIVE_PROCESS | `nvidia-smi -q \| grep "Compute Mode"` |
| Persistence mode | Enabled | `nvidia-smi -q \| grep "Persistence Mode"` |
| Graphics clock | Locked 1410 MHz | `nvidia-smi -q \| grep "Graphics"` |
| Power limit | 400W (TDP) | `nvidia-smi -q \| grep "Power Limit"` |
| Auto-boost | Disabled | `nvidia-smi -q \| grep "Auto Boost"` |
| ECC | Enabled | `nvidia-smi -q \| grep "ECC"` |

## NCCL Testing

```bash
# Single-node 8-GPU all-reduce benchmark
bash scripts/nccl-test.sh 8

# Multi-node via Slurm (2 nodes, 16 GPUs)
srun -N 2 --ntasks-per-node=8 --gpus-per-node=8 \
  /usr/bin/all_reduce_perf -b 8 -e 2G -f 2 -g 1 -c 1 -n 100
```

### Expected Bandwidth

| Test | Intra-node (NVSwitch) | Inter-node (EFA) |
|---|---|---|
| all_reduce 256 MB | ~550 GB/s | ~11 GB/s |
| all_reduce 1 GB | ~580 GB/s | ~12 GB/s |

## Common Issues

### nvidia-smi hangs or fails

```bash
# Check if driver modules are loaded
lsmod | grep nvidia

# Check for XID errors in kernel log
dmesg | grep -i "NVRM: Xid"

# Check Fabric Manager (required for NVSwitch)
systemctl status nvidia-fabricmanager
journalctl -u nvidia-fabricmanager --since "1 hour ago"

# If driver crashed, reset GPU
nvidia-smi -r
```

### EFA not working

```bash
# Verify EFA kernel module
lsmod | grep efa

# Check EFA device
/opt/amazon/efa/bin/fi_info -p efa -t FI_EP_RDM

# Verify security group allows all EFA traffic (protocol -1)
# Check Terraform: aws_security_group.efa

# Verify NCCL env is loaded
env | grep -E "(NCCL|FI_)"
```

### GPU throttling / inconsistent performance

```bash
# Check current clocks (should be locked)
nvidia-smi --query-gpu=clocks.gr,clocks.mem,clocks.max.gr,clocks.max.mem --format=csv

# Check thermal throttling
nvidia-smi --query-gpu=temperature.gpu,power.draw,clocks_throttle_reasons.active --format=csv

# Re-apply clock lock if needed
sudo nvidia-smi -lgc 1410
sudo nvidia-smi -pl 400
```

### ECC errors

```bash
# Check aggregate ECC errors
nvidia-smi --query-gpu=ecc.errors.corrected.aggregate.total,ecc.errors.uncorrected.aggregate.total --format=csv

# Check row remapping status
nvidia-smi --query-gpu=remapped_rows.pending,remapped_rows.failure,remapped_rows.correctable,remapped_rows.uncorrectable --format=csv

# If pending remaps exist, drain node and reboot
sudo scontrol update NodeName=$(hostname) State=DRAIN Reason="GPU row remap pending"
sudo reboot
```

## DCGM Monitoring

```bash
# GPU discovery
dcgmi discovery -l

# Run diagnostics (Level 3 = full)
dcgmi diag -r 3

# Start field group watching (temperature, power, utilisation)
dcgmi dmon -e 150,155,203,204,230,252
# Fields: GPU temp, memory temp, GPU util, memory util, power, ECC errors

# Health monitoring
dcgmi health -c    # Check health
dcgmi health -j    # JSON output (for automation)
```

## Service Management

```bash
# Restart all NVIDIA services
sudo systemctl restart nvidia-persistenced
sudo systemctl restart nvidia-fabricmanager
sudo systemctl restart nvidia-dcgm

# Check all services
for svc in nvidia-persistenced nvidia-fabricmanager nvidia-dcgm; do
  echo "--- $svc ---"
  systemctl is-active $svc
done
```
