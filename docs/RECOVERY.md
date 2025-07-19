# Recovery Guide

## Quick Recovery Options

### 1. File Recovery
```bash
# Mount backup and access files
~/scripts/restore_from_backup.fish
# Files available at: /mnt/backup_restore/
```

### 2. Snapshot Rollback  
```bash
# List snapshots
sudo snapper -c root list

# Rollback to snapshot (replace X with number)
sudo snapper -c root undochange 1..X
```

### 3. Complete Disaster Recovery
Boot from Express 1M2 external drive (full backup)

## BTRFS Subvolumes
- @ = Root filesystem (/)
- @home = Home directories (/home)
- @cache = Cache (/var/cache)  
- @log = Logs (/var/log)
