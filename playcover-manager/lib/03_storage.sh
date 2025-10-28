#!/bin/zsh
#
# PlayCover Volume Manager - Module 03: Storage Detection & Switching
# ════════════════════════════════════════════════════════════════════
#
# This module provides storage detection and switching capabilities:
# - Container size calculation (human-readable and bytes)
# - Free space calculation for internal/external storage
# - Storage type detection (internal/external/none)
# - Internal storage flag management
# - Storage mode detection (intentional vs contamination)
# - Complete internal ⇄ external switching with data migration
#
# Storage Mode States:
#   - external                    : Data is on mounted external volume
#   - external_wrong_location     : External volume mounted at wrong path
#   - internal_intentional        : Intentionally switched to internal (has flag + data)
#   - internal_intentional_empty  : Intentionally switched to internal (has flag, no data)
#   - internal_contaminated       : Accidentally has internal data (no flag, has data)
#   - none                        : No data exists (empty or unmounted)
#
# Version: 5.0.0-alpha1
# Part of: Modular Architecture Refactoring

#######################################################
# Container Size Calculation
#######################################################

# Get container size in human-readable format (decimal/1000-based like macOS Finder)
get_container_size() {
    local container_path=$1
    
    if [[ ! -e "$container_path" ]]; then
        echo "0B"
        return
    fi
    
    # Get size in bytes first, then use our bytes_to_human function for consistent decimal units
    local size_kb=$(/usr/bin/du -sk "$container_path" 2>/dev/null | /usr/bin/awk '{print $1}')
    
    if [[ -z "$size_kb" ]] || [[ ! "$size_kb" =~ ^[0-9]+$ ]]; then
        echo "0B"
        return
    fi
    
    local size_bytes=$((size_kb * 1024))
    bytes_to_human "$size_bytes"
}

# Get container size with styled formatting (bold number + normal unit)
get_container_size_styled() {
    local container_path=$1
    local size=$(get_container_size "$container_path")
    
    # Extract number and unit using regex
    if [[ "$size" =~ ^([0-9.]+)([A-Za-z]+)$ ]]; then
        local number="${match[1]}"
        local unit="${match[2]}"
        echo "${BOLD}${WHITE}${number}${NC}${LIGHT_GRAY}${unit}${NC}"
    else
        echo "${LIGHT_GRAY}${size}${NC}"
    fi
}

# Get container size in bytes (for capacity comparison)
get_container_size_bytes() {
    local container_path=$1
    
    if [[ ! -e "$container_path" ]]; then
        echo "0"
        return
    fi
    
    # Use get_directory_size for kilobytes, then convert to bytes
    local size_kb=$(get_directory_size "$container_path")
    
    if [[ -z "$size_kb" ]]; then
        echo "0"
    else
        echo $((size_kb * 1024))
    fi
}

#######################################################
# Free Space Calculation
#######################################################

# Get storage free space in bytes (for capacity comparison)
get_storage_free_space_bytes() {
    local target_path="${1:-$HOME}"
    
    # Get free space using df (1K-blocks)
    local free_blocks=$(/bin/df "$target_path" 2>/dev/null | /usr/bin/tail -1 | /usr/bin/awk '{print $4}')
    
    if [[ -z "$free_blocks" ]]; then
        echo "0"
    else
        echo $((free_blocks * 1024))
    fi
}

# Get storage free space (APFS volumes share space in same container)
# Uses decimal units (1000-based: KB/MB/GB/TB) like macOS Finder
get_storage_free_space() {
    local target_path="${1:-$HOME}"  # Default to home directory if no path provided
    
    # Get free space in KB, then convert to bytes and use our bytes_to_human function
    local free_kb=$(/bin/df -k "$target_path" 2>/dev/null | /usr/bin/tail -1 | /usr/bin/awk '{print $4}')
    
    if [[ -z "$free_kb" ]] || [[ ! "$free_kb" =~ ^[0-9]+$ ]]; then
        echo "不明"
        return
    fi
    
    local free_bytes=$((free_kb * 1024))
    bytes_to_human "$free_bytes"
}

# Get external drive free space using PlayCover volume
get_external_drive_free_space() {
    # Always use PlayCover volume mount point to get external drive free space
    # This is more reliable than checking individual app volumes
    
    # Check if PlayCover volume exists
    if ! volume_exists "$PLAYCOVER_VOLUME_NAME"; then
        get_storage_free_space "$HOME"
        return
    fi
    
    # Get PlayCover volume mount point
    local playcover_mount=$(get_mount_point "$PLAYCOVER_VOLUME_NAME")
    
    if [[ -z "$playcover_mount" ]]; then
        # Not mounted, use home directory space
        get_storage_free_space "$HOME"
        return
    fi
    
    # Get free space from PlayCover volume mount point using df -H
    get_storage_free_space "$playcover_mount"
}

#######################################################
# Storage Type Detection
#######################################################

