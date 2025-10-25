#!/bin/zsh

#######################################################
# PlayCover Volume Manager Script
# macOS Tahoe 26.0.1 Compatible
#######################################################

# Note: set -e is NOT used here to allow graceful error handling
# and continue processing remaining volumes even if one fails

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Constants
readonly PLAYCOVER_BUNDLE_ID="io.playcover.PlayCover"
readonly PLAYCOVER_CONTAINER="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}"
readonly PLAYCOVER_VOLUME_NAME="PlayCover"
readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly MAPPING_FILE="${SCRIPT_DIR}/playcover-map.txt"

# Global variables
SUDO_AUTHENTICATED=false

#######################################################
# Utility Functions
#######################################################

print_header() {
    echo "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "${BLUE}  $1${NC}"
    echo "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_success() {
    echo "${GREEN}✓ $1${NC}"
}

print_error() {
    echo "${RED}✗ $1${NC}"
}

print_warning() {
    echo "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo "${BLUE}ℹ $1${NC}"
}

print_cyan() {
    echo "${CYAN}$1${NC}"
}

exit_with_cleanup() {
    local exit_code=$1
    local message=$2
    
    echo ""
    if [[ $exit_code -eq 0 ]]; then
        print_success "$message"
        echo ""
        print_info "3秒後にターミナルを自動で閉じます..."
        sleep 3
        osascript -e 'tell application "Terminal" to close (every window whose name contains "playcover")' & exit 0
    else
        print_error "$message"
        echo ""
        print_warning "エラーが発生しました。ログを確認してください。"
        echo ""
        echo -n "Enterキーを押すとターミナルを閉じます..."
        read
        osascript -e 'tell application "Terminal" to close (every window whose name contains "playcover")' & exit $exit_code
    fi
}

#######################################################
# Authentication
#######################################################

authenticate_sudo() {
    if ! $SUDO_AUTHENTICATED; then
        print_info "管理者パスワードを入力してください..."
        if sudo -v; then
            SUDO_AUTHENTICATED=true
            # Keep sudo alive
            (while true; do sudo -n true; sleep 50; done 2>/dev/null) &
        else
            print_error "認証に失敗しました"
            exit_with_cleanup 1 "sudo認証失敗"
        fi
    fi
}

#######################################################
# Mapping File Operations
#######################################################

check_mapping_file() {
    if [[ ! -f "$MAPPING_FILE" ]]; then
        print_error "マッピングファイルが見つかりません: ${MAPPING_FILE}"
        echo ""
        print_info "初期セットアップスクリプトを先に実行してください"
        exit_with_cleanup 1 "マッピングファイル不在"
    fi
}

# Read mapping file and return array of entries
# Format: VolumeName	BundleID	DisplayName
read_mappings() {
    local -a mappings
    while IFS=$'\t' read -r volume_name bundle_id display_name || [[ -n "$volume_name" ]]; do
        # Skip empty lines and PlayCover main volume
        if [[ -z "$volume_name" ]] || [[ "$volume_name" == "$PLAYCOVER_VOLUME_NAME" ]]; then
            continue
        fi
        mappings+=("${volume_name}|${bundle_id}|${display_name}")
    done < "$MAPPING_FILE"
    echo "${mappings[@]}"
}

# Remove mapping entry from file
remove_mapping() {
    local volume_name=$1
    local bundle_id=$2
    
    # Create backup
    cp "$MAPPING_FILE" "${MAPPING_FILE}.bak"
    
    # Remove the line
    sed -i.tmp "/^${volume_name}[[:space:]]${bundle_id}[[:space:]]/d" "$MAPPING_FILE"
    rm -f "${MAPPING_FILE}.tmp"
    
    print_success "マッピングを削除しました: ${volume_name}"
}

#######################################################
# Volume Operations
#######################################################

# Check if volume exists
volume_exists() {
    local volume_name=$1
    diskutil info "${volume_name}" >/dev/null 2>&1
    return $?
}

# Get volume device node
get_volume_device() {
    local volume_name=$1
    diskutil info "${volume_name}" 2>/dev/null | /usr/bin/grep "Device Node:" | /usr/bin/awk '{print $NF}'
}

# Get current mount point of volume
get_mount_point() {
    local volume_name=$1
    local mount_point=$(diskutil info "${volume_name}" 2>/dev/null | /usr/bin/grep "Mount Point:" | /usr/bin/sed 's/.*: *//')
    if [[ "$mount_point" == "Not applicable (no file system)" ]] || [[ -z "$mount_point" ]]; then
        echo ""
    else
        echo "$mount_point"
    fi
}

