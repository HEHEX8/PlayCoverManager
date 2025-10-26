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

# Check if internal storage has significant data
# Note: PlayCover may create some initial files immediately on launch
# We only block mounting if there's substantial existing data
if [[ -d "$PLAYCOVER_CONTAINER" ]]; then
    # Check if it's a mount point already (should not happen, but check anyway)
    if /sbin/mount | /usr/bin/grep -q " on ${PLAYCOVER_CONTAINER} "; then
        log "INFO: Container is already a mount point, skipping check"
    else
        # Check for significant data directories (Data, Documents, Library, etc.)
        # These indicate actual app usage, not just initial creation
        SIGNIFICANT_DATA=false
        
        if [[ -d "$PLAYCOVER_CONTAINER/Data" ]] || \
           [[ -d "$PLAYCOVER_CONTAINER/Documents" ]] || \
           [[ -d "$PLAYCOVER_CONTAINER/Library" ]]; then
            # Check if these directories have actual content
            local data_size=$(/usr/bin/du -sk "$PLAYCOVER_CONTAINER" 2>/dev/null | /usr/bin/awk '{print $1}')
            
            # If container size > 1MB (1024KB), consider it significant data
            if [[ -n "$data_size" ]] && [[ $data_size -gt 1024 ]]; then
                SIGNIFICANT_DATA=true
                log "WARNING: Internal storage has significant data (${data_size}KB)"
            fi
        fi
        
        if [[ "$SIGNIFICANT_DATA" == true ]]; then
            log "ERROR: Internal storage has substantial data - manual migration required"
            log "SOLUTION: Use 'アプリ管理' menu to handle internal data cleanup"
            
            # Show notification to user
            /usr/bin/osascript -e 'display notification "内蔵ストレージに既存データがあります。アプリ管理メニューから処理してください。" with title "PlayCover 内部データ検出" sound name "Glass"' 2>/dev/null || true
            
            exit 1
        else
            # Small amount of data or just metadata - safe to clear
            if [[ -d "$PLAYCOVER_CONTAINER" ]]; then
                log "INFO: Clearing minimal internal data before mount"
                /bin/rm -rf "$PLAYCOVER_CONTAINER" 2>/dev/null || true
            fi
        fi
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
