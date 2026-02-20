# GlusterFS Runbook

Operational reference for the GlusterFS parallel filesystem nodes (`gluster0`, `gluster1`, `gluster2`).

## Log Locations

| Location | Contents |
|---|---|
| `/var/log/glusterfs/glusterd.log` | GlusterFS management daemon |
| `/var/log/glusterfs/bricks/` | Per-brick logs |
| `/var/log/glusterfs/cli.log` | CLI command logs |
| `journalctl -u glusterd` | Systemd service logs |

## Cluster Status

```bash
# Overall peer status
sudo gluster peer status

# Volume info
sudo gluster volume info gv0

# Volume status (detailed brick-level)
sudo gluster volume status gv0 detail

# Check heal status (replica volumes)
sudo gluster volume heal gv0 info
sudo gluster volume heal gv0 info summary

# List connected clients
sudo gluster volume status gv0 clients
```

## Performance Diagnostics

```bash
# Volume I/O stats
sudo gluster volume profile gv0 start
sudo gluster volume profile gv0 info
sudo gluster volume profile gv0 stop

# Top operations (open, read, write, etc.)
sudo gluster volume top gv0 open
sudo gluster volume top gv0 read
sudo gluster volume top gv0 write

# Brick-level disk I/O
iostat -x 1

# Check read-ahead setting
blockdev --getra /dev/xvdh
```

## Common Issues

### Split-brain

```bash
# Check for split-brain entries
sudo gluster volume heal gv0 info split-brain

# Resolve using the larger file
sudo gluster volume heal gv0 split-brain bigger-file <filename>

# Or pick a specific source brick
sudo gluster volume heal gv0 split-brain source-brick \
    gluster0:/export/xvdh1/brick <filename>
```

### Brick offline

```bash
# Check brick status
sudo gluster volume status gv0

# Restart the brick's glusterd
sudo systemctl restart glusterd

# If brick won't come up, check the brick log
tail -100 /var/log/glusterfs/bricks/*.log

# Force-start the volume
sudo gluster volume start gv0 force
```

### Slow performance

```bash
# Check if profiling reveals hot bricks
sudo gluster volume profile gv0 start
sudo gluster volume profile gv0 info

# Verify sysctl tunings are applied
sysctl net.core.rmem_max net.core.wmem_max vm.dirty_ratio vm.swappiness

# Check XFS mount options
mount | grep xvdh1

# Check disk utilisation
df -h /export/xvdh1
```

### Self-heal not completing

```bash
# Check pending heals
sudo gluster volume heal gv0 info summary

# Trigger a full heal
sudo gluster volume heal gv0 full

# Monitor heal progress
watch -n 5 'sudo gluster volume heal gv0 info summary'
```

## Volume Tuning (Post-Creation)

These can be applied after `gluster volume create` and `gluster volume start`:

```bash
# Increase thread count for parallel I/O
sudo gluster volume set gv0 performance.io-thread-count 32

# Enable read-ahead and write-behind caching
sudo gluster volume set gv0 performance.read-ahead on
sudo gluster volume set gv0 performance.write-behind on
sudo gluster volume set gv0 performance.cache-size 512MB

# Optimise for large-file HPC workloads
sudo gluster volume set gv0 performance.io-cache on
sudo gluster volume set gv0 performance.quick-read off
sudo gluster volume set gv0 performance.open-behind on
sudo gluster volume set gv0 performance.stat-prefetch on

# Network tuning
sudo gluster volume set gv0 network.ping-timeout 30
sudo gluster volume set gv0 server.event-threads 4
sudo gluster volume set gv0 client.event-threads 4
```

## Tuning Reference

Tunings applied by Ansible (`roles/glusterfs/tasks/main.yml`):

| Setting | Value | Purpose |
|---|---|---|
| `net.core.rmem_max` | 16 MB | Max socket receive buffer |
| `net.core.wmem_max` | 16 MB | Max socket send buffer |
| `net.core.somaxconn` | 4096 | Connection backlog for parallel clients |
| `vm.dirty_ratio` | 40 | % RAM for dirty pages before forced flush |
| `vm.dirty_background_ratio` | 10 | % RAM before background flush starts |
| `vm.swappiness` | 10 | Minimise swapping on storage nodes |
| `vm.vfs_cache_pressure` | 50 | Favour keeping inode/dentry caches |
| I/O scheduler | `none` | Bypass scheduler for EBS (SSD-backed) |
| Read-ahead | 4096 sectors | Sequential read prefetch on brick device |
| XFS mount | `noatime,nodiratime,inode64` | Reduce metadata overhead |
| XFS inode size | 512 bytes | Better extended attribute performance |
