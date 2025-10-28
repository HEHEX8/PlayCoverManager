#!/bin/zsh
#######################################################
# PlayCover Manager - Volume Operations Module
# ボリュームの作成、マウント、アンマウント、検出
#######################################################

# Note: Basic mount_volume() and unmount_volume() are in 00_core.sh
# This module contains higher-level volume operations

#######################################################
# Volume Detection Functions
#######################################################

# Check if APFS volume exists
# Args: volume_name, [diskutil_cache]
# Returns: 0 if exists, 1 if not found
volume_exists() {
    local volume_name=$1
    local diskutil_cache="${2:-}"
    
    # Use flexible pattern to match volume name (handles special characters and formatting)
    if [[ -n "$diskutil_cache" ]]; then
        echo "$diskutil_cache" | /usr/bin/grep -i "APFS Volume" | /usr/bin/grep -q "${volume_name}"
    else
        /usr/sbin/diskutil list | /usr/bin/grep -i "APFS Volume" | /usr/bin/grep -q "${volume_name}"
    fi
}

# Get volume device identifier
# Args: volume_name, [diskutil_cache]
# Output: Device identifier (e.g., disk3s2)
# Returns: Device string or empty
get_volume_device() {
    local volume_name=$1
    local diskutil_cache="${2:-}"
    
    # Use flexible pattern to match volume name and extract device
    if [[ -n "$diskutil_cache" ]]; then
        echo "$diskutil_cache" | /usr/bin/grep -i "APFS Volume" | /usr/bin/grep "${volume_name}" | /usr/bin/awk '{print $NF}'
    else
        /usr/sbin/diskutil list | /usr/bin/grep -i "APFS Volume" | /usr/bin/grep "${volume_name}" | /usr/bin/awk '{print $NF}'
    fi
}

# Get current mount point of volume
# Args: volume_name, [diskutil_cache]
# Output: Mount point path or empty string
get_mount_point() {
    local volume_name=$1
    local diskutil_cache="${2:-}"
    local device=$(get_volume_device "$volume_name" "$diskutil_cache")
    
    if [[ -z "$device" ]]; then
        echo ""
        return 1
    fi
    
    /usr/sbin/diskutil info "$device" 2>/dev/null | /usr/bin/grep "Mount Point:" | /usr/bin/sed 's/.*Mount Point: *//;s/ *$//'
}

# Check volume existence with automatic error handling and callback
# Args: volume_name, title, [callback]
# Returns: 0 if volume exists, 1 if not (with error display and callback)
check_volume_exists_or_error() {
    local volume_name="$1"
    local title="$2"
    local callback="${3:-}"
    
    if ! volume_exists "$volume_name"; then
        show_error_and_return "$title" "ボリューム '${volume_name}' が見つかりません" "$callback"
        return 1
    fi
    
    return 0
}

#######################################################
# High-Level Volume Operations
#######################################################

# Unmount app volume with optional app quit
# Args: volume_name, bundle_id, [diskutil_cache]
# Returns: 0 on success, 1 on failure
unmount_app_volume() {
    local volume_name=$1
    local bundle_id=$2
    local diskutil_cache="${3:-}"
    
    # Cache diskutil list output if not provided
    if [[ -z "$diskutil_cache" ]]; then
        diskutil_cache=$(/usr/sbin/diskutil list 2>/dev/null)
    fi
    
    if ! volume_exists "$volume_name" "$diskutil_cache"; then
        print_warning "ボリューム '${volume_name}' が見つかりません"
        return 1
    fi
    
    local current_mount=$(get_mount_point "$volume_name" "$diskutil_cache")
    
    if [[ -z "$current_mount" ]]; then
        print_info "既にアンマウント済みです"
        return 0
    fi
    
    # Quit app before unmounting if bundle_id is provided
    if [[ -n "$bundle_id" ]]; then
        quit_app_if_running "$bundle_id"
    fi
    
    local device=$(get_volume_device "$volume_name" "$diskutil_cache")
    
    if unmount_volume "$device" "silent"; then
        print_success "アンマウント成功"
        return 0
    else
        print_error "アンマウント失敗"
        return 1
    fi
}

