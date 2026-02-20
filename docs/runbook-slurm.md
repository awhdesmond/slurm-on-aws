# Slurm Cluster Runbook

Operational and troubleshooting guide for the AWS Slurm cluster.

## Architecture

| Component | Node(s) | Role & Configuration |
|---|---|---|
| **Slurmctld** | `controller0` (Primary)<br>`controller1` (Backup) | Central management, scheduling, state tracking (`/shared/slurmctld`). |
| **SlurmDBD** | `controller0` (Primary)<br>`controller1` (Backup) | Accounting daemon connecting to RDS MySQL. Configured for High Availability. |
| **Slurmd** | `compute[0-2]`<br>`gpu-compute[0-1]` | Compute daemon running on worker nodes. Executes jobs and monitors resources. |
| **Munge** | All Nodes | Authentication service. Uses a shared secret key `/etc/munge/munge.key`. |

### Hardware Mapping
- **t2.small (cpu)**: 1 CPU, 2GB Memory
- **p4d.24xlarge (gpu)**: 96 CPUs, 1.1TB Memory, 8x A100 40GB GPUs (`Gres=gpu:a100:8`)

---

## Log Locations

- **Controller Daemon:** `/var/log/slurmctld.log` (on controllers)
- **Accounting Daemon:** `/var/log/slurmdbd.log` (on controllers)
- **Worker Daemon:** `/var/log/slurmd.log` (on compute nodes)
- **Munge Auth:** `/var/log/munge/munged.log` (on all nodes)

---

## Core Operations

### Cluster Status
```bash
# View overall partition and node state
sinfo

# View detailed information about specific nodes
scontrol show node gpu-compute0
```

### Job Management
```bash
# View running and queued jobs
squeue

# View detailed job information
scontrol show job <job_id>

# Cancel a job
scancel <job_id>
```

### Accounting
```bash
# View cluster usage statistics
sreport cluster utilization

# View historical job data (queries RDS via SlurmDBD)
sacct -j <job_id> --format=JobID,JobName,Partition,NodeList,State,ExitCode,MaxRSS
```

### DCGM GPU Job Accounting
The cluster automatically tracks detailed GPU metrics (utilization, memory bandwidth, power draw, and ECC errors) for every Slurm job running on the `gpu-compute` nodes via native DCGM integration in the Slurm Prolog and Epilog scripts.

- **Storage Location:** `/shared/slurm_job_stats/job_<job_id>_<hostname>.log`
- **Retention:** Logs are automatically rotated and deleted after 30 days.

To view the GPU profile for a completed job:
```bash
cat /shared/slurm_job_stats/job_1234_gpu-compute0.log
```

---

## Health Checks & Node Draining

The cluster uses an automated health check (`/etc/slurm-llnl/healthcheck.py`) running every 5 minutes (`HealthCheckInterval=300`). 
It monitors:
1. GPU XID Errors (fatal driver crashes)
2. PCIe AER faults
3. EFA/InfiniBand link state drops
4. Hung parallel filesystems (`/shared` and `/shared_gluster`)

### Managing Drained Nodes
If a node fails a health check, its state becomes `DRAIN`. 

```bash
# View reasons for drained nodes
sinfo -R

# To return a drained node to service (after fixing the issue):
sudo scontrol update NodeName=<node_name> State=RESUME
```

---

## Common Issues & Troubleshooting

### 1. Nodes stuck in `DOWN` or `DRAIN` state immediately after boot
**Symptom:** Run `sinfo` and nodes appear as `DOWN` or `DRAIN` with no obvious reason.
**Cause:** Node hardware doesn't match `slurm.conf`. 
**Fix:** 
1. Run `slurmd -C` on the problem node to print its actual hardware specs.
2. Ensure values in `slurm.conf` (CPUs, RealMemory) are slightly *lower* or exactly equal to the reported physical hardware.

### 2. "Invalid credential" or "Munge decode failed"
**Symptom:** Slurm commands (`sinfo`, `squeue`) hang or return authentication errors.
**Cause:** Munge daemon isn't running, clocks are out of sync, or the munge key differs between nodes.
**Fix:**
```bash
# Check munge status
systemctl status munge

# Verify clocks are synced (AWS Time Sync should handle this)
chronyc tracking

# Restart munge
sudo systemctl restart munge
```

### 3. SlurmDBD Connection Refused
**Symptom:** Controller logs show `slurmdbd: connection refused` or accounting commands (`sacct`) fail.
**Cause:** `slurmdbd` is down or RDS database is unreachable.
**Fix:**
```bash
# Check SlurmDBD process
systemctl status slurmdbd

# Check SlurmDBD configuration for RDS endpoint
cat /etc/slurm-llnl/slurmdbd.conf | grep StorageHost

# Restart services
sudo systemctl restart slurmdbd
sudo systemctl restart slurmctld
```

### 4. High Latency or GPU Job Hangs
**Symptom:** Multi-node GPU jobs start but make no progress.
**Cause:** EFA network is down or NCCL is falling back to slow TCP.
**Fix:**
1. Check EFA status: `/opt/amazon/efa/bin/fi_info -p efa`
2. Ensure NCCL variables are set: `env | grep NCCL`
3. Check the internal GPU network (NVSwitch): `systemctl status nvidia-fabricmanager`

---

## HPC Optimizations Applied

This cluster includes several parameters tuned for AWS and throughput:
- **Scheduler:** `bf_continue`, `bf_max_job_user=100` (rapid backfilling)
- **Timeouts:** `MessageTimeout=60`, `SlurmdTimeout=300`, `TCPTimeout=5` (resilience to AWS network blips)
- **Cgroups:** `ConstrainCores`, `ConstrainRAMSpace`, `ConstrainDevices` (strict isolation)
- **Topology:** `topology/tree` (pack communicating GPU tasks physically close)
- **Affinity:** `CR_Core_Memory,CR_ONE_TASK_PER_CORE` (dedicated CPU core per task)
