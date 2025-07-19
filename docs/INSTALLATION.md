# Installation Guide

## Step 1: Find Your UUIDs
```bash
# Find your backup device UUID
sudo blkid

# Find your system BTRFS UUID  
sudo blkid | grep btrfs
```

## Step 2: Update Scripts
Edit each script in scripts/ and replace:
- YOUR_BACKUP_DEVICE_UUID with your external drive UUID
- YOUR_SYSTEM_BTRFS_UUID with your system BTRFS UUID

## Step 3: Setup Automation
```bash
# Add to crontab
crontab -e

# Add these lines:
0 2 * * * /home/yourusername/scripts/incremental_backup.fish
0 3 * * 0 /home/yourusername/scripts/ssd_backup.fish
```
