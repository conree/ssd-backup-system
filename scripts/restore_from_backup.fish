#!/usr/bin/fish
# Enhanced Recovery Script for BTRFS Backup

set BACKUP_UUID "YOUR_SYSTEM_BTRFS_UUID"
set LOG_FILE "/var/log/restore_backup.log"

function log_message
    set restore_date (date '+%Y-%m-%d %H:%M:%S')
    set message $argv
    echo "[$restore_date] $message"
end

log_message "Starting backup recovery process"

# Find backup device by BTRFS UUID
set BACKUP_DEVICE ""
for device in /dev/sdb2 /dev/sdc2 /dev/sdd2
    if test -b $device
        set uuid (sudo blkid -s UUID -o value $device 2>/dev/null)
        if test "$uuid" = "$BACKUP_UUID"
            set BACKUP_DEVICE $device
            log_message "Found backup device: $BACKUP_DEVICE"
            break
        end
    end
end

if test -z "$BACKUP_DEVICE"
    log_message "ERROR: Could not find backup device"
    exit 1
end

# Mount backup
set MOUNT_ROOT "/mnt/backup_restore"
sudo mkdir -p $MOUNT_ROOT/home
sudo mount -o subvol=@ $BACKUP_DEVICE $MOUNT_ROOT
sudo mount -o subvol=@home $BACKUP_DEVICE $MOUNT_ROOT/home

echo "🎯 Backup mounted at: $MOUNT_ROOT"
echo "Access files: cd $MOUNT_ROOT"
echo "Unmount: sudo umount $MOUNT_ROOT/home $MOUNT_ROOT"