# Mount app volume to specific path
# Args: volume_name, mount_path, [bundle_id]
# Returns: 0 on success, 1 on failure
mount_app_volume() {
    local volume_name=$1
    local mount_path=$2
    local bundle_id="${3:-}"
    
    # Check if volume exists
    if ! volume_exists "$volume_name"; then
        print_error "ボリューム '${volume_name}' が見つかりません"
        return 1
    fi
    
    # Get volume device
    local device=$(get_volume_device "$volume_name")
    if [[ -z "$device" ]]; then
        print_error "デバイスの取得に失敗しました"
        return 1
    fi
    
    # Check if already mounted at correct location
    local current_mount=$(get_mount_point "$volume_name")
    if [[ "$current_mount" == "$mount_path" ]]; then
        print_info "既に正しい位置にマウント済みです"
        return 0
    fi
    
    # If mounted elsewhere, unmount first
    if [[ -n "$current_mount" ]]; then
        print_info "別の位置にマウントされているため、再マウントします"
        if [[ -n "$bundle_id" ]]; then
            quit_app_if_running "$bundle_id"
        fi
        unmount_volume "$device" "silent" || unmount_volume "$device" "silent" "force"
    fi
    
    # Create mount point if not exists
    if [[ ! -d "$mount_path" ]]; then
        /usr/bin/sudo /bin/mkdir -p "$mount_path" 2>/dev/null
    fi
    
    # Mount with nobrowse option
    if mount_volume "$device" "$mount_path" "nobrowse" "silent"; then
        print_success "マウント成功: $mount_path"
        return 0
    else
        print_error "マウント失敗"
        return 1
    fi
}

#######################################################
# Volume Creation Functions
#######################################################

# Create new APFS volume for app
# Args: volume_name, disk_identifier, size_gb
# Returns: 0 on success, 1 on failure
create_app_volume() {
    local volume_name=$1
    local disk_identifier=$2
    local size_gb=${3:-10}
    
    print_info "ボリュームを作成中: ${volume_name} (${size_gb}GB)"
    
    # Create APFS volume with specified size
    if /usr/bin/sudo /usr/sbin/diskutil apfs addVolume "$disk_identifier" APFS "$volume_name" -size "${size_gb}g" >/dev/null 2>&1; then
        print_success "ボリュームの作成に成功しました"
        return 0
    else
        print_error "ボリュームの作成に失敗しました"
        return 1
    fi
}

# Delete APFS volume
# Args: volume_name
# Returns: 0 on success, 1 on failure
delete_app_volume() {
    local volume_name=$1
    
    if ! volume_exists "$volume_name"; then
        print_warning "ボリューム '${volume_name}' は存在しません"
        return 0
    fi
    
    local device=$(get_volume_device "$volume_name")
    if [[ -z "$device" ]]; then
        print_error "デバイスの取得に失敗しました"
        return 1
    fi
    
    print_info "ボリュームを削除中: ${volume_name}"
    
    # Unmount first if mounted
    local mount_point=$(get_mount_point "$volume_name")
    if [[ -n "$mount_point" ]]; then
        unmount_volume "$device" "silent" || unmount_volume "$device" "silent" "force"
    fi
    
    # Delete volume
    if /usr/bin/sudo /usr/sbin/diskutil apfs deleteVolume "$device" >/dev/null 2>&1; then
        print_success "ボリュームの削除に成功しました"
        return 0
    else
        print_error "ボリュームの削除に失敗しました"
        return 1
    fi
}

#######################################################
# Utility Functions
#######################################################

# Get drive name from device path
# Args: device_path (e.g., /dev/disk3s1)
# Output: Drive name (e.g., "External SSD")
get_drive_name() {
    local device=$1
    
    # Extract disk identifier (e.g., disk3 from disk3s1)
    local disk_id=$(echo "$device" | /usr/bin/sed 's|/dev/||;s|s[0-9]*$||')
    
    # Get drive name from diskutil info
    /usr/sbin/diskutil info "$disk_id" 2>/dev/null | /usr/bin/grep "Device / Media Name:" | /usr/bin/sed 's/.*Device \/ Media Name: *//' | /usr/bin/sed 's/ *$//'
}

# Check if PlayCover main volume is mounted
# Returns: 0 if mounted, 1 if not
check_playcover_volume_mount() {
    if [[ -d "$PLAYCOVER_CONTAINER" ]]; then
        # Check if it's actually a mount point
        if /sbin/mount | /usr/bin/grep -q "$PLAYCOVER_CONTAINER"; then
            return 0
        fi
    fi
    return 1
}

#######################################################
# Disk Eject Function
#######################################################