# Mount volume to specified path
mount_volume() {
    local volume_name=$1
    local bundle_id=$2
    local display_name=$3
    local target_path="${HOME}/Library/Containers/${bundle_id}"
    
    # Check if volume exists
    if ! volume_exists "$volume_name"; then
        print_error "ボリュームが見つかりません: ${volume_name}"
        return 1
    fi
    
    local volume_device=$(get_volume_device "$volume_name")
    if [[ -z "$volume_device" ]]; then
        print_error "デバイスノードを取得できません: ${volume_name}"
        return 1
    fi
    
    # CRITICAL: Check if internal storage data exists (mount protection)
    # If the target path exists as a regular directory (not a mount point), 
    # AND contains actual data, it means data is on internal storage
    # - prevent mounting external volume to avoid data loss
    if [[ -d "$target_path" ]]; then
        local mount_check=$(/sbin/mount | /usr/bin/grep " on ${target_path} ")
        if [[ -z "$mount_check" ]]; then
            # Directory exists but is NOT a mount point
            # Check if it contains actual data (not just an empty mount point directory)
            if [[ -n "$(ls -A "$target_path" 2>/dev/null)" ]]; then
                # Directory has content = internal storage data exists
                print_error "❌ マウントがブロックされました"
                print_warning "このアプリは現在、内蔵ストレージで動作しています"
                print_info "外部ボリュームをマウントする前に、以下を実行してください:"
                echo ""
                echo "  ${CYAN}1.${NC} ストレージ切り替え機能（オプション6）を使用"
                echo "  ${CYAN}2.${NC} 「内蔵 → 外部」への切り替えを実行"
                echo ""
                print_info "または、内蔵データを手動でバックアップしてから削除:"
                echo "  sudo mv \"${target_path}\" \"${target_path}.backup\""
                echo ""
                return 1
            else
                # Directory is empty = safe to remove and mount
                print_info "空のディレクトリを削除してマウント準備中..."
                sudo rm -rf "$target_path"
            fi
        fi
    fi
    
    # Check current mount point
    local current_mount=$(get_mount_point "$volume_name")
    
    if [[ "$current_mount" == "$target_path" ]]; then
        print_success "${display_name} は既に正しい位置にマウントされています"
        return 0
    fi
    
    # Unmount if mounted elsewhere
    if [[ -n "$current_mount" ]]; then
        print_info "${display_name} が別の場所にマウントされています: ${current_mount}"
        print_info "アンマウント中..."
        sudo umount "$current_mount" 2>/dev/null || sudo diskutil unmount force "$volume_device" 2>/dev/null
    fi
    
    # At this point, target_path should either not exist, or be safe to use
    # The mount protection above already handled internal data cases
    
    # Create mount point
    sudo mkdir -p "$target_path"
    
    # Mount with nobrowse option
    print_info "${display_name} をマウント中..."
    if sudo mount -t apfs -o nobrowse "$volume_device" "$target_path"; then
        print_success "${display_name} をマウントしました"
        print_info "  → ${target_path}"
        sudo chown -R $(id -u):$(id -g) "$target_path" 2>/dev/null || true
        return 0
    else
        print_error "${display_name} のマウントに失敗しました"
        return 1
    fi
}

# Unmount volume
unmount_volume() {
    local volume_name=$1
    local display_name=$2
    
    if ! volume_exists "$volume_name"; then
        print_warning "${display_name} ボリュームが見つかりません"
        return 1
    fi
    
    local current_mount=$(get_mount_point "$volume_name")
    
    if [[ -z "$current_mount" ]]; then
        print_info "${display_name} は既にアンマウントされています"
        return 0
    fi
    
    print_info "${display_name} をアンマウント中..."
    if sudo umount "$current_mount" 2>/dev/null || sudo diskutil unmount force "$(get_volume_device "$volume_name")" 2>/dev/null; then
        print_success "${display_name} をアンマウントしました"
        return 0
    else
        print_error "${display_name} のアンマウントに失敗しました"
        return 1
    fi
}

#######################################################
# Helper Functions
#######################################################

# Check if path is on external volume
is_on_external_volume() {
    local path=$1
    local storage_type=$(get_storage_type "$path")
    [[ "$storage_type" == "external" ]]
}

# Get storage type (internal/external/none)
get_storage_type() {
    local path=$1
    
    # If path doesn't exist, return unknown
    if [[ ! -e "$path" ]]; then
        echo "unknown"
        return
    fi
    
    # CRITICAL: First check if this path is a mount point for an APFS volume
    # This is the most reliable way to detect external storage
    local mount_check=$(/sbin/mount | /usr/bin/grep " on ${path} ")
    if [[ -n "$mount_check" ]] && [[ "$mount_check" =~ "apfs" ]]; then
        # This path is mounted as an APFS volume = external storage
        echo "external"
        return
    fi
    
    # If it's a directory but not a mount point, check if it has content
    if [[ -d "$path" ]]; then
        if [[ -z "$(ls -A "$path" 2>/dev/null)" ]]; then
            # Directory exists but is empty = no actual data
            # This is just an empty mount point directory left after unmount
            echo "none"
            return
        fi
    fi
    
    # If not a mount point and has content, it's a regular directory on some disk
    # Get the device info for the filesystem containing this path
    local device=$(/bin/df "$path" | /usr/bin/tail -1 | /usr/bin/awk '{print $1}')
    local disk_id=$(echo "$device" | /usr/bin/sed -E 's|/dev/(disk[0-9]+).*|\1|')
    
    # Check the disk location
    local disk_location=$(diskutil info "/dev/$disk_id" 2>/dev/null | /usr/bin/grep "Device Location:" | /usr/bin/awk -F: '{print $2}' | /usr/bin/sed 's/^ *//')
    
    if [[ "$disk_location" == "Internal" ]]; then
        echo "internal"
    elif [[ "$disk_location" == "External" ]]; then
        echo "external"
    else
        # Fallback: check if it's on the main system disk (disk0 or disk1 usually)
        if [[ "$disk_id" == "disk0" ]] || [[ "$disk_id" == "disk1" ]] || [[ "$disk_id" == "disk3" ]]; then
            echo "internal"
        else
            echo "external"
        fi
    fi
}

# Ensure PlayCover main volume is mounted
ensure_playcover_main_volume() {
    if ! volume_exists "$PLAYCOVER_VOLUME_NAME"; then
        print_warning "PlayCover メインボリュームが見つかりません"
        return 1
    fi
    
    local pc_current_mount=$(get_mount_point "$PLAYCOVER_VOLUME_NAME")
    
    if [[ "$pc_current_mount" == "$PLAYCOVER_CONTAINER" ]]; then
        print_info "PlayCover メインボリュームは既にマウント済みです"
        return 0
    fi
    
    print_info "PlayCover メインボリュームをマウント中..."
    
    local pc_device=$(get_volume_device "$PLAYCOVER_VOLUME_NAME")
    if [[ -z "$pc_device" ]]; then
        print_error "PlayCover デバイスノードを取得できません"
        return 1
    fi
    
    # Unmount if mounted elsewhere
    if [[ -n "$pc_current_mount" ]]; then
        sudo umount "$pc_current_mount" 2>/dev/null || sudo diskutil unmount force "$pc_device" 2>/dev/null || true
    fi
    
    # Create mount point and mount
    sudo mkdir -p "$PLAYCOVER_CONTAINER"
    if sudo mount -t apfs -o nobrowse "$pc_device" "$PLAYCOVER_CONTAINER"; then
        print_success "PlayCover メインボリュームをマウントしました"
        sudo chown -R $(id -u):$(id -g) "$PLAYCOVER_CONTAINER" 2>/dev/null || true
        return 0
    else
        print_error "PlayCover メインボリュームのマウントに失敗しました"
        return 1
    fi
}