# CRITICAL FIX (v1.5.12): Renamed 'path' to 'container_path' to avoid zsh conflict
# zsh has a special 'path' array variable that syncs with PATH environment variable
get_storage_type() {
    local container_path=$1
    local debug=${2:-false}
    
    # If path doesn't exist, return unknown
    if [[ ! -e "$container_path" ]]; then
        [[ "$debug" == "true" ]] && echo "[DEBUG] Path does not exist: $container_path" >&2
        echo "unknown"
        return
    fi
    
    # CRITICAL: First check if this path is a mount point for an APFS volume
    # This is the most reliable way to detect external storage
    local mount_check=$(/sbin/mount | /usr/bin/grep " on ${container_path} ")
    if [[ -n "$mount_check" ]] && [[ "$mount_check" =~ "apfs" ]]; then
        # This path is mounted as an APFS volume = external storage
        [[ "$debug" == "true" ]] && echo "[DEBUG] Detected as mount point (external)" >&2
        echo "external"
        return
    fi
    
    # If it's a directory but not a mount point, check if it has content
    if [[ -d "$container_path" ]]; then
        # Ignore macOS metadata files when checking for content
        # Note: Do NOT exclude flag file here - that's handled in get_storage_mode()
        # Use /bin/ls -A1 to ensure one item per line (not multi-column output)
        local content_check=$(/bin/ls -A1 "$container_path" 2>/dev/null | /usr/bin/grep -v -x -F '.DS_Store' | /usr/bin/grep -v -x -F '.Spotlight-V100' | /usr/bin/grep -v -x -F '.Trashes' | /usr/bin/grep -v -x -F '.fseventsd' | /usr/bin/grep -v -x -F '.TemporaryItems' | /usr/bin/grep -v -F '.com.apple.containermanagerd.metadata.plist')
        [[ "$debug" == "true" ]] && echo "[DEBUG] Content check (filtered): '$content_check'" >&2
        [[ "$debug" == "true" ]] && echo "[DEBUG] Content length: ${#content_check}" >&2
        
        if [[ -z "$content_check" ]]; then
            # Directory exists but is empty (or only has metadata) = no actual data
            # This is just an empty mount point directory left after unmount
            [[ "$debug" == "true" ]] && echo "[DEBUG] Directory is empty or only has metadata (none)" >&2
            echo "none"
            return
        else
            [[ "$debug" == "true" ]] && echo "[DEBUG] Directory has actual content, checking disk location..." >&2
        fi
    fi
    
    # If not a mount point and has content, it's a regular directory on some disk
    # Get the device info for the filesystem containing this path
    local device=$(/bin/df "$container_path" | /usr/bin/tail -1 | /usr/bin/awk '{print $1}')
    local disk_id=$(echo "$device" | /usr/bin/sed -E 's|/dev/(disk[0-9]+).*|\1|')
    
    [[ "$debug" == "true" ]] && echo "[DEBUG] Device: $device, Disk ID: $disk_id" >&2
    
    # Check the disk location
    local disk_location=$(get_disk_location "/dev/$disk_id")
    
    [[ "$debug" == "true" ]] && echo "[DEBUG] Disk location: $disk_location" >&2
    
    if [[ "$disk_location" == "Internal" ]]; then
        echo "internal"
    elif [[ "$disk_location" == "External" ]]; then
        echo "external"
    else
        # Fallback: check if it's on the main system disk (disk0 or disk1 usually)
        if [[ "$disk_id" == "disk0" ]] || [[ "$disk_id" == "disk1" ]] || [[ "$disk_id" == "disk3" ]]; then
            [[ "$debug" == "true" ]] && echo "[DEBUG] Fallback to internal (system disk)" >&2
            echo "internal"
        else
            [[ "$debug" == "true" ]] && echo "[DEBUG] Fallback to external (non-system disk)" >&2
            echo "external"
        fi
    fi
}

#######################################################
# Internal Storage Flag Management
#######################################################

# Check if internal storage flag exists
has_internal_storage_flag() {
    local container_path=$1
    
    if [[ -f "${container_path}/${INTERNAL_STORAGE_FLAG}" ]]; then
        return 0  # Flag exists
    else
        return 1  # Flag does not exist
    fi
}

# Create internal storage flag (when switching to internal)
create_internal_storage_flag() {
    local container_path=$1
    
    # Create flag file with timestamp
    echo "Switched to internal storage at: $(date)" > "${container_path}/${INTERNAL_STORAGE_FLAG}"
    
    if [[ $? -eq 0 ]]; then
        return 0
    else
        print_error "内蔵ストレージフラグの作成に失敗しました"
        return 1
    fi
}

# Remove internal storage flag (when switching back to external)
remove_internal_storage_flag() {
    local container_path=$1
    
    if [[ -f "${container_path}/${INTERNAL_STORAGE_FLAG}" ]]; then
        /bin/rm -f "${container_path}/${INTERNAL_STORAGE_FLAG}"
        
        if [[ $? -eq 0 ]]; then
            return 0
        else
            print_error "内蔵ストレージフラグの削除に失敗しました"
            return 1
        fi
    fi
    
    return 0  # Flag doesn't exist, nothing to remove
}

#######################################################
# Storage Mode Detection
#######################################################

# Get storage mode (intentional internal vs contamination)
# Enhanced: Check external volume mount status first to avoid misdetection
get_storage_mode() {
    local container_path=$1
    local volume_name=$2  # Optional: volume name for mount status check
    
    # If volume name is provided, check external volume mount status first
    if [[ -n "$volume_name" ]]; then
        if volume_exists "$volume_name"; then
            local current_mount=$(get_mount_point "$volume_name")
            
            if [[ -n "$current_mount" ]]; then
                # External volume is mounted somewhere
                if [[ "$current_mount" == "$container_path" ]]; then
                    echo "external"  # Correctly mounted at target location
                else
                    echo "external_wrong_location"  # Mounted at wrong location
                fi
                return 0
            fi
        fi
    fi
    
    # External volume not mounted, check internal storage
    local storage_type=$(get_storage_type "$container_path")
    
    case "$storage_type" in
        "external")
            echo "external"
            ;;
        "internal")
            # Check if has actual data or just flag file
            # Exclude metadata AND flag file to determine if real data exists
            local content_check=$(/bin/ls -A1 "$container_path" 2>/dev/null | /usr/bin/grep -v -x -F '.DS_Store' | /usr/bin/grep -v -F '.com.apple.containermanagerd.metadata.plist' | /usr/bin/grep -v -x -F "${INTERNAL_STORAGE_FLAG}")
            
            if [[ -z "$content_check" ]]; then
                # Only flag file (and/or metadata) exists, no real data
                if has_internal_storage_flag "$container_path"; then
                    # Flag exists = intentional internal mode, but empty
                    echo "internal_intentional_empty"
                else
                    # No flag, no data = truly empty
                    echo "none"
                fi
            elif has_internal_storage_flag "$container_path"; then
                # Has flag + actual data = intentional internal storage
                echo "internal_intentional"
            else
                # Has data but no flag = unintended contamination
                echo "internal_contaminated"
            fi
            ;;
        "none")
            # Directory is empty, but check if flag file exists
            if has_internal_storage_flag "$container_path"; then
                # Flag file exists without data - intentional internal mode (empty)
                echo "internal_intentional_empty"
            else
                echo "none"
            fi
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

#######################################################
# Storage Switching Functions
#######################################################

