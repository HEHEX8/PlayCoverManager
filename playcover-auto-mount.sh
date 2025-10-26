#!/bin/bash

#######################################################
# PlayCover Auto-Mount Helper
# 
# Purpose: Automatically mount PlayCover volume before
#          PlayCover.app launches to prevent internal
#          storage data creation
#
# Usage: Called by LaunchAgent when PlayCover starts
#######################################################

# Configuration
PLAYCOVER_VOLUME_NAME="PlayCover"
PLAYCOVER_CONTAINER="${HOME}/Library/Containers/io.playcover.PlayCover"
LOG_FILE="${HOME}/Library/Logs/playcover-auto-mount.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log "=== PlayCover Auto-Mount Started ==="

# Check if volume exists
if ! /usr/sbin/diskutil list 2>/dev/null | /usr/bin/grep -q "APFS Volume ${PLAYCOVER_VOLUME_NAME}"; then
    log "ERROR: PlayCover volume not found"
    exit 1
fi

# Get volume device
VOLUME_DEVICE=$(/usr/sbin/diskutil list 2>/dev/null | /usr/bin/grep "APFS Volume ${PLAYCOVER_VOLUME_NAME}" | /usr/bin/awk '{print $NF}')

if [[ -z "$VOLUME_DEVICE" ]]; then
    log "ERROR: Could not get volume device"
    exit 1
fi

# Check current mount status
CURRENT_MOUNT=$(/usr/sbin/diskutil info "$VOLUME_DEVICE" 2>/dev/null | /usr/bin/grep "Mount Point:" | /usr/bin/sed 's/.*Mount Point: *//' | /usr/bin/sed 's/ *$//')

# If already mounted at correct location, nothing to do
if [[ "$CURRENT_MOUNT" == "$PLAYCOVER_CONTAINER" ]]; then
    log "INFO: Already mounted at correct location"
    exit 0
fi

# If mounted elsewhere, unmount first
if [[ -n "$CURRENT_MOUNT" ]] && [[ "$CURRENT_MOUNT" != "Not applicable (no file system)" ]]; then
    log "INFO: Unmounting from wrong location: $CURRENT_MOUNT"
    if ! /usr/sbin/diskutil unmount "$VOLUME_DEVICE" >/dev/null 2>&1; then
        log "WARNING: Failed to unmount from $CURRENT_MOUNT"
    fi
fi

# Create target directory if needed
if [[ ! -d "$PLAYCOVER_CONTAINER" ]]; then
    /bin/mkdir -p "$PLAYCOVER_CONTAINER" 2>/dev/null || true
fi

# Check if internal storage has data (CRITICAL CHECK)
if [[ -d "$PLAYCOVER_CONTAINER" ]]; then
    # Check for actual content (ignore macOS metadata)
    CONTENT_CHECK=$(/bin/ls -A1 "$PLAYCOVER_CONTAINER" 2>/dev/null | \
        /usr/bin/grep -v -x -F '.DS_Store' | \
        /usr/bin/grep -v -x -F '.Spotlight-V100' | \
        /usr/bin/grep -v -x -F '.Trashes' | \
        /usr/bin/grep -v -x -F '.fseventsd' | \
        /usr/bin/grep -v -x -F '.TemporaryItems' | \
        /usr/bin/grep -v -F '.com.apple.containermanagerd.metadata.plist')
    
    if [[ -n "$CONTENT_CHECK" ]]; then
        log "ERROR: Internal storage has data - cannot mount to prevent data loss"
        log "SOLUTION: Use storage switch feature to migrate data first"
        
        # Show notification to user
        /usr/bin/osascript -e 'display notification "内蔵ストレージにデータが存在します。ストレージ切り替え機能を使用してください。" with title "PlayCover マウントエラー" sound name "Glass"' 2>/dev/null || true
        
        exit 1
    fi
fi

# Mount the volume
log "INFO: Mounting PlayCover volume to $PLAYCOVER_CONTAINER"
if /sbin/mount -t apfs -o nobrowse "$VOLUME_DEVICE" "$PLAYCOVER_CONTAINER" >/dev/null 2>&1; then
    # Set correct ownership
    /usr/sbin/chown -R $(id -u):$(id -g) "$PLAYCOVER_CONTAINER" 2>/dev/null || true
    log "SUCCESS: PlayCover volume mounted successfully"
    exit 0
else
    log "ERROR: Failed to mount PlayCover volume"
    
    # Show notification to user
    /usr/bin/osascript -e 'display notification "PlayCoverボリュームのマウントに失敗しました。" with title "PlayCover マウントエラー" sound name "Glass"' 2>/dev/null || true
    
    exit 1
fi
