#!/bin/bash
# -------------------------------------------------------------------
# NCCL All-Reduce Performance Test
# Validates multi-GPU communication over NVSwitch (intra-node)
# and EFA (inter-node).
# -------------------------------------------------------------------

set -euo pipefail

# EFA/NCCL environment
export LD_LIBRARY_PATH=/opt/amazon/efa/lib:${LD_LIBRARY_PATH:-}
export FI_PROVIDER=efa
export NCCL_NET_GDR_READ=1
export NCCL_SOCKET_IFNAME=ens
export FI_EFA_USE_DEVICE_RDMA=1
export NCCL_DEBUG=INFO

NUM_GPUS=${1:-8}

echo "============================================"
echo "  NCCL All-Reduce Performance Test"
echo "  GPUs: ${NUM_GPUS}"
echo "  Date: $(date)"
echo "  Host: $(hostname)"
echo "============================================"
echo ""

echo "--- nvidia-smi summary ---"
nvidia-smi --query-gpu=index,name,driver_version,memory.total,ecc.errors.corrected.aggregate.total \
  --format=csv,noheader
echo ""

echo "--- EFA devices ---"
/opt/amazon/efa/bin/fi_info -p efa -t FI_EP_RDM 2>/dev/null | head -20 || echo "EFA not available"
echo ""

echo "--- Running all_reduce_perf ---"
echo "  Message sizes: 8 bytes → 2 GB"
echo ""

/usr/bin/all_reduce_perf \
  -b 8 \
  -e 2G \
  -f 2 \
  -g "${NUM_GPUS}" \
  -c 1 \
  -n 100

echo ""
echo "============================================"
echo "  Test Complete"
echo "============================================"