switch_storage_location() {
    while true; do
        clear
        print_header "ストレージ切替（内蔵⇄外部）"
        
        local mappings_content=$(read_mappings)
        
        if [[ -z "$mappings_content" ]]; then
            show_error_and_return "ストレージ切替（内蔵⇄外部）" "$MSG_NO_REGISTERED_VOLUMES"
            return
        fi
        
        # Display volume list with storage type and mount status
        echo "${BOLD}データ位置情報${NC}"
        echo ""
        
        declare -a mappings_array=()
        local index=1
        while IFS=$'\t' read -r volume_name bundle_id display_name; do
            if [[ "$bundle_id" == "$PLAYCOVER_BUNDLE_ID" ]]; then
                continue
            fi
            
            mappings_array+=("${volume_name}|${bundle_id}|${display_name}")
            
            local target_path="${HOME}/Library/Containers/${bundle_id}"
            
            # Get storage mode (includes flag check and external volume mount status)
            local storage_mode=$(get_storage_mode "$target_path" "$volume_name")
            
            # Get container size and free space
            local container_size=$(get_container_size "$target_path")
            local free_space=""
            local location_text=""
            local usage_text=""
            
            case "$storage_mode" in
                "external")
                    location_text="${BOLD}${BLUE}🔌 外部ストレージモード${NC}"
                    free_space=$(get_external_drive_free_space "$volume_name")
                    usage_text="${BOLD}${WHITE}${container_size}${NC} ${GRAY}/${NC} ${LIGHT_GRAY}残容量:${NC} ${BOLD}${WHITE}${free_space}${NC}"
                    ;;
                "external_wrong_location")
                    location_text="${BOLD}${ORANGE}⚠️  マウント位置異常（外部）${NC}"
                    local current_mount=$(get_mount_point "$volume_name")
                    free_space=$(get_external_drive_free_space "$volume_name")
                    usage_text="${BOLD}${WHITE}${container_size}${NC} ${GRAY}|${NC} ${ORANGE}誤ったマウント位置:${NC} ${DIM_GRAY}${current_mount}${NC}"
                    ;;
                "internal_intentional")
                    location_text="${BOLD}${GREEN}🏠 内蔵ストレージモード${NC}"
                    free_space=$(get_storage_free_space "$HOME")
                    usage_text="${BOLD}${WHITE}${container_size}${NC} ${GRAY}/${NC} ${LIGHT_GRAY}残容量:${NC} ${BOLD}${WHITE}${free_space}${NC}"
                    ;;
                "internal_intentional_empty")
                    location_text="${BOLD}${GREEN}🏠 内蔵ストレージモード${NC}"
                    free_space=$(get_storage_free_space "$HOME")
                    usage_text="${GRAY}0B${NC} ${GRAY}/${NC} ${LIGHT_GRAY}残容量:${NC} ${BOLD}${WHITE}${free_space}${NC}"
                    ;;
                "internal_contaminated")
                    location_text="${BOLD}${ORANGE}⚠️  内蔵データ検出${NC}"
                    free_space=$(get_storage_free_space "$HOME")
                    usage_text="${GRAY}内蔵ストレージ残容量:${NC} ${BOLD}${WHITE}${free_space}${NC}"
                    ;;
                "none")
                    location_text="${GRAY}⚠️ データ無し${NC}"
                    usage_text="${GRAY}N/A${NC}"
                    ;;
                *)
                    location_text="${GRAY}⚠️ データ無し${NC}"
                    usage_text="${GRAY}N/A${NC}"
                    ;;
            esac
            
            # Display formatted output
            echo "  ${BOLD}${CYAN}${index}.${NC} ${BOLD}${WHITE}${display_name}${NC}"
            echo "      ${GRAY}位置:${NC} ${location_text}"
            echo "      ${GRAY}使用容量:${NC} ${usage_text}"
            echo ""
            ((index++))
        done <<< "$mappings_content"
        
        print_separator
        echo ""
        echo "${BOLD}${UNDERLINE}切り替えるアプリを選択してください${NC}"
        echo "  ${BOLD}${CYAN}[番号]${NC} : データ位置切替"
        echo "  ${BOLD}${LIGHT_GRAY}[0]${NC}    : 戻る"
        echo ""
        echo -n "${BOLD}${YELLOW}選択:${NC} "
        read choice
        
        if [[ "$choice" == "0" ]]; then
            return
        fi
        
        if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ $choice -lt 1 ]] || [[ $choice -gt ${#mappings_array} ]]; then
            print_error "$MSG_INVALID_SELECTION"
            /bin/sleep 2
            continue
        fi
        
        # zsh arrays are 1-indexed, so choice can be used directly
        local selected_mapping="${mappings_array[$choice]}"
        IFS='|' read -r volume_name bundle_id display_name <<< "$selected_mapping"
        
        echo ""
        print_header "${display_name} のストレージ切替"
        
        local target_path="${HOME}/Library/Containers/${bundle_id}"
        
        # Check current storage mode (enhanced with external volume mount check)
        local storage_mode=$(get_storage_mode "$target_path" "$volume_name")
        
        # Handle external volume mounted at wrong location
        if [[ "$storage_mode" == "external_wrong_location" ]]; then
            clear
            print_header "${display_name} のストレージ切替"
            echo ""
            print_error "外部ボリュームが誤った位置にマウントされています"
            echo ""
            local current_mount=$(get_mount_point "$volume_name")
            echo "${BOLD}現在のマウント位置:${NC}"
            echo "  ${DIM_GRAY}${current_mount}${NC}"
            echo ""
            echo "${BOLD}正しいマウント位置:${NC}"
            echo "  ${DIM_GRAY}${target_path}${NC}"
            echo ""
            print_info "ストレージ切替を実行する前に、正しい位置に再マウントしてください"
            echo ""
            echo "${BOLD}推奨される操作:${NC}"
            echo "  ${LIGHT_GREEN}1.${NC} ボリューム管理 → 個別ボリューム操作 → 再マウント"
            echo "  ${LIGHT_GREEN}2.${NC} または、全ボリュームをマウント（自動修正）"
            echo ""
            wait_for_enter
            continue
        fi
        
        # Convert storage_mode to legacy storage_type for compatibility
        local current_storage="unknown"
        case "$storage_mode" in
            "external")
                current_storage="external"
                ;;
            "internal_intentional"|"internal_intentional_empty"|"internal_contaminated")
                current_storage="internal"
                ;;
            "none")
                current_storage="none"
                ;;
        esac
        
        # Get current size (both human-readable and bytes)
        local current_size=$(get_container_size "$target_path")
        local current_size_bytes=$(get_container_size_bytes "$target_path")
        
        echo "${BOLD}${UNDERLINE}${CYAN}現在のデータ位置${NC}"
        case "$current_storage" in
            "internal")
                local internal_free=$(get_storage_free_space "$HOME")
                echo "  ${BOLD}🏠 ${CYAN}内蔵ストレージ${NC}"
                echo "     ${LIGHT_GRAY}使用容量:${NC} $(get_container_size_styled "$target_path") ${GRAY}/${NC} ${LIGHT_GRAY}残容量:${NC} ${BOLD}${WHITE}${internal_free}${NC}"
                ;;
            "external")
                local external_free=$(get_external_drive_free_space "$volume_name")
                echo "  ${BOLD}🔌 ${CYAN}外部ストレージ${NC}"
                echo "     ${LIGHT_GRAY}使用容量:${NC} $(get_container_size_styled "$target_path") ${GRAY}/${NC} ${LIGHT_GRAY}残容量:${NC} ${BOLD}${WHITE}${external_free}${NC}"
                ;;
            *)
                echo "  ${GRAY}❓ 不明 / データなし${NC}"
                ;;
        esac
        echo ""
        
        # Determine target action and show appropriate free space
        local action=""
        local storage_free=""
        local storage_free_bytes=0
        local storage_location=""
        
        case "$current_storage" in
            "internal")
                action="external"
                # Moving to external - show external drive free space for the target volume
                storage_free=$(get_external_drive_free_space "$volume_name")
                storage_location="外部ドライブ"
                
                # Get mount point of the target app volume (not PlayCover volume) to check capacity
                local volume_mount=$(get_mount_point "$volume_name")
                if [[ -n "$volume_mount" ]]; then
                    # Target volume is mounted, get its free space
                    storage_free_bytes=$(get_storage_free_space_bytes "$volume_mount")
                else
                    # Volume not mounted, assume sufficient space (will be verified during actual operation)
                    # Set to a large value to skip capacity warning
                    storage_free_bytes=999999999999
                fi
                
                echo "${BOLD}${UNDERLINE}${CYAN}実行する操作:${NC} ${BOLD}${GREEN}🏠内蔵${NC} ${BOLD}${YELLOW}→${NC} ${BOLD}${BLUE}🔌外部${NC} ${LIGHT_GRAY}へ移動${NC}"
                echo "  ${BOLD}🔌${CYAN}外部ストレージ残容量:${NC} ${BOLD}${WHITE}${storage_free}${NC}"
                ;;
            "external")
                action="internal"
                # Moving to internal - show internal drive free space
                storage_free=$(get_storage_free_space "$HOME")
                storage_location="内蔵ドライブ"
                storage_free_bytes=$(get_storage_free_space_bytes "$HOME")
                
                echo "${BOLD}${UNDERLINE}${CYAN}実行する操作:${NC} ${BOLD}${BLUE}🔌外部${NC} ${BOLD}${YELLOW}→${NC} ${BOLD}${GREEN}🏠内蔵${NC} ${LIGHT_GRAY}へ移動${NC}"
                echo "  ${BOLD}🏠${CYAN}内蔵ストレージ残容量:${NC} ${BOLD}${WHITE}${storage_free}${NC}"
                ;;
            "none")
                print_error "ストレージ切り替えを実行できません"
                echo ""
                echo "理由: データが存在しません（未マウント）"
                echo ""
                echo "推奨される操作:"
                echo "  ${LIGHT_GREEN}1.${NC} メインメニューのオプション3で外部ボリュームをマウント"
                echo "  ${LIGHT_GREEN}2.${NC} その後、このストレージ切り替え機能を使用"
                wait_for_enter
                continue
                ;;
            *)
                print_error "現在のストレージ状態を判定できません"
                echo ""
                echo "考えられる原因:"
                echo "  - アプリがまだインストールされていない"
                echo "  - データディレクトリが存在しない"
                wait_for_enter
                continue
                ;;
        esac
        
        # Check if there's enough space (with 10% safety margin)
        local required_bytes=$((current_size_bytes + current_size_bytes / 10))
        if [[ $storage_free_bytes -lt $required_bytes ]] && [[ $storage_free_bytes -gt 0 ]]; then
            echo ""
            echo "${BOLD}${RED}════════════════════════════════════════════════════${NC}"
            print_error "警告: 移行先の容量が不足している可能性があります"
            echo "${BOLD}${RED}════════════════════════════════════════════════════${NC}"
            echo ""
            echo "  ${LIGHT_GRAY}必要容量:${NC} ${BOLD}${WHITE}${current_size}${NC} ${LIGHT_GRAY}+ 10% 安全余裕${NC}"
            echo "  ${LIGHT_GRAY}利用可能:${NC} ${BOLD}${WHITE}${storage_free}${NC}"
            echo ""
            echo "${BOLD}${RED}⚠️  続行するとデータ破損のリスクがあります${NC}"
        fi
        
        echo ""
        print_warning "この操作には時間がかかる場合があります"
        echo ""
        
        if ! prompt_confirmation "${BOLD}${YELLOW}続行しますか？${NC}" "Y"; then
            print_info "$MSG_CANCELED"
            wait_for_enter "Enterキーで続行..."
            continue
        fi
        
        # Authenticate sudo only when actually needed (before mount/copy operations)
        authenticate_sudo
        
        echo ""
        
        if [[ "$action" == "external" ]]; then
            # ═══════════════════════════════════════════════════════
            # Internal -> External Migration
            # ═══════════════════════════════════════════════════════
            perform_internal_to_external_migration "$volume_name" "$bundle_id" "$display_name" "$target_path"
        else
            # ═══════════════════════════════════════════════════════
            # External -> Internal Migration
            # ═══════════════════════════════════════════════════════
            perform_external_to_internal_migration "$volume_name" "$bundle_id" "$display_name" "$target_path"
        fi
        
        wait_for_enter
    done  # End of while true loop
}

