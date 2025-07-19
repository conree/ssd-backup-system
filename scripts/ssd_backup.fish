#!/usr/bin/fish
# SSD Backup Script using dd
# Source: EndeavourOS SSD (UUID-based)
# Destination: Express 1M2 external SSD (UUID-based)

# UUIDs for NEW EndeavourOS installation
set EFI_UUID "221D-363E"
set ROOT_UUID "YOUR_SYSTEM_BTRFS_UUID"

# UUID of the destination device partition (Express 1M2)
set DEST_PARTITION_UUID "YOUR_BACKUP_DEVICE_UUID"

set LOG_FILE "/var/log/ssd_backup.log"

# Function to log messages
function log_message
    set backup_date (date '+%Y-%m-%d %H:%M:%S')
    set message $argv
    echo "[$backup_date] $message" | tee -a $LOG_FILE
    echo "DEBUG: log_message received: $argv" >> $LOG_FILE
end

# Check if script is run as root
if test (id -u) -ne 0
    log_message "ERROR: This script must be run as root"
    exit 1
end

# Debug: List all block devices
log_message "DEBUG: Available block devices:"
lsblk -f | tee -a $LOG_FILE

# Find destination device by partition UUID
set DEST_DEVICE ""
for dev in /dev/nvme{0,1,2,3}n1 /dev/sd{a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z}
    if test -b $dev
        # Check if this device contains a partition with the target UUID
        set found_uuid (lsblk -rno UUID $dev | grep "$DEST_PARTITION_UUID")
        if test -n "$found_uuid"
            set DEST_DEVICE $dev
            log_message "Found destination device by partition UUID: $DEST_DEVICE (Partition UUID: $DEST_PARTITION_UUID)"
            break
        end
    end
end

if test -z "$DEST_DEVICE"
    log_message "ERROR: Could not find destination device with partition UUID $DEST_PARTITION_UUID"
    exit 1
end

# Find source device by UUIDs, scanning all block devices except destination
set SOURCE_DEVICE ""
for dev in /dev/nvme{0,1,2,3}n1 /dev/sd{a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p,q,r,s,t,u,v,w,x,y,z}
    if test -b $dev; and test "$dev" != "$DEST_DEVICE"
        log_message "DEBUG: Checking device $dev"
        set partitions (lsblk -rno NAME,UUID $dev | grep -E "$EFI_UUID|$ROOT_UUID")
        if test (count $partitions) -ge 2
            set SOURCE_DEVICE $dev
            log_message "Found EndeavourOS disk: $SOURCE_DEVICE (EFI UUID: $EFI_UUID, Root UUID: $ROOT_UUID)"
            break
        end
    end
end

if test -z "$SOURCE_DEVICE"
    log_message "ERROR: Could not find EndeavourOS disk with EFI UUID $EFI_UUID and Root UUID $ROOT_UUID"
    exit 1
end

# Check if destination device exists
if not test -b $DEST_DEVICE
    log_message "ERROR: Destination device $DEST_DEVICE not found"
    exit 1
end

# Verify destination as external SSD
set dest_size (blockdev --getsize64 $DEST_DEVICE)
if test $dest_size -lt 1500000000000
    log_message "ERROR: Destination device $DEST_DEVICE ($dest_size bytes) is smaller than expected for external SSD"
    exit 1
end

# Check if destination has sufficient capacity for source
set source_size (blockdev --getsize64 $SOURCE_DEVICE)
if test $dest_size -lt $source_size
    log_message "ERROR: Destination device $DEST_DEVICE ($dest_size bytes) is smaller than source $SOURCE_DEVICE ($source_size bytes)"
    exit 1
end

# Prompt user to verify source and destination
echo ""
echo "Please verify the source and destination devices:"
echo "Source Device: $SOURCE_DEVICE"
echo "  Size: $source_size bytes"
echo "  Details:"
lsblk -f $SOURCE_DEVICE
echo ""
echo "Destination Device: $DEST_DEVICE (Partition UUID: $DEST_PARTITION_UUID)"
echo "  Size: $dest_size bytes"
echo "  Details:"
lsblk -f $DEST_DEVICE
echo ""
echo "WARNING: This will COMPLETELY OVERWRITE $DEST_DEVICE"
echo "Type 'yes' to proceed, or any other key to abort:"
read -l user_confirmation

if test "$user_confirmation" != "yes"
    log_message "ERROR: User aborted operation"
    exit 1
end

log_message "User confirmed: Proceeding with backup from $SOURCE_DEVICE to $DEST_DEVICE"

# Perform the backup using dd
log_message "Beginning dd operation..."
set dd_output (dd if=$SOURCE_DEVICE of=$DEST_DEVICE bs=64K conv=noerror,sync status=progress 2>&1 | tee -a $LOG_FILE)

if test $status -eq 0; and not string match -q "*error*" "$dd_output"
    log_message "SUCCESS: Backup completed successfully"
    
    # Sync to ensure all data is written
    sync
    log_message "Data synced to disk"
    
    # Verify the backup (compares first 1MB)
    log_message "Performing quick verification..."
    if cmp -n 1048576 $SOURCE_DEVICE $DEST_DEVICE >/dev/null 2>&1
        log_message "SUCCESS: Verification passed - first 1MB matches"
    else
        log_message "WARNING: Verification failed - backup may be corrupted"
    end
    
else
    log_message "ERROR: Backup failed due to dd errors"
    exit 1
end

log_message "Backup operation completed"

# Post-backup verification and fixes
log_message "Fixing GPT table on destination..."
sudo partprobe $DEST_DEVICE
sleep 2

# Verify both partitions are accessible  
if not test -b "$DEST_DEVICE"2
    log_message "WARNING: Partition 2 not accessible, attempting fix..."
    sudo partprobe $DEST_DEVICE
    sleep 5
end

# Test mount the backup to verify integrity
log_message "Testing backup accessibility..."
mkdir -p /tmp/backup_verify
if sudo mount -o subvol=@ "$DEST_DEVICE"2 /tmp/backup_verify
    log_message "SUCCESS: Backup verified - root filesystem accessible"
    sudo umount /tmp/backup_verify
else
    log_message "WARNING: Backup verification failed"
end

log_message "Enhanced backup verification completed"
