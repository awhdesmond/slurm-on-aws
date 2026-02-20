# NFS Server Runbook

Operational reference for the NFS server node (`nfs0`) serving `/shared` to the Slurm cluster.

## Log Locations

| Location | Contents |
|---|---|
| `/var/log/syslog` | NFS daemon messages (mountd, nfsd, rpc.statd) |
| `journalctl -u nfs-kernel-server` | Systemd service logs |
| `journalctl -u rpc-mountd` | Client mount request logs |
| `/var/log/kern.log` | Kernel-level NFS messages (lockd, nfsd threads) |

## Live Stats & Diagnostics

```bash
# NFS server operation stats
nfsstat -s

# Watch operations per second in real-time
watch -n 1 'nfsstat -s -l'

# Connected clients and their mounts
showmount -a

# Current exports
exportfs -v

# Active NFS thread count
cat /proc/fs/nfsd/threads

# Detailed RPC stats (cache hits, thread utilisation)
cat /proc/net/rpc/nfsd
```

## Debugging

```bash
# Enable verbose NFS debug logging (writes to syslog)
rpcdebug -m nfsd -s all

# Disable debug logging
rpcdebug -m nfsd -c all

# Check for stale file handles or RPC errors
dmesg | grep -i nfs
```

## Common Issues

### Clients can't mount

```bash
# Verify exports are active
exportfs -v

# Re-export after editing /etc/exports
exportfs -ra

# Check if NFS ports are listening
ss -tlnp | grep -E '(2049|111)'

# Verify security group allows traffic from compute subnet
```

### Slow performance

```bash
# Check thread utilisation (if th= shows high values, threads are saturated)
cat /proc/net/rpc/nfsd | grep th

# Current thread count vs configured
cat /proc/fs/nfsd/threads
grep RPCNFSDCOUNT /etc/default/nfs-kernel-server

# Check disk I/O bottleneck
iostat -x 1

# Verify sysctl tunings are applied
sysctl net.core.rmem_max net.core.wmem_max vm.dirty_ratio
```

### Service won't start

```bash
# Check service status
systemctl status nfs-kernel-server

# Check for port conflicts
ss -tlnp | grep 2049

# Validate /etc/exports syntax
exportfs -ra 2>&1

# Full service restart
systemctl restart nfs-kernel-server
```

## Tuning Reference

Current tunings applied by Ansible (see `roles/nfs/tasks/main.yml`):

| Setting | Value | Purpose |
|---|---|---|
| `RPCNFSDCOUNT` | 64 | NFS worker threads |
| `net.core.rmem_max` | 16 MB | Max socket receive buffer |
| `net.core.wmem_max` | 16 MB | Max socket send buffer |
| `vm.dirty_ratio` | 40 | % RAM for dirty pages before forced flush |
| `vm.dirty_background_ratio` | 10 | % RAM before background flush starts |
| `vm.vfs_cache_pressure` | 50 | Favour keeping inode/dentry caches |
| Read-ahead | 4096 sectors | Sequential read prefetch |
| Export mode | `async` | Faster writes, risk on server crash |