#######################################################
# Migration Helper Functions
#######################################################

# Internal -> External migration logic
# This is extracted to improve readability and maintainability
perform_internal_to_external_migration() {
    local volume_name=$1
    local bundle_id=$2
    local display_name=$3
    local target_path=$4
    
    print_info "内蔵から外部ストレージへデータを移行中..."
    
    # Check if volume exists
    if ! check_volume_exists_or_error "$volume_name" "${display_name} のストレージ切替"; then
        return 1
    fi
    
    # Determine correct source path
    local source_path="$target_path"
    
    # Validate source path exists
    if [[ ! -d "$source_path" ]]; then
        print_error "コピー元が存在しません: $source_path"
        return 1
    fi
    
    # Check container structure
    if [[ -d "$source_path/Data" ]] && [[ -f "$source_path/.com.apple.containermanagerd.metadata.plist" ]]; then
        # Normal container structure - use as-is
        print_info "内蔵ストレージからコピーします: $source_path"
    else
        # Check for empty source (only flag file exists)
        local content_check=$(/bin/ls -A1 "$source_path" 2>/dev/null | /usr/bin/grep -v -x -F '.DS_Store' | /usr/bin/grep -v -F '.com.apple.containermanagerd.metadata.plist' | /usr/bin/grep -v -x -F "${INTERNAL_STORAGE_FLAG}")
        
        if [[ -z "$content_check" ]]; then
            # Only flag file exists, no actual data
            print_info "空のボリューム検出: 実データなし（フラグファイルのみ）"
            print_info "内蔵ストレージをクリーンアップして外部ボリュームをマウントします"
            echo ""
            
            # Check if external volume is mounted at wrong location
            local current_mount=$(get_mount_point "$volume_name")
            if [[ -n "$current_mount" ]] && [[ "$current_mount" != "$target_path" ]]; then
                print_info "外部ボリュームが誤った位置にマウントされています: ${current_mount}"
                print_info "正しい位置に再マウントするため、一度アンマウントします"
                unmount_app_volume "$volume_name" "$bundle_id" || true
                /bin/sleep 1
            fi
            
            # Remove internal flag and directory
            remove_internal_storage_flag "$source_path"
            /usr/bin/sudo /bin/rm -rf "$source_path"
            
            # Now mount to correct location
            print_info "外部ボリュームを正しい位置にマウント中..."
            if mount_app_volume "$volume_name" "$target_path" "$bundle_id"; then
                echo ""
                print_success "外部ストレージへの切り替えが完了しました"
                print_info "保存場所: ${target_path}"
                remove_internal_storage_flag "$target_path"
            else
                print_error "$MSG_MOUNT_FAILED"
            fi
            
            return 0
        fi
    fi
    
    # Check disk space before migration
    print_info "転送前の容量チェック中..."
    local source_size_bytes=$(get_container_size_bytes "$source_path")
    
    # Special handling for empty source (0 bytes)
    if [[ -z "$source_size_bytes" ]] || [[ "$source_size_bytes" -eq 0 ]]; then
        print_warning "コピー元が空です（0バイト）"
        print_info "空のディレクトリを外部ボリュームにマウントします"
        echo ""
        
        # Remove internal data (empty directory)
        /usr/bin/sudo /bin/rm -rf "$target_path"
        
        # Mount external volume directly
        print_info "外部ボリュームをマウント中..."
        if mount_app_volume "$volume_name" "$target_path" "$bundle_id"; then
            echo ""
            print_success "外部ストレージへの切り替えが完了しました"
            print_info "保存場所: ${target_path}"
            remove_internal_storage_flag "$target_path"
        else
            print_error "$MSG_MOUNT_FAILED"
        fi
        
        return 0
    fi
    
    # Get available space on external volume (mount temporarily to check)
    local volume_device=$(get_volume_device "$volume_name")
    
    if [[ -z "$volume_device" ]]; then
        print_error "外部ボリュームのデバイス情報が取得できませんでした"
        echo ""
        print_info "デバッグ情報:"
        echo "  ボリューム名: $volume_name"
        return 1
    fi
    
    print_info "外部ボリューム: $volume_device"
    
    local temp_check_mount="/tmp/playcover_check_$$"
    /usr/bin/sudo /bin/mkdir -p "$temp_check_mount"
    
    # Check if volume is already mounted
    local existing_mount=$(get_volume_mount_point "$volume_device")
    local available_bytes=0
    local mount_cleanup_needed=false
    
    if [[ -n "$existing_mount" ]] && [[ "$existing_mount" != "Not applicable (no file system)" ]]; then
        # Volume already mounted - need to unmount it first for fresh mount later
        print_info "外部ボリュームは既にマウントされています: $existing_mount"
        local available_kb=$(get_available_space "$existing_mount")
        available_bytes=$((available_kb * 1024))
        mount_cleanup_needed=true
    else
        # Volume not mounted - mount it temporarily for capacity check
        print_info "外部ボリュームをマウント中..."
        if /usr/bin/sudo /sbin/mount -t apfs -o nobrowse,rdonly "$volume_device" "$temp_check_mount" 2>/dev/null; then
            print_success "マウント成功"
            local available_kb=$(get_available_space "$temp_check_mount")
            available_bytes=$((available_kb * 1024))
            existing_mount="$temp_check_mount"
            mount_cleanup_needed=true
        else
            print_error "外部ボリュームのマウントに失敗しました"
            echo ""
            print_info "デバッグ情報:"
            echo "  デバイス: $volume_device"
            echo "  マウントポイント: $temp_check_mount"
            echo ""
            print_info "考えられる原因:"
            echo "  - ボリュームが破損している"
            echo "  - ディスクが接続されていない"
            echo "  - 権限の問題"
            cleanup_temp_dir "$temp_check_mount" true
            return 1
        fi
    fi
    
    # Cleanup: Unmount after capacity check for clean state
    if [[ "$mount_cleanup_needed" == true ]]; then
        print_info "容量チェック完了、一時マウントをクリーンアップ中..."
        unmount_volume "$existing_mount" "silent"
        /bin/sleep 1
    fi
    cleanup_temp_dir "$temp_check_mount" true
    
    # Calculate required space with 10% safety margin
    local required_bytes=$((source_size_bytes * 110 / 100))
    
    # Convert to human-readable format (decimal/1000-based like macOS Finder)
    local source_size_human=$(bytes_to_human "$source_size_bytes")
    local available_human=$(bytes_to_human "$available_bytes")
    local required_human=$(bytes_to_human "$required_bytes")
    
    echo ""
    print_info "容量チェック結果:"
    echo "  コピー元サイズ: ${source_size_human}"
    echo "  転送先空き容量: ${available_human}"
    echo "  必要容量（余裕込み）: ${required_human}"
    echo ""
    
    if [[ $available_bytes -lt $required_bytes ]]; then
        print_error "容量不足: 転送先の空き容量が不足しています"
        echo ""
        local shortage_bytes=$((required_bytes - available_bytes))
        local shortage_human=$(bytes_to_human "$shortage_bytes")
        echo "不足分: ${shortage_human}"
        echo ""
        print_warning "このまま続行すると、転送が中途半端に終了する可能性があります"
        echo ""
        if ! prompt_confirmation "それでも続行しますか？" "y/N"; then
            print_info "$MSG_CANCELED"
            return 1
        fi
        
        print_warning "容量不足を承知で続行します..."
        echo ""
    else
        print_success "容量チェック: OK（十分な空き容量があります）"
        echo ""
    fi
    
    # Unmount if already mounted
    local current_mount=$(get_mount_point "$volume_name")
    if [[ -n "$current_mount" ]]; then
        print_info "既存のマウントをアンマウント中..."
        unmount_app_volume "$volume_name" "$bundle_id" || true
        /bin/sleep 1
    fi
    
    # Create temporary mount point
    local temp_mount="/tmp/playcover_temp_$$"
    /usr/bin/sudo /bin/mkdir -p "$temp_mount"
    
    # Mount volume temporarily (with nobrowse to hide from Finder)
    local volume_device=$(get_volume_device "$volume_name")
    print_info "ボリュームを一時マウント中..."
    if ! /usr/bin/sudo /sbin/mount -t apfs -o nobrowse "$volume_device" "$temp_mount"; then
        print_error "$MSG_MOUNT_FAILED"
        cleanup_temp_dir "$temp_mount" true
        return 1
    fi
    
    # Debug: Show source path and content
    print_info "コピー元: ${source_path}"
    local file_count=$(/usr/bin/find "$source_path" -type f 2>/dev/null | wc -l | /usr/bin/xargs)
    local total_size=$(get_container_size "$source_path")
    print_info "  ファイル数: ${file_count}"
    print_info "  データサイズ: ${total_size}"
    
    # Copy data from internal to external (differential sync with deletion)
    print_info "データを同期転送中... (進捗が表示されます)"
    echo ""
    print_info "💡 同期モード: 削除されたファイルも反映、同一ファイルはスキップ"
    echo ""
    
    # Use rsync with --delete for proper sync (like game client updates)
    # - Files modified/added: transferred
    # - Files deleted at source: deleted at destination
    # - Files unchanged (same size & mtime): skipped (no write)
    # This matches game distribution platforms' update behavior
    # Exclude system metadata files and backup directories
    # Note: macOS rsync doesn't support --info=progress2, use --progress instead
    /usr/bin/sudo /usr/bin/rsync -avH --delete --progress \
        --exclude='.Spotlight-V100' \
        --exclude='.fseventsd' \
        --exclude='.Trashes' \
        --exclude='.TemporaryItems' \
        --exclude='.DS_Store' \
        --exclude='.playcover_backup_*' \
        "$source_path/" "$temp_mount/"
    local rsync_exit=$?
    
    if [[ $rsync_exit -eq 0 ]] || [[ $rsync_exit -eq 23 ]] || [[ $rsync_exit -eq 24 ]]; then
        echo ""
        print_success "データのコピーが完了しました"
        
        local copied_count=$(/usr/bin/find "$temp_mount" -type f 2>/dev/null | wc -l | /usr/bin/xargs)
        local copied_size=$(get_container_size "$temp_mount")
        print_info "  コピー完了: ${copied_count} ファイル (${copied_size})"
    else
        echo ""
        print_error "データのコピーに失敗しました"
        print_info "一時マウントをクリーンアップ中..."
        unmount_with_fallback "$temp_mount" "silent" || true
        /bin/sleep 1  # Wait for unmount to complete
        cleanup_temp_dir "$temp_mount" true
        return 1
    fi
    
    # Unmount temporary mount
    print_info "一時マウントをアンマウント中..."
    unmount_with_fallback "$temp_mount" "verbose"
    /bin/sleep 1  # Wait for unmount to complete
    cleanup_temp_dir "$temp_mount" true
    
    # Delete internal data completely (no backup needed)
    print_info "内蔵データを完全削除中..."
    /usr/bin/sudo /bin/rm -rf "$target_path"
    
    # Ensure directory is completely gone before mounting
    # This prevents macOS from auto-creating container structure
    if [[ -d "$target_path" ]]; then
        print_warning "ディレクトリが残っています、再削除を試みます..."
        /usr/bin/sudo /bin/rm -rf "$target_path"
        /bin/sleep 0.5
    fi
    
    # Mount volume to proper location
    print_info "ボリュームを正式にマウント中..."
    if mount_app_volume "$volume_name" "$target_path" "$bundle_id"; then
        echo ""
        print_success "外部ストレージへの切り替えが完了しました"
        print_info "保存場所: ${target_path}"
        
        # Verify mount success and no leftover internal data
        if /sbin/mount | grep -q " on ${target_path} "; then
            print_success "マウント検証: OK"
        else
            print_warning "マウント検証: 警告 - マウント状態を確認できません"
        fi
        
        # Explicitly remove internal storage flag to prevent false lock status
        # This is critical because mount_volume creates the directory,
        # and any remaining flag file would cause misdetection
        remove_internal_storage_flag "$target_path"
    else
        print_error "$MSG_MOUNT_FAILED"
        
        # Cleanup any leftover directory created by failed mount
        if [[ -d "$target_path" ]]; then
            print_info "失敗したマウントのクリーンアップ中..."
            /usr/bin/sudo /bin/rm -rf "$target_path"
        fi
    fi
    
    return 0
}