# Eject external disk containing PlayCover volume
# Unmounts all PlayCover-related volumes before ejecting
eject_disk() {
    clear
    
    # Get current PlayCover volume device dynamically
    local playcover_device=""
    if volume_exists "$PLAYCOVER_VOLUME_NAME"; then
        local volume_device=$(get_volume_device "$PLAYCOVER_VOLUME_NAME")
        if [[ -n "$volume_device" ]]; then
            playcover_device="/dev/${volume_device}"
        fi
    fi
    
    if [[ -z "$playcover_device" ]]; then
        print_header "ディスク取り外し"
        print_error "PlayCoverボリュームが見つかりません"
        wait_for_enter
        return
    fi
    
    local disk_id=$(echo "$playcover_device" | /usr/bin/sed -E 's|/dev/(disk[0-9]+).*|\1|')
    local drive_name=$(get_drive_name "$playcover_device")
    
    print_header "「${drive_name}」の取り外し"
    
    print_warning "このドライブの全てのボリュームをアンマウントします"
    echo ""
    print_info "注意: PlayCover関連ボリューム以外も含まれる可能性があります"
    echo ""
    
    if ! prompt_confirmation "続行しますか？" "Y"; then
        print_info "$MSG_CANCELED"
        wait_for_enter "Enterキーで続行..."
        return
    fi
    
    # Authenticate sudo only when user confirms
    authenticate_sudo
    
    echo ""
    
    # Use existing batch_unmount_all logic to unmount all mapped volumes
    local mappings_content=$(read_mappings)
    
    if [[ -n "$mappings_content" ]]; then
        local -a mappings_array=()
        while IFS=$'\t' read -r volume_name bundle_id display_name; do
            [[ -z "$volume_name" || -z "$bundle_id" ]] && continue
            mappings_array+=("${volume_name}|${bundle_id}|${display_name}")
        done <<< "$mappings_content"
        
        if [[ ${#mappings_array} -gt 0 ]]; then
            print_info "登録済みボリュームをアンマウント中..."
            echo ""
            
            # Cache diskutil list for performance (single call for all volumes)
            local diskutil_cache=$(/usr/sbin/diskutil list 2>/dev/null)
            
            local success_count=0
            local fail_count=0
            
            # Unmount in reverse order (apps first, PlayCover last)
            for ((i=${#mappings_array}; i>=1; i--)); do
                IFS='|' read -r volume_name bundle_id display_name <<< "${mappings_array[$i]}"
                
                # Check if this volume is on the target disk
                local device=$(get_volume_device "$volume_name" "$diskutil_cache" 2>/dev/null)
                if [[ -z "$device" ]]; then
                    continue
                fi
                
                local vol_disk=$(echo "$device" | /usr/bin/sed -E 's|(disk[0-9]+).*|\1|')
                if [[ "$vol_disk" != "$disk_id" ]]; then
                    continue
                fi
                
                echo "  ${CYAN}${display_name}${NC} (${volume_name})"
                
                local current_mount=$(get_mount_point "$volume_name" "$diskutil_cache")
                
                if [[ -z "$current_mount" ]]; then
                    echo "     ${GREEN}✅ 既にアンマウント済${NC}"
                    ((success_count++))
                else
                    if [[ -n "$bundle_id" ]]; then
                        quit_app_if_running "$bundle_id"
                    fi
                    
                    if unmount_volume "$device" "silent"; then
                        echo "     ${GREEN}✅ アンマウント成功${NC}"
                        ((success_count++))
                    else
                        if /usr/bin/pgrep -f "$bundle_id" >/dev/null 2>&1; then
                            echo "     ${RED}❌ アンマウント失敗: アプリが実行中です${NC}"
                        else
                            echo "     ${RED}❌ アンマウント失敗${NC}"
                        fi
                        ((fail_count++))
                    fi
                fi
                echo ""
            done
            
            if [[ $success_count -gt 0 ]] || [[ $fail_count -gt 0 ]]; then
                echo ""
                print_info "PlayCover関連: 成功 ${success_count}個, 失敗 ${fail_count}個"
            fi
        fi
    fi
    
    echo ""
    print_info "ディスク ${drive_name} (${disk_id}) を取り外し中..."
    
    if /usr/bin/sudo /usr/sbin/diskutil eject "$disk_id"; then
        print_success "ディスク ${drive_name} を安全に取り外しました"
        echo ""
        print_info "3秒後にターミナルを自動で閉じます..."
        /bin/sleep 3
        /usr/bin/osascript -e 'tell application "Terminal" to close (every window whose name contains "playcover")' & exit 0
    else
        print_error "ディスクの取り外しに失敗しました"
        wait_for_enter
    fi
}