#######################################################
# Main Operations
#######################################################

# Mount all volumes
mount_all_volumes() {
    clear
    print_header "全ボリュームのマウント"
    
    authenticate_sudo
    
    # Mount PlayCover main volume first
    print_info "PlayCover メインボリュームを確認中..."
    if volume_exists "$PLAYCOVER_VOLUME_NAME"; then
        local pc_current_mount=$(get_mount_point "$PLAYCOVER_VOLUME_NAME")
        if [[ "$pc_current_mount" != "$PLAYCOVER_CONTAINER" ]]; then
            local pc_device=$(get_volume_device "$PLAYCOVER_VOLUME_NAME")
            if [[ -n "$pc_current_mount" ]]; then
                sudo umount "$pc_current_mount" 2>/dev/null || true
            fi
            sudo mkdir -p "$PLAYCOVER_CONTAINER"
            if sudo mount -t apfs -o nobrowse "$pc_device" "$PLAYCOVER_CONTAINER"; then
                print_success "PlayCover メインボリュームをマウントしました"
                sudo chown -R $(id -u):$(id -g) "$PLAYCOVER_CONTAINER" 2>/dev/null || true
            fi
        else
            print_success "PlayCover メインボリュームは既にマウント済みです"
        fi
    else
        print_warning "PlayCover メインボリュームが見つかりません"
    fi
    
    echo ""
    
    # Read mappings
    local mappings=($(read_mappings))
    
    if [[ ${#mappings[@]} -eq 0 ]]; then
        print_warning "登録されているアプリボリュームがありません"
        echo ""
        echo -n "Enterキーで続行..."
        read
        return
    fi
    
    local mounted_count=0
    local failed_count=0
    local missing_volumes=()
    
    for mapping in "${mappings[@]}"; do
        IFS='|' read -r volume_name bundle_id display_name <<< "$mapping"
        
        if ! volume_exists "$volume_name"; then
            missing_volumes+=("${volume_name}|${bundle_id}|${display_name}")
            continue
        fi
        
        # Use || true to prevent script exit on error
        if mount_volume "$volume_name" "$bundle_id" "$display_name" || true; then
            # Check if actually mounted
            local verify_mount=$(get_mount_point "$volume_name")
            local target_path="${HOME}/Library/Containers/${bundle_id}"
            if [[ "$verify_mount" == "$target_path" ]]; then
                ((mounted_count++))
            else
                ((failed_count++))
            fi
        else
            ((failed_count++))
        fi
        echo ""
    done
    
    # Handle missing volumes
    if [[ ${#missing_volumes[@]} -gt 0 ]]; then
        echo ""
        print_warning "以下のボリュームが見つかりませんでした:"
        for missing in "${missing_volumes[@]}"; do
            IFS='|' read -r vol_name bun_id disp_name <<< "$missing"
            echo "  - ${disp_name} (${vol_name})"
        done
        echo ""
        echo -n "${YELLOW}これらのマッピングを削除しますか？ (y/N):${NC} "
        read cleanup_choice
        
        if [[ "$cleanup_choice" =~ ^[Yy] ]]; then
            for missing in "${missing_volumes[@]}"; do
                IFS='|' read -r vol_name bun_id disp_name <<< "$missing"
                remove_mapping "$vol_name" "$bun_id"
            done
            print_success "マッピングをクリーンアップしました"
        fi
    fi
    
    echo ""
    print_header "マウント結果"
    print_success "成功: ${mounted_count} 個"
    if [[ $failed_count -gt 0 ]]; then
        print_error "失敗: ${failed_count} 個"
    fi
    if [[ ${#missing_volumes[@]} -gt 0 ]]; then
        print_warning "見つからない: ${#missing_volumes[@]} 個"
    fi
    echo ""
    echo -n "Enterキーで続行..."
    read
}

# Unmount all volumes
unmount_all_volumes() {
    clear
    print_header "全ボリュームのアンマウント"
    
    authenticate_sudo
    
    local mappings=($(read_mappings))
    
    if [[ ${#mappings[@]} -eq 0 ]]; then
        print_warning "登録されているアプリボリュームがありません"
        echo ""
        
        # Still try to unmount PlayCover main volume
        if volume_exists "$PLAYCOVER_VOLUME_NAME"; then
            unmount_volume "$PLAYCOVER_VOLUME_NAME" "PlayCover メインボリューム" || true
        fi
        
        echo ""
        echo -n "Enterキーで続行..."
        read
        return
    fi
    
    local unmounted_count=0
    local failed_count=0
    
    # Unmount app volumes first
    for mapping in "${mappings[@]}"; do
        IFS='|' read -r volume_name bundle_id display_name <<< "$mapping"
        
        # Use || true to prevent script exit on error
        if unmount_volume "$volume_name" "$display_name" || true; then
            # Verify unmount
            local verify_mount=$(get_mount_point "$volume_name" 2>/dev/null || echo "")
            if [[ -z "$verify_mount" ]]; then
                ((unmounted_count++))
            else
                ((failed_count++))
            fi
        else
            ((failed_count++))
        fi
        echo ""
    done
    
    # Unmount PlayCover main volume last
    print_info "PlayCover メインボリュームをアンマウント中..."
    if volume_exists "$PLAYCOVER_VOLUME_NAME"; then
        if unmount_volume "$PLAYCOVER_VOLUME_NAME" "PlayCover メインボリューム" || true; then
            # Verify unmount
            local verify_mount=$(get_mount_point "$PLAYCOVER_VOLUME_NAME" 2>/dev/null || echo "")
            if [[ -z "$verify_mount" ]]; then
                ((unmounted_count++))
            else
                ((failed_count++))
            fi
        else
            ((failed_count++))
        fi
    fi
    
    echo ""
    print_header "アンマウント結果"
    print_success "成功: ${unmounted_count} 個"
    if [[ $failed_count -gt 0 ]]; then
        print_error "失敗: ${failed_count} 個"
    fi
    echo ""
    echo -n "Enterキーで続行..."
    read
}

# Individual volume control
individual_volume_control() {
    clear
    print_header "個別ボリューム操作"
    
    local mappings=($(read_mappings))
    
    if [[ ${#mappings[@]} -eq 0 ]]; then
        print_warning "登録されているアプリボリュームがありません"
        echo ""
        echo -n "Enterキーで続行..."
        read
        return
    fi
    
    # Display volume list
    echo "登録されているボリューム:"
    echo ""
    
    local index=1
    for mapping in "${mappings[@]}"; do
        IFS='|' read -r volume_name bundle_id display_name <<< "$mapping"
        
        local vol_status="❌"
        local mount_info=""
        
        if volume_exists "$volume_name"; then
            local current_mount=$(get_mount_point "$volume_name")
            local target_path="${HOME}/Library/Containers/${bundle_id}"
            
            if [[ -n "$current_mount" ]]; then
                if [[ "$current_mount" == "$target_path" ]]; then
                    vol_status="✅"
                    mount_info="(正常にマウント済み)"
                else
                    vol_status="⚠️ "
                    mount_info="(別の場所: ${current_mount})"
                fi
            else
                vol_status="⭕"
                mount_info="(アンマウント済み)"
            fi
        else
            vol_status="❌"
            mount_info="(ボリュームが見つかりません)"
        fi
        
        echo "  ${index}. ${vol_status} ${display_name}"
        echo "      ${mount_info}"
        echo ""
        ((index++))
    done
    
    echo "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "${CYAN}操作を選択してください:${NC}"
    echo "  ${GREEN}[番号]${NC} : 個別マウント/アンマウント"
    echo "  ${YELLOW}[q]${NC}    : 戻る"
    echo ""
    echo -n "${CYAN}選択:${NC} "
    read choice
    
    if [[ "$choice" == "q" ]] || [[ "$choice" == "Q" ]]; then
        return
    fi
    
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ $choice -lt 1 ]] || [[ $choice -gt ${#mappings[@]} ]]; then
        print_error "無効な選択です"
        sleep 2
        individual_volume_control
        return
    fi
    
    authenticate_sudo
    
    local selected_mapping="${mappings[$choice]}"
    IFS='|' read -r volume_name bundle_id display_name <<< "$selected_mapping"
    
    echo ""
    print_header "${display_name} の操作"
    
    if ! volume_exists "$volume_name"; then
        print_error "ボリュームが見つかりません: ${volume_name}"
        echo ""
        echo -n "${YELLOW}このマッピングを削除しますか？ (y/N):${NC} "
        read delete_choice
        
        if [[ "$delete_choice" =~ ^[Yy] ]]; then
            remove_mapping "$volume_name" "$bundle_id"
        fi
        
        echo ""
        echo -n "Enterキーで続行..."
        read
        individual_volume_control
        return
    fi
    
    local current_mount=$(get_mount_point "$volume_name")
    
    if [[ -n "$current_mount" ]]; then
        echo "${CYAN}現在のマウント先:${NC} ${current_mount}"
        echo ""
        echo "  ${YELLOW}1.${NC} アンマウント"
        echo "  ${GREEN}2.${NC} 再マウント（正しい位置に）"
        echo "  ${NC}3.${NC} キャンセル"
        echo ""
        echo -n "${CYAN}選択:${NC} "
        read action
        
        case "$action" in
            1)
                unmount_volume "$volume_name" "$display_name"
                ;;
            2)
                unmount_volume "$volume_name" "$display_name"
                echo ""
                
                # Ensure PlayCover main volume is mounted first
                ensure_playcover_main_volume || true
                echo ""
                
                mount_volume "$volume_name" "$bundle_id" "$display_name"
                ;;
            *)
                print_info "キャンセルしました"
                ;;
        esac
    else
        echo "${CYAN}現在:${NC} アンマウント済み"
        echo ""
        echo -n "${GREEN}マウントしますか？ (Y/n):${NC} "
        read mount_choice
        
        if [[ ! "$mount_choice" =~ ^[Nn] ]]; then
            # Ensure PlayCover main volume is mounted first
            ensure_playcover_main_volume || true
            echo ""
            
            mount_volume "$volume_name" "$bundle_id" "$display_name"
        fi
    fi
    
    echo ""
    echo -n "Enterキーで続行..."
    read
    individual_volume_control
}

# Eject entire disk
eject_disk() {
    clear
    print_header "ディスク全体の取り外し"
    
    authenticate_sudo
    
    # First, unmount all PlayCover volumes
    print_info "全ボリュームをアンマウント中..."
    echo ""
    
    local mappings=($(read_mappings))
    local unmounted_volumes=()
    
    # Unmount app volumes
    for mapping in "${mappings[@]}"; do
        IFS='|' read -r volume_name bundle_id display_name <<< "$mapping"
        
        if volume_exists "$volume_name"; then
            local current_mount=$(get_mount_point "$volume_name")
            if [[ -n "$current_mount" ]]; then
                if unmount_volume "$volume_name" "$display_name"; then
                    unmounted_volumes+=("$volume_name")
                fi
            fi
        fi
    done
    
    # Unmount PlayCover main volume
    if volume_exists "$PLAYCOVER_VOLUME_NAME"; then
        local pc_mount=$(get_mount_point "$PLAYCOVER_VOLUME_NAME")
        if [[ -n "$pc_mount" ]]; then
            if unmount_volume "$PLAYCOVER_VOLUME_NAME" "PlayCover メインボリューム"; then
                unmounted_volumes+=("$PLAYCOVER_VOLUME_NAME")
            fi
        fi
    fi
    
    if [[ ${#unmounted_volumes[@]} -eq 0 ]]; then
        print_warning "アンマウントするボリュームがありませんでした"
        echo ""
        echo -n "Enterキーで続行..."
        read
        return
    fi
    
    echo ""
    print_header "ディスクの検出"
    
    # Find the disk that contains the PlayCover volume
    local playcover_device=$(get_volume_device "$PLAYCOVER_VOLUME_NAME")
    if [[ -z "$playcover_device" ]]; then
        print_error "PlayCover ボリュームのデバイスが見つかりません"
        echo ""
        echo -n "Enterキーで続行..."
        read
        return
    fi
    
    # Extract disk identifier (e.g., /dev/disk5s1 -> disk5)
    local disk_id=$(echo "$playcover_device" | /usr/bin/sed -E 's|/dev/(disk[0-9]+).*|\1|')
    
    # Get disk information
    local disk_name=$(diskutil info "/dev/$disk_id" | /usr/bin/grep "Device / Media Name:" | /usr/bin/sed 's/.*: *//')
    local disk_size=$(diskutil info "/dev/$disk_id" | /usr/bin/grep "Disk Size:" | /usr/bin/sed 's/.*: *//' | /usr/bin/awk '{print $1, $2}')
    
    print_info "検出されたディスク:"
    echo "  名前: ${disk_name}"
    echo "  サイズ: ${disk_size}"
    echo "  デバイス: /dev/${disk_id}"
    echo ""
    
    print_warning "このディスクを取り外すと、すべてのボリュームがアンマウントされます"
    echo ""
    echo -n "${RED}ディスクを取り外しますか？ (y/N):${NC} "
    read eject_choice
    
    if [[ ! "$eject_choice" =~ ^[Yy] ]]; then
        print_info "キャンセルしました"
        echo ""
        echo -n "Enterキーで続行..."
        read
        return
    fi
    
    print_info "ディスクを取り外し中..."
    
    # Try to eject all volumes on the disk first
    print_info "ディスク上の全ボリュームを強制アンマウント中..."
    local all_volumes=$(diskutil list "/dev/$disk_id" 2>/dev/null | /usr/bin/grep "APFS Volume" | /usr/bin/awk '{print $NF}')
    for vol in $all_volumes; do
        sudo diskutil unmount force "/dev/$vol" 2>/dev/null || true
    done
    
    sleep 2
    
    if sudo diskutil eject "/dev/$disk_id" 2>/dev/null; then
        print_success "ディスクを安全に取り外しました"
        print_info "物理的にデバイスを取り外すことができます"
    else
        print_warning "ディスクの取り外しに失敗しました"
        print_info "一部のボリュームが使用中の可能性があります"
        echo ""
        print_info "手動で取り外すには:"
        echo "  1. Finder ですべてのウィンドウを閉じる"
        echo "  2. ディスクユーティリティで取り外しを試す"
    fi
    
    echo ""
    echo -n "Enterキーで続行..."
    read
}

# Show status
show_status() {
    clear
    print_header "ボリューム状態一覧"
    
    # PlayCover main volume
    echo "${CYAN}● PlayCover メインボリューム${NC}"
    if volume_exists "$PLAYCOVER_VOLUME_NAME"; then
        local pc_mount=$(get_mount_point "$PLAYCOVER_VOLUME_NAME")
        if [[ -n "$pc_mount" ]]; then
            if [[ "$pc_mount" == "$PLAYCOVER_CONTAINER" ]]; then
                print_success "正常にマウント済み"
                echo "  → ${pc_mount}"
            else
                print_warning "別の場所にマウントされています"
                echo "  → ${pc_mount}"
            fi
        else
            print_warning "アンマウント済み"
        fi
    else
        print_error "ボリュームが見つかりません"
    fi
    echo ""
    
    # App volumes
    local mappings=($(read_mappings))
    
    if [[ ${#mappings[@]} -eq 0 ]]; then
        print_info "登録されているアプリボリュームはありません"
        echo ""
        echo -n "Enterキーで続行..."
        read
        return
    fi
    
    echo "${CYAN}● アプリボリューム${NC}"
    echo ""
    
    for mapping in "${mappings[@]}"; do
        IFS='|' read -r volume_name bundle_id display_name <<< "$mapping"
        
        echo "  ${GREEN}${display_name}${NC}"
        
        if volume_exists "$volume_name"; then
            local current_mount=$(get_mount_point "$volume_name")
            local target_path="${HOME}/Library/Containers/${bundle_id}"
            
            if [[ -n "$current_mount" ]]; then
                if [[ "$current_mount" == "$target_path" ]]; then
                    print_success "  正常にマウント済み"
                    echo "    → ${current_mount}"
                else
                    print_warning "  別の場所にマウントされています"
                    echo "    正: ${target_path}"
                    echo "    現: ${current_mount}"
                fi
            else
                print_info "  アンマウント済み"
            fi
        else
            print_error "  ボリュームが見つかりません (${volume_name})"
        fi
        echo ""
    done
    
    echo -n "Enterキーで続行..."
    read
}

# Switch storage location (internal <-> external)
switch_storage_location() {
    clear
    print_header "ストレージ切り替え（内蔵⇄外部）"
    
    local mappings=($(read_mappings))
    
    if [[ ${#mappings[@]} -eq 0 ]]; then
        print_warning "登録されているアプリボリュームがありません"
        echo ""
        echo -n "Enterキーで続行..."
        read
        return
    fi
    
    # Display volume list with current storage type
    echo "登録されているボリューム:"
    echo ""
    
    local index=1
    for mapping in "${mappings[@]}"; do
        IFS='|' read -r volume_name bundle_id display_name <<< "$mapping"
        
        local storage_icon="❓"
        local storage_info="(不明)"
        local target_path="${HOME}/Library/Containers/${bundle_id}"
        
        if [[ -d "$target_path" ]]; then
            local storage_type=$(get_storage_type "$target_path")
            case "$storage_type" in
                "internal")
                    storage_icon="💾"
                    storage_info="(内蔵ストレージ)"
                    ;;
                "external")
                    storage_icon="🔌"
                    storage_info="(外部ストレージ)"
                    ;;
                "none")
                    storage_icon="⚪"
                    storage_info="(アンマウント済み)"
                    ;;
                *)
                    storage_icon="❓"
                    storage_info="(不明)"
                    ;;
            esac
        else
            storage_icon="❌"
            storage_info="(データなし)"
        fi
        
        echo "  ${index}. ${storage_icon} ${display_name}"
        echo "      ${storage_info}"
        echo ""
        ((index++))
    done
    
    echo "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "${CYAN}切り替えるアプリを選択してください:${NC}"
    echo "  ${GREEN}[番号]${NC} : ストレージ切り替え"
    echo "  ${YELLOW}[q]${NC}    : 戻る"
    echo ""
    echo -n "${CYAN}選択:${NC} "
    read choice
    
    if [[ "$choice" == "q" ]] || [[ "$choice" == "Q" ]]; then
        return
    fi
    
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ $choice -lt 1 ]] || [[ $choice -gt ${#mappings[@]} ]]; then
        print_error "無効な選択です"
        sleep 2
        switch_storage_location
        return
    fi
    
    authenticate_sudo
    
    local selected_mapping="${mappings[$choice]}"
    IFS='|' read -r volume_name bundle_id display_name <<< "$selected_mapping"
    
    echo ""
    print_header "${display_name} のストレージ切り替え"
    
    local target_path="${HOME}/Library/Containers/${bundle_id}"
    local backup_path="${HOME}/Library/Containers/.${bundle_id}.backup"
    
    # Check current storage type
    local current_storage="unknown"
    if [[ -d "$target_path" ]]; then
        current_storage=$(get_storage_type "$target_path")
    fi
    
    echo "${CYAN}現在の状態:${NC}"
    case "$current_storage" in
        "internal")
            echo "  💾 内蔵ストレージ"
            ;;
        "external")
            echo "  🔌 外部ストレージ"
            ;;
        *)
            echo "  ❓ 不明 / データなし"
            ;;
    esac
    echo ""
    
    # Determine target action
    local action=""
    case "$current_storage" in
        "internal")
            action="external"
            echo "${CYAN}実行する操作:${NC} 内蔵 → 外部ストレージへ移動"
            ;;
        "external")
            action="internal"
            echo "${CYAN}実行する操作:${NC} 外部 → 内蔵ストレージへ移動"
            ;;
        "none")
            print_error "ストレージ切り替えを実行できません"
            echo ""
            echo "理由: データが存在しません（アンマウント済み）"
            echo ""
            echo "推奨される操作:"
            echo "  ${CYAN}1.${NC} メインメニューのオプション3で外部ボリュームをマウント"
            echo "  ${CYAN}2.${NC} その後、このストレージ切り替え機能を使用"
            echo ""
            echo -n "Enterキーで続行..."
            read
            switch_storage_location
            return
            ;;
        *)
            print_error "現在のストレージ状態を判定できません"
            echo ""
            echo "考えられる原因:"
            echo "  - アプリがまだインストールされていない"
            echo "  - データディレクトリが存在しない"
            echo ""
            echo -n "Enterキーで続行..."
            read
            switch_storage_location
            return
            ;;
    esac
    
    echo ""
    print_warning "この操作には時間がかかる場合があります"
    echo ""
    echo -n "${YELLOW}続行しますか？ (y/N):${NC} "
    read confirm
    
    if [[ ! "$confirm" =~ ^[Yy] ]]; then
        print_info "キャンセルしました"
        echo ""
        echo -n "Enterキーで続行..."
        read
        switch_storage_location
        return
    fi
    
    echo ""
    
    if [[ "$action" == "external" ]]; then
        # Internal -> External: Copy data to volume and mount
        print_info "内蔵から外部ストレージへデータを移行中..."
        
        # Check if volume exists
        if ! volume_exists "$volume_name"; then
            print_error "外部ボリュームが見つかりません: ${volume_name}"
            echo ""
            echo -n "Enterキーで続行..."
            read
            switch_storage_location
            return
        fi
        
        # Unmount if already mounted
        local current_mount=$(get_mount_point "$volume_name")
        if [[ -n "$current_mount" ]]; then
            print_info "既存のマウントをアンマウント中..."
            unmount_volume "$volume_name" "$display_name" || true
            sleep 1
        fi
        
        # Create temporary mount point
        local temp_mount="/tmp/playcover_temp_$$"
        sudo mkdir -p "$temp_mount"
        
        # Mount volume temporarily
        local volume_device=$(get_volume_device "$volume_name")
        print_info "ボリュームを一時マウント中..."
        if ! sudo mount -t apfs "$volume_device" "$temp_mount"; then
            print_error "ボリュームのマウントに失敗しました"
            sudo rm -rf "$temp_mount"
            echo ""
            echo -n "Enterキーで続行..."
            read
            switch_storage_location
            return
        fi
        
        # Debug: Show source path and content
        print_info "コピー元: ${target_path}"
        local file_count=$(sudo find "$target_path" -type f 2>/dev/null | wc -l | xargs)
        local total_size=$(sudo du -sh "$target_path" 2>/dev/null | awk '{print $1}')
        print_info "  ファイル数: ${file_count}"
        print_info "  データサイズ: ${total_size}"
        
        # Copy data from internal to external
        print_info "データをコピー中... (しばらくお待ちください)"
        echo ""
        
        # Use rsync with better progress display
        if sudo /usr/bin/rsync -avH --progress "$target_path/" "$temp_mount/" 2>&1; then
            echo ""
            print_success "データのコピーが完了しました"
            
            # Verify copied data
            local copied_count=$(sudo find "$temp_mount" -type f 2>/dev/null | wc -l | xargs)
            local copied_size=$(sudo du -sh "$temp_mount" 2>/dev/null | awk '{print $1}')
            print_info "  コピー完了: ${copied_count} ファイル (${copied_size})"
        else
            echo ""
            print_error "データのコピーに失敗しました"
            sudo umount "$temp_mount"
            sudo rm -rf "$temp_mount"
            echo ""
            echo -n "Enterキーで続行..."
            read
            switch_storage_location
            return
        fi
        
        # Unmount temporary mount
        sudo umount "$temp_mount"
        sudo rm -rf "$temp_mount"
        
        # Backup internal data
        print_info "内蔵データをバックアップ中..."
        sudo mv "$target_path" "$backup_path"
        
        # Mount volume to proper location
        print_info "ボリュームを正式にマウント中..."
        if mount_volume "$volume_name" "$bundle_id" "$display_name"; then
            print_success "外部ストレージへの切り替えが完了しました"
            echo ""
            print_info "内蔵データは以下にバックアップされています:"
            echo "  ${backup_path}"
            echo ""
            print_warning "問題なく動作することを確認したら、バックアップを削除してください:"
            echo "  sudo rm -rf \"${backup_path}\""
        else
            print_error "ボリュームのマウントに失敗しました"
            print_info "内蔵データを復元中..."
            sudo mv "$backup_path" "$target_path"
        fi
        
    else
        # External -> Internal: Copy data from volume to internal and unmount
        print_info "外部から内蔵ストレージへデータを移行中..."
        
        # Check if volume exists
        if ! volume_exists "$volume_name"; then
            print_error "外部ボリュームが見つかりません: ${volume_name}"
            echo ""
            echo -n "Enterキーで続行..."
            read
            switch_storage_location
            return
        fi
        
        # Determine current mount point
        local current_mount=$(get_mount_point "$volume_name")
        local temp_mount_created=false
        
        if [[ -z "$current_mount" ]]; then
            # Volume not mounted - mount to temporary location
            print_info "ボリュームを一時マウント中..."
            local temp_mount="/tmp/playcover_temp_$$"
            sudo mkdir -p "$temp_mount"
            local volume_device=$(get_volume_device "$volume_name")
            if ! sudo mount -t apfs "$volume_device" "$temp_mount"; then
                print_error "ボリュームのマウントに失敗しました"
                sudo rm -rf "$temp_mount"
                echo ""
                echo -n "Enterキーで続行..."
                read
                switch_storage_location
                return
            fi
            current_mount="$temp_mount"
            temp_mount_created=true
        elif [[ "$current_mount" == "$target_path" ]]; then
            # Volume is mounted at target path - need to use it as source
            print_info "外部ボリュームは ${target_path} にマウントされています"
        fi
        
        # Debug: Show source path and content
        print_info "コピー元: ${current_mount}"
        local file_count=$(sudo find "$current_mount" -type f 2>/dev/null | wc -l | xargs)
        local total_size=$(sudo du -sh "$current_mount" 2>/dev/null | awk '{print $1}')
        print_info "  ファイル数: ${file_count}"
        print_info "  データサイズ: ${total_size}"
        
        # If target path exists and is a mount point, we need to unmount first
        if [[ -d "$target_path" ]]; then
            local is_mount=$(/sbin/mount | /usr/bin/grep " on ${target_path} ")
            if [[ -n "$is_mount" ]]; then
                # Target is a mount point - unmount it first
                print_info "既存のマウントポイントをアンマウント中..."
                if ! sudo umount "$target_path" 2>/dev/null; then
                    print_error "アンマウントに失敗しました"
                    if [[ "$temp_mount_created" == true ]]; then
                        sudo umount "$current_mount" 2>/dev/null || true
                        sudo rm -rf "$current_mount"
                    fi
                    echo ""
                    echo -n "Enterキーで続行..."
                    read
                    switch_storage_location
                    return
                fi
                sleep 1  # Wait for unmount to complete
            fi
            
            # Now backup the directory (no longer a mount point)
            if [[ -e "$target_path" ]]; then
                print_info "既存ディレクトリをバックアップ中..."
                sudo mv "$target_path" "$backup_path" 2>/dev/null || {
                    print_warning "バックアップに失敗しましたが続行します"
                }
            fi
        fi
        
        # Create new internal directory
        sudo mkdir -p "$target_path"
        
        # Copy data from external to internal
        print_info "データをコピー中... (しばらくお待ちください)"
        echo ""
        
        # Use rsync with better progress display
        if sudo /usr/bin/rsync -avH --progress "$current_mount/" "$target_path/" 2>&1; then
            echo ""
            print_success "データのコピーが完了しました"
            
            # Verify copied data
            local copied_count=$(sudo find "$target_path" -type f 2>/dev/null | wc -l | xargs)
            local copied_size=$(sudo du -sh "$target_path" 2>/dev/null | awk '{print $1}')
            print_info "  コピー完了: ${copied_count} ファイル (${copied_size})"
            
            # Set ownership
            sudo chown -R $(id -u):$(id -g) "$target_path"
        else
            echo ""
            print_error "データのコピーに失敗しました"
            sudo rm -rf "$target_path"
            if [[ -d "$backup_path" ]]; then
                print_info "バックアップを復元中..."
                sudo mv "$backup_path" "$target_path"
            fi
            
            # Cleanup temp mount if created
            if [[ "$temp_mount_created" == true ]]; then
                sudo umount "$current_mount" 2>/dev/null || true
                sudo rm -rf "$current_mount"
            fi
            
            echo ""
            echo -n "Enterキーで続行..."
            read
            switch_storage_location
            return
        fi
        
        # Unmount volume (if it was at target_path or temp mount)
        if [[ "$temp_mount_created" == true ]]; then
            print_info "一時マウントをクリーンアップ中..."
            sudo umount "$current_mount" 2>/dev/null || true
            sudo rm -rf "$current_mount"
        else
            # Volume was mounted at target_path, now unmount it completely
            print_info "外部ボリュームをアンマウント中..."
            unmount_volume "$volume_name" "$display_name" || true
        fi
        
        print_success "内蔵ストレージへの切り替えが完了しました"
        
        if [[ -d "$backup_path" ]]; then
            echo ""
            print_info "元の外部マウントポイントは以下にバックアップされています:"
            echo "  ${backup_path}"
            echo ""
            print_warning "問題なく動作することを確認したら、バックアップを削除してください:"
            echo "  sudo rm -rf \"${backup_path}\""
        fi
    fi
    
    echo ""
    echo -n "Enterキーで続行..."
    read
    switch_storage_location
}

#######################################################
# Main Menu
#######################################################

# Show quick mount status on menu
show_quick_status() {
    local mounted_count=0
    local unmounted_count=0
    local total_count=0
    
    # Count volumes by status
    while IFS=$'\t' read -r volume_name bundle_id display_name; do
        # Skip PlayCover main volume
        if [[ "$bundle_id" == "$PLAYCOVER_BUNDLE_ID" ]]; then
            continue
        fi
        
        ((total_count++))
        
        local target_path="${HOME}/Library/Containers/${bundle_id}"
        local storage_type=$(get_storage_type "$target_path")
        
        if [[ "$storage_type" == "external" ]]; then
            ((mounted_count++))
        else
            ((unmounted_count++))
        fi
    done < "$MAPPING_FILE"
    
    # Display status bar
    echo "${BLUE}━━━━━━━━━━━━ 現在の状態 ━━━━━━━━━━━━${NC}"
    echo ""
    
    if [[ $total_count -eq 0 ]]; then
        echo "  ${YELLOW}⚠${NC} 登録されているアプリがありません"
    else
        echo "  ${GREEN}🔌 マウント中:${NC} ${mounted_count}/${total_count}"
        echo "  ${YELLOW}⚪ アンマウント:${NC} ${unmounted_count}/${total_count}"
        
        # Show individual status (compact)
        echo ""
        echo "  ${CYAN}【ボリューム一覧】${NC}"
        
        local index=1
        while IFS=$'\t' read -r volume_name bundle_id display_name; do
            # Skip PlayCover main volume
            if [[ "$bundle_id" == "$PLAYCOVER_BUNDLE_ID" ]]; then
                continue
            fi
            
            local target_path="${HOME}/Library/Containers/${bundle_id}"
            local storage_type=$(get_storage_type "$target_path")
            local status_icon=""
            
            case "$storage_type" in
                "external")
                    status_icon="${GREEN}🔌${NC}"
                    ;;
                "internal")
                    status_icon="${YELLOW}💾${NC}"
                    ;;
                "none")
                    status_icon="${BLUE}⚪${NC}"
                    ;;
                *)
                    status_icon="❓"
                    ;;
            esac
            
            echo "    ${status_icon} ${display_name}"
            ((index++))
        done < "$MAPPING_FILE"
    fi
    
    echo ""
}

show_menu() {
    clear
    
    echo "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                                                           ║"
    echo "║            ${GREEN}PlayCover ボリューム管理${CYAN}                     ║"
    echo "║                                                           ║"
    echo "║              ${BLUE}macOS Tahoe 26.0.1 対応版${CYAN}                    ║"
    echo "║                 ${BLUE}Version 1.5.1${CYAN}                              ║"
    echo "║                                                           ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo "${NC}"
    echo ""
    
    # Display current mount status
    show_quick_status
    
    echo "${BLUE}━━━━━━━━━━━━━━ メニュー ━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  ${GREEN}1.${NC} 全ボリュームをマウント"
    echo "  ${YELLOW}2.${NC} 全ボリュームをアンマウント"
    echo "  ${CYAN}3.${NC} 個別ボリューム操作"
    echo "  ${BLUE}4.${NC} ボリューム状態確認"
    echo "  ${RED}5.${NC} ディスク全体を取り外し"
    echo "  ${YELLOW}6.${NC} ストレージ切り替え（内蔵⇄外部）"
    echo "  ${NC}7.${NC} 終了"
    echo ""
    echo -n "${CYAN}選択 (1-7):${NC} "
}

main() {
    # Check mapping file
    check_mapping_file
    
    while true; do
        show_menu
        read choice
        
        case "$choice" in
            1)
                echo ""
                mount_all_volumes
                ;;
            2)
                echo ""
                unmount_all_volumes
                ;;
            3)
                echo ""
                individual_volume_control
                ;;
            4)
                echo ""
                show_status
                ;;
            5)
                echo ""
                eject_disk
                ;;
            6)
                echo ""
                switch_storage_location
                ;;
            7)
                echo ""
                print_info "終了します"
                sleep 1
                osascript -e 'tell application "Terminal" to close (every window whose name contains "playcover")' & exit 0
                ;;
            *)
                echo ""
                print_error "無効な選択です"
                sleep 2
                ;;
        esac
    done
}

# Handle Ctrl+C
trap 'echo ""; print_info "終了します"; sleep 1; osascript -e '"'"'tell application "Terminal" to close (every window whose name contains "playcover")'"'"' & exit 0' INT

# Run main
main