# External -> Internal migration logic
perform_external_to_internal_migration() {
    local volume_name=$1
    local bundle_id=$2
    local display_name=$3
    local target_path=$4
    
    print_info "外部から内蔵ストレージへデータを移行中..."
    
    # Check if volume exists
    if ! check_volume_exists_or_error "$volume_name" "${display_name} のストレージ切替"; then
        return 1
    fi
    
    # Check if app is running before migration
    if is_app_running "$bundle_id"; then
        print_error "アプリが実行中です"
        print_info "アプリを終了してから再度お試しください"
        return 1
    fi
    
    # Check disk space before migration
    print_info "転送前の容量チェック中..."
    
    # Mount volume temporarily to check size (if not already mounted)
    local current_mount=$(get_mount_point "$volume_name")
    local temp_check_mount=""
    local check_mount_point=""
    
    if [[ -n "$current_mount" ]]; then
        check_mount_point="$current_mount"
    else
        temp_check_mount="/tmp/playcover_check_$$"
        /usr/bin/sudo /bin/mkdir -p "$temp_check_mount"
        local volume_device=$(get_volume_device "$volume_name")
        
        # Ensure device has /dev/ prefix
        if [[ ! "$volume_device" =~ ^/dev/ ]]; then
            volume_device="/dev/$volume_device"
        fi
        
        if ! /usr/bin/sudo /sbin/mount -t apfs -o nobrowse,rdonly "$volume_device" "$temp_check_mount" 2>/dev/null; then
            print_error "外部ボリュームの容量チェックに失敗しました"
            /usr/bin/sudo /bin/rm -rf "$temp_check_mount"
            return 1
        fi
        check_mount_point="$temp_check_mount"
    fi
    
    # Get directory size (no sudo needed - du can read mounted volumes)
    local source_size_kb=$(get_directory_size "$check_mount_point")
    # Convert from df's 1024-based KB to actual bytes, then use decimal (1000-based) units
    local source_size_bytes=$((source_size_kb * 1024))
    
    # Unmount temporary check mount if created
    if [[ -n "$temp_check_mount" ]]; then
        unmount_volume "$temp_check_mount" "silent"
        cleanup_temp_dir "$temp_check_mount" true
    fi
    
    # Special handling for empty source (0 bytes or failed to get size)
    if [[ -z "$source_size_bytes" ]] || [[ "$source_size_bytes" -eq 0 ]]; then
        print_warning "外部ボリュームが空です（0バイト）"
        print_info "空のデータを内蔵ストレージにコピーします"
        echo ""
        
        # Create empty internal directory
        /usr/bin/sudo /bin/mkdir -p "$target_path"
        /usr/bin/sudo /usr/sbin/chown -R $(id -u):$(id -g) "$target_path"
        
        # Unmount external volume
        print_info "外部ボリュームをアンマウント中..."
        if ! unmount_app_volume "$volume_name" "$bundle_id"; then
            print_error "外部ボリュームのアンマウントに失敗しました"
            print_warning "空ディレクトリは作成されましたが、外部ボリュームがまだマウントされています"
            print_info "手動でアンマウントしてから、再度ストレージ切替を実行してください"
            return 1
        fi
        
        echo ""
        print_success "内蔵ストレージへの切り替えが完了しました（空ディレクトリ作成）"
        print_info "保存場所: ${target_path}"
        
        # Create internal storage flag (only after successful unmount)
        if create_internal_storage_flag "$target_path"; then
            print_info "内蔵ストレージモードフラグを作成しました"
        fi
        
        return 0
    fi
    
    # Get available space on internal disk (where target_path will be created)
    local internal_disk_path=$(dirname "$target_path")
    # If parent doesn't exist, check its parent
    while [[ ! -d "$internal_disk_path" ]] && [[ "$internal_disk_path" != "/" ]]; do
        internal_disk_path=$(dirname "$internal_disk_path")
    done
    
    local available_kb=$(get_available_space "$internal_disk_path")
    # Convert from df's 1024-based KB to actual bytes
    local available_bytes=$((available_kb * 1024))
    
    # Calculate required space with 10% safety margin
    local required_bytes=$((source_size_bytes * 110 / 100))
    
    # Convert to human-readable format (decimal/1000-based like macOS Finder)
    local source_size_human=$(bytes_to_human "$source_size_bytes")
    local available_human=$(bytes_to_human "$available_bytes")
    local required_human=$(bytes_to_human "$required_bytes")
    
    echo ""
    print_info "容量チェック結果:"
    echo "  コピー元サイズ: ${source_size_human}"
    echo "  転送先空き容量: ${available_human}"
    echo "  必要容量（余裕込み）: ${required_human}"
    echo ""
    
    if [[ $available_bytes -lt $required_bytes ]]; then
        print_error "容量不足: 転送先の空き容量が不足しています"
        echo ""
        local shortage_bytes=$((required_bytes - available_bytes))
        local shortage_human=$(bytes_to_human "$shortage_bytes")
        echo "不足分: ${shortage_human}"
        echo ""
        print_warning "このまま続行すると、転送が中途半端に終了する可能性があります"
        echo ""
        if ! prompt_confirmation "それでも続行しますか？" "y/N"; then
            print_info "$MSG_CANCELED"
            return 1
        fi
        
        print_warning "容量不足を承知で続行します..."
        echo ""
    else
        print_success "容量チェック: OK（十分な空き容量があります）"
        echo ""
    fi
    
    # Determine current mount point
    local current_mount=$(get_mount_point "$volume_name")
    local temp_mount_created=false
    local source_mount=""
    
    if [[ -z "$current_mount" ]]; then
        # Volume not mounted - mount to temporary location
        print_info "ボリュームを一時マウント中..."
        local temp_mount="/tmp/playcover_temp_$$"
        /usr/bin/sudo /bin/mkdir -p "$temp_mount"
        local volume_device=$(get_volume_device "$volume_name")
        
        # Ensure device has /dev/ prefix
        if [[ ! "$volume_device" =~ ^/dev/ ]]; then
            volume_device="/dev/$volume_device"
        fi
        
        if ! /usr/bin/sudo /sbin/mount -t apfs -o nobrowse "$volume_device" "$temp_mount"; then
            print_error "$MSG_MOUNT_FAILED"
            /usr/bin/sudo /bin/rm -rf "$temp_mount"
            return 1
        fi
        source_mount="$temp_mount"
        temp_mount_created=true
    elif [[ "$current_mount" == "$target_path" ]]; then
        # Volume is mounted at target path - need to remount to temporary location
        print_info "外部ボリュームは ${target_path} にマウントされています"
        print_info "一時マウントポイントへ移動中..."
        
        local volume_device=$(get_volume_device "$volume_name")
        
        # Try unmount with automatic fallback
        if ! unmount_with_fallback "$target_path" "verbose"; then
            print_error "強制アンマウントも失敗しました"
            echo ""
            print_warning "このアプリが使用中の可能性があります"
            print_info "推奨される対応:"
            echo "  1. アプリが起動していないか確認"
            echo "  2. Finderでこのディレクトリを開いていないか確認"
            echo "  3. 上記を確認後、再度実行"
            echo ""
            return 1
        fi
        
        print_success "アンマウントに成功しました"
        
        /bin/sleep 1
        
        local temp_mount="/tmp/playcover_temp_$$"
        /usr/bin/sudo /bin/mkdir -p "$temp_mount"
        
        # Ensure device has /dev/ prefix
        if [[ ! "$volume_device" =~ ^/dev/ ]]; then
            volume_device="/dev/$volume_device"
        fi
        
        if ! /usr/bin/sudo /sbin/mount -t apfs -o nobrowse "$volume_device" "$temp_mount"; then
            print_error "一時マウントに失敗しました"
            /usr/bin/sudo /sbin/mount -t apfs -o nobrowse "$volume_device" "$target_path" 2>/dev/null || true
            /usr/bin/sudo /bin/rm -rf "$temp_mount"
            return 1
        fi
        source_mount="$temp_mount"
        temp_mount_created=true
    else
        # Volume is mounted elsewhere
        print_info "外部ボリュームは ${current_mount} にマウントされています"
        source_mount="$current_mount"
    fi
    
    # Debug: Show source path and content
    print_info "コピー元: ${source_mount}"
    local file_count=$(sudo /usr/bin/find "$source_mount" -type f 2>/dev/null | wc -l | /usr/bin/xargs)
    local total_size=$(get_container_size "$source_mount")
    print_info "  ファイル数: ${file_count}"
    print_info "  データサイズ: ${total_size}"
    
    # Remove existing internal data/mount point if it exists
    if [[ -e "$target_path" ]]; then
        print_info "既存データをクリーンアップ中..."
        # Remove any existing internal storage flag first to ensure clean state
        remove_internal_storage_flag "$target_path"
        /usr/bin/sudo /bin/rm -rf "$target_path" 2>/dev/null || true
    fi
    
    # Create new internal directory
    /usr/bin/sudo /bin/mkdir -p "$target_path"
    
    # Copy data from external to internal
    print_info "データをコピー中... (進捗が表示されます)"
    echo ""
    
    # Use rsync with progress for real-time progress (macOS compatible)
    # Exclude system metadata files and backup directories
    /usr/bin/sudo /usr/bin/rsync -avH --ignore-errors --progress \
        --exclude='.Spotlight-V100' \
        --exclude='.fseventsd' \
        --exclude='.Trashes' \
        --exclude='.TemporaryItems' \
        --exclude='.DS_Store' \
        --exclude='.playcover_backup_*' \
        "$source_mount/" "$target_path/"
    local rsync_exit=$?
    
    if [[ $rsync_exit -eq 0 ]] || [[ $rsync_exit -eq 23 ]] || [[ $rsync_exit -eq 24 ]]; then
        echo ""
        print_success "データのコピーが完了しました"
        
        # Change ownership first, then check without sudo
        /usr/bin/sudo /usr/sbin/chown -R $(id -u):$(id -g) "$target_path"
        
        local copied_count=$(/usr/bin/find "$target_path" -type f 2>/dev/null | wc -l | /usr/bin/xargs)
        local copied_size=$(/usr/bin/du -sh "$target_path" 2>/dev/null | /usr/bin/awk '{print $1}')
        print_info "  コピー完了: ${copied_count} ファイル (${copied_size})"
    else
        echo ""
        print_error "データのコピーに失敗しました"
        
        # Cleanup: Unmount first, then clean up directories
        if [[ "$temp_mount_created" == true ]]; then
            print_info "一時マウントをクリーンアップ中..."
            unmount_with_fallback "$source_mount" "silent" || true
            /bin/sleep 1  # Wait for unmount to complete
            /usr/bin/sudo /bin/rm -rf "$source_mount" 2>/dev/null || true
        fi
        
        # Remove failed copy
        /usr/bin/sudo /bin/rm -rf "$target_path" 2>/dev/null || true
        
        return 1
    fi
    
    # Unmount volume
    local unmount_success=true
    if [[ "$temp_mount_created" == true ]]; then
        print_info "一時マウントをクリーンアップ中..."
        if ! unmount_with_fallback "$source_mount" "silent"; then
            print_warning "一時マウントのアンマウントに失敗しました"
            unmount_success=false
        fi
        /bin/sleep 1  # Wait for unmount to complete
        cleanup_temp_dir "$source_mount" true
    else
        print_info "外部ボリュームをアンマウント中..."
        if ! unmount_app_volume "$volume_name" "$bundle_id"; then
            print_error "外部ボリュームのアンマウントに失敗しました"
            print_warning "ボリュームがまだマウントされている可能性があります"
            print_info "手動でアンマウントしてください"
            unmount_success=false
        fi
    fi
    
    # Only proceed with flag creation if unmount succeeded
    if [[ "$unmount_success" == false ]]; then
        echo ""
        print_error "アンマウント失敗のため、内蔵ストレージモードの設定を完了できませんでした"
        print_warning "データは ${target_path} にコピーされましたが、外部ボリュームがまだマウントされています"
        print_info "手動で外部ボリュームをアンマウントしてから、再度ストレージ切替を実行してください"
        return 1
    fi
    
    echo ""
    print_success "内蔵ストレージへの切り替えが完了しました"
    print_info "保存場所: ${target_path}"
    
    # Create internal storage flag to mark this as intentional (only if unmount succeeded)
    if create_internal_storage_flag "$target_path"; then
        print_info "内蔵ストレージモードフラグを作成しました"
    fi
    
    return 0
}
