#!/usr/bin/fish
# Incremental Backup Script using rsync
# Fast daily backups that only copy changed files
# Complements the full dd backup system

set DEST_UUID "YOUR_BACKUP_DEVICE_UUID"
set LOG_FILE "/var/log/incremental_backup.log"
set BACKUP_NAME "incremental_"(date +%Y%m%d_%H%M%S)

# Function to log messages
function log_message
    set backup_date (date '+%Y-%m-%d %H:%M:%S')
    set message $argv
    echo "[$backup_date] $message" | tee -a $LOG_FILE
end

# Check if running as regular user (incremental backups don't need root)
if test (id -u) -eq 0
    log_message "WARNING: Running as root. Incremental backups should run as regular user."
end

log_message "Starting incremental backup: $BACKUP_NAME"

# Find the destination device by UUID
set DEST_MOUNT ""
for mount_point in /run/media/*/* /media/*/* /mnt/*
    if test -d $mount_point
        set mount_uuid (findmnt -n -o UUID $mount_point 2>/dev/null)
        if test "$mount_uuid" = "$DEST_UUID"
            set DEST_MOUNT $mount_point
            break
        end
    end
end

if test -z "$DEST_MOUNT"
    log_message "ERROR: Express 1M2 (UUID: $DEST_UUID) not found or not mounted"
    exit 1
end

log_message "Found Express 1M2 mounted at: $DEST_MOUNT"

# Create backup directory structure
set BACKUP_ROOT "$DEST_MOUNT/incremental_backups"
set CURRENT_BACKUP "$BACKUP_ROOT/$BACKUP_NAME"
set LATEST_LINK "$BACKUP_ROOT/latest"

mkdir -p $BACKUP_ROOT
mkdir -p $CURRENT_BACKUP

log_message "Backup destination: $CURRENT_BACKUP"

# Important directories to backup incrementally
set BACKUP_DIRS \
    "$HOME/.config" \
    "$HOME/scripts" \
    "$HOME/Documents" \
    "$HOME/Pictures" \
    "$HOME/Downloads" \
    "$HOME/.local" \
    "/etc" \
    "/usr/local"

# Directories to exclude (large/unnecessary files)
set EXCLUDE_PATTERNS \
    "*.cache*" \
    "*.tmp*" \
    "*/.git*" \
    "*/node_modules*" \
    "*/target*" \
    "*/__pycache__*" \
    "*.log" \
    "*/Trash*" \
    "*/.local/share/Steam*" \
    "*/.mozilla/firefox/*/Cache*"

log_message "Starting rsync operations..."

# Build rsync exclude options
set exclude_opts
for pattern in $EXCLUDE_PATTERNS
    set exclude_opts $exclude_opts --exclude=$pattern
end

# Backup each important directory
for dir in $BACKUP_DIRS
    if test -d $dir
        set dir_name (basename $dir)
        if test "$dir" = "/etc" -o "$dir" = "/usr/local"
            # System directories need sudo
            log_message "Backing up $dir (requires sudo)"
            sudo rsync -avH --delete --delete-excluded $exclude_opts \
                --link-dest="$LATEST_LINK/$dir_name" \
                "$dir/" "$CURRENT_BACKUP/$dir_name/" 2>&1 | tee -a $LOG_FILE
        else
            # User directories
            log_message "Backing up $dir"
            rsync -avH --delete --delete-excluded $exclude_opts \
                --link-dest="$LATEST_LINK/$dir_name" \
                "$dir/" "$CURRENT_BACKUP/$dir_name/" 2>&1 | tee -a $LOG_FILE
        end
        
        if test $status -eq 0
            log_message "SUCCESS: $dir backed up successfully"
        else
            log_message "WARNING: Issues backing up $dir (exit code: $status)"
        end
    else
        log_message "SKIP: $dir does not exist"
    end
end

# Create/update the 'latest' symlink for next incremental backup
if test -L $LATEST_LINK
    rm $LATEST_LINK
end
ln -s $CURRENT_BACKUP $LATEST_LINK
log_message "Updated latest backup link"

# Calculate backup size
set backup_size (du -sh $CURRENT_BACKUP | cut -f1)
log_message "Backup size: $backup_size"

# Clean up old incremental backups (keep last 30 days)
log_message "Cleaning up old backups (keeping last 30 days)..."
find $BACKUP_ROOT -maxdepth 1 -name "incremental_*" -type d -mtime +30 -exec rm -rf {} \; 2>/dev/null

# Create backup summary
set summary_file "$CURRENT_BACKUP/backup_summary.txt"
echo "Incremental Backup Summary" > $summary_file
echo "=========================" >> $summary_file
echo "Date: $(date)" >> $summary_file
echo "Backup Name: $BACKUP_NAME" >> $summary_file
echo "Backup Size: $backup_size" >> $summary_file
echo "Directories Backed Up:" >> $summary_file
for dir in $BACKUP_DIRS
    if test -d $dir
        echo "  ✓ $dir" >> $summary_file
    else
        echo "  ✗ $dir (not found)" >> $summary_file
    end
end

log_message "Incremental backup completed successfully"
log_message "Summary saved to: $summary_file"

# Show completion stats
echo ""
echo "🎉 Incremental Backup Complete!"
echo "📁 Location: $CURRENT_BACKUP"
echo "📊 Size: $backup_size"
echo "📝 Log: $LOG_FILE"
echo "📋 Summary: $summary_file"
