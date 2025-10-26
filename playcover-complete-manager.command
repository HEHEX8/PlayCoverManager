#!/bin/zsh

#######################################################
# PlayCover Complete Manager
# macOS Tahoe 26.0.1 Compatible
# Version: 4.19.1 - Fix startup crashes and improve UX
#######################################################

# Note: set -e is NOT used here to allow graceful error handling
# Volume operations require explicit error checking

# Enable zsh options for bash-like behavior
setopt KSH_ARRAYS  # Use 0-based array indexing like bash

#######################################################
# Module 1: Constants & Global Variables
#######################################################

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly NC='\033[0m' # No Color

# Constants
readonly PLAYCOVER_BUNDLE_ID="io.playcover.PlayCover"
readonly PLAYCOVER_CONTAINER="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}"
readonly PLAYCOVER_VOLUME_NAME="PlayCover"
readonly PLAYCOVER_APP_NAME="PlayCover.app"
readonly PLAYCOVER_APP_PATH="/Applications/${PLAYCOVER_APP_NAME}"
readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly MAPPING_FILE="${SCRIPT_DIR}/playcover-map.txt"
readonly MAPPING_LOCK_FILE="${MAPPING_FILE}.lock"

# Display width settings (optimized for 120x30 terminal)
readonly DISPLAY_WIDTH=118
readonly SEPARATOR_CHAR="─"

# Global variables
declare -a SELECTED_IPAS=()
declare -a INSTALL_SUCCESS=()
declare -a INSTALL_FAILED=()
APP_NAME=""
APP_NAME_EN=""
APP_VERSION=""
APP_BUNDLE_ID=""
APP_VOLUME_NAME=""
SELECTED_DISK=""
PLAYCOVER_VOLUME_DEVICE=""
SUDO_AUTHENTICATED=false
BATCH_MODE=false
CURRENT_IPA_INDEX=0
TOTAL_IPAS=0

# Initial setup specific variables
NEED_XCODE_TOOLS=false
NEED_HOMEBREW=false
NEED_PLAYCOVER=false

#######################################################
# Module 2: Utility Functions
#######################################################

# Print separator line (optimized for 120-column terminal)
print_separator() {
    local char="${1:-$SEPARATOR_CHAR}"
    local color="${2:-$BLUE}"
    printf "${color}"
    printf '%*s' "$DISPLAY_WIDTH" | tr ' ' "$char"
    printf "${NC}\n"
}

print_header() {
    echo ""
    echo "${BLUE}$1${NC}"
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

print_batch_progress() {
    local current=$1
    local total=$2
    local app_name=$3
    
    echo ""
    echo "${MAGENTA}▶ 処理中: ${current}/${total} - ${app_name}${NC}"
    print_separator "$SEPARATOR_CHAR" "$MAGENTA"
    echo ""
}

wait_for_enter() {
    local message="${1:-Enterキーで続行...}"
    echo ""
    echo -n "$message"
    read
}

is_playcover_running() {
    pgrep -x "PlayCover" >/dev/null 2>&1
}

get_playcover_external_path() {
    # PlayCoverボリュームがマウントされている場合、その場所を返す
    if [[ -d "$PLAYCOVER_CONTAINER" ]]; then
        echo "${PLAYCOVER_CONTAINER}/${PLAYCOVER_APP_NAME}"
    else
        echo ""
    fi
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
        osascript -e 'tell application "Terminal" to close (every window whose name contains "playcover")' & exit "$exit_code"
    fi
}

authenticate_sudo() {
    if [[ "$SUDO_AUTHENTICATED" == "true" ]]; then
        return 0
    fi
    
    print_info "管理者権限が必要です"
    
    if sudo -v; then
        SUDO_AUTHENTICATED=true
        print_success "認証成功"
        
        # Keep sudo alive in background
        while true; do
            sudo -n true
            sleep 50
            kill -0 "$$" 2>/dev/null || exit
        done 2>/dev/null &
        
        echo ""
        return 0
    else
        print_error "認証失敗"
        exit_with_cleanup 1 "管理者権限の取得に失敗しました"
    fi
}

check_playcover_app() {
    if [[ ! -d "/Applications/PlayCover.app" ]]; then
        print_error "PlayCover が見つかりません"
        print_warning "PlayCover を /Applications にインストールしてください"
        exit_with_cleanup 1 "PlayCover が見つかりません"
    fi
}

check_full_disk_access() {
    # Check if we can access a protected directory (e.g., Safari's directory)
    # This is a more reliable test for Full Disk Access
    local test_path="${HOME}/Library/Safari"
    
    if [[ ! -d "$test_path" ]]; then
        # Safari directory doesn't exist, try another test
        test_path="${HOME}/Library/Mail"
    fi
    
    # Try to list the directory - if FDA is granted, this will succeed
    if /bin/ls "$test_path" >/dev/null 2>&1; then
        return 0
    else
        print_warning "Terminal にフルディスクアクセス権限がありません"
        print_info "システム設定 > プライバシーとセキュリティ > フルディスクアクセス から有効にしてください"
        echo ""
        echo -n "設定完了後、Enterキーを押してください..."
        read
        
        # Re-check after user confirmation
        if /bin/ls "$test_path" >/dev/null 2>&1; then
            return 0
        else
            print_error "権限が確認できませんでした"
            echo ""
            echo -n "それでも続行しますか？ (y/N): "
            read continue_choice
            
            if [[ ! "$continue_choice" =~ ^[Yy]$ ]]; then
                exit_with_cleanup 1 "フルディスクアクセス権限が必要です"
            fi
            echo ""
        fi
    fi
}

#######################################################
# Module 3: Mapping File Management
#######################################################

acquire_mapping_lock() {
    local timeout=10
    local elapsed=0
    
    while ! mkdir "$MAPPING_LOCK_FILE" 2>/dev/null; do
        sleep 0.1
        elapsed=$((elapsed + 1))
        
        if [[ $elapsed -ge $((timeout * 10)) ]]; then
            print_error "マッピングファイルのロック取得に失敗しました（タイムアウト）"
            return 1
        fi
    done
    
    return 0
}

release_mapping_lock() {
    rmdir "$MAPPING_LOCK_FILE" 2>/dev/null || true
}

check_mapping_file() {
    if [[ ! -f "$MAPPING_FILE" ]]; then
        print_warning "マッピングファイルが見つかりません"
        
        if [[ -x "$INITIAL_SETUP_SCRIPT" ]]; then
            print_info "初期セットアップスクリプトを実行してください"
            print_info "実行: $INITIAL_SETUP_SCRIPT"
        else
            print_info "空のマッピングファイルを作成します"
            touch "$MAPPING_FILE"
        fi
        
        echo ""
        return 1
    fi
    
    return 0
}

read_mappings() {
    if [[ ! -f "$MAPPING_FILE" ]]; then
        return 1
    fi
    
    # Return mappings via stdout (caller captures with command substitution)
    /bin/cat "$MAPPING_FILE"
}

deduplicate_mappings() {
    if [[ ! -f "$MAPPING_FILE" ]]; then
        return 0
    fi
    
    acquire_mapping_lock || return 1
    
    local temp_file="${MAPPING_FILE}.dedup"
    local original_count=$(wc -l < "$MAPPING_FILE" 2>/dev/null || echo "0")
    
    # Remove duplicates based on volume_name (first column)
    # Keep first occurrence, remove subsequent duplicates
    /usr/bin/awk -F'\t' '!seen[$1]++' "$MAPPING_FILE" > "$temp_file"
    
    local new_count=$(wc -l < "$temp_file" 2>/dev/null || echo "0")
    local removed=$((original_count - new_count))
    
    if [[ $removed -gt 0 ]]; then
        /bin/mv "$temp_file" "$MAPPING_FILE"
        print_info "重複エントリを ${removed} 件削除しました"
    else
        /bin/rm -f "$temp_file"
    fi
    
    release_mapping_lock
    return 0
}

add_mapping() {
    local volume_name=$1
    local bundle_id=$2
    local display_name=$3
    
    acquire_mapping_lock || return 1
    
    # Check if mapping already exists (by volume_name OR bundle_id)
    if /usr/bin/grep -q "^${volume_name}"$'\t' "$MAPPING_FILE" 2>/dev/null; then
        print_warning "ボリューム名が既に存在します: $volume_name"
        release_mapping_lock
        return 0
    fi
    
    if /usr/bin/grep -q $'\t'"${bundle_id}"$'\t' "$MAPPING_FILE" 2>/dev/null; then
        print_warning "Bundle IDが既に存在します: $bundle_id"
        release_mapping_lock
        return 0
    fi
    
    # Add new mapping
    echo "${volume_name}"$'\t'"${bundle_id}"$'\t'"${display_name}" >> "$MAPPING_FILE"
    
    release_mapping_lock
    print_success "マッピングを追加しました: $display_name"
    
    return 0
}

remove_mapping() {
    local bundle_id=$1
    
    acquire_mapping_lock || return 1
    
    # Create temporary file
    local temp_file="${MAPPING_FILE}.tmp"
    
    # Remove matching line
    /usr/bin/grep -v $'\t'"${bundle_id}"$'\t' "$MAPPING_FILE" > "$temp_file" 2>/dev/null || true
    
    # Replace original file
    /bin/mv "$temp_file" "$MAPPING_FILE"
    
    release_mapping_lock
    
    return 0
}

update_mapping() {
    local volume_name=$1
    local bundle_id=$2
    local display_name=$3
    
    # Remove old mapping if exists, then add new one
    remove_mapping "$bundle_id"
    add_mapping "$volume_name" "$bundle_id" "$display_name"
}

#######################################################
# Module 4: Volume Operations
#######################################################

# Optimized: Accept optional cached diskutil output
volume_exists() {
    local volume_name=$1
    local diskutil_cache="${2:-}"
    
    if [[ -n "$diskutil_cache" ]]; then
        echo "$diskutil_cache" | /usr/bin/grep -q "APFS Volume ${volume_name}"
    else
        /usr/sbin/diskutil list | /usr/bin/grep -q "APFS Volume ${volume_name}"
    fi
}

# Optimized: Accept optional cached diskutil output
get_volume_device() {
    local volume_name=$1
    local diskutil_cache="${2:-}"
    
    if [[ -n "$diskutil_cache" ]]; then
        echo "$diskutil_cache" | /usr/bin/grep "APFS Volume ${volume_name}" | /usr/bin/awk '{print $NF}'
    else
        /usr/sbin/diskutil list | /usr/bin/grep "APFS Volume ${volume_name}" | /usr/bin/awk '{print $NF}'
    fi
}

# Optimized: Accept optional cached diskutil output  
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

mount_volume() {
    local volume_name=$1
    local target_path=$2
    local force=${3:-false}
    local diskutil_cache="${4:-}"  # Optional: pre-cached diskutil list output
    
    # Cache diskutil list output if not provided (execute only once)
    if [[ -z "$diskutil_cache" ]]; then
        diskutil_cache=$(/usr/sbin/diskutil list 2>/dev/null)
    fi
    
    # Check if volume exists using cached output
    if ! volume_exists "$volume_name" "$diskutil_cache"; then
        print_error "ボリューム '${volume_name}' が見つかりません"
        return 1
    fi
    
    # Get current mount point using cached output
    local current_mount=$(get_mount_point "$volume_name" "$diskutil_cache")
    
    # If already mounted at target, nothing to do
    if [[ "$current_mount" == "$target_path" ]]; then
        print_info "既にマウント済みです: $target_path"
        return 0
    fi
    
    # If mounted elsewhere, unmount first
    if [[ -n "$current_mount" ]] && [[ "$current_mount" != "$target_path" ]]; then
        print_info "別の場所にマウントされています: $current_mount"
        print_info "アンマウント中..."
        
        local device=$(get_volume_device "$volume_name" "$diskutil_cache")
        if ! sudo /usr/sbin/diskutil unmount "$device" 2>/dev/null; then
            print_error "アンマウントに失敗しました"
            return 1
        fi
    fi
    
    # Check if target path exists and has content (mount protection)
    if [[ -e "$target_path" ]]; then
        local mount_check=$(/sbin/mount | /usr/bin/grep " on ${target_path} ")
        
        if [[ -z "$mount_check" ]]; then
            # Directory exists but is NOT a mount point
            # Check if it contains actual data (not just an empty mount point directory)
            # Ignore macOS metadata files (.DS_Store, .Spotlight-V100, etc.)
            # Use /bin/ls -A1 to ensure one item per line (not multi-column output)
            local content_check=$(/bin/ls -A1 "$target_path" 2>/dev/null | /usr/bin/grep -v -x -F '.DS_Store' | /usr/bin/grep -v -x -F '.Spotlight-V100' | /usr/bin/grep -v -x -F '.Trashes' | /usr/bin/grep -v -x -F '.fseventsd' | /usr/bin/grep -v -x -F '.TemporaryItems' | /usr/bin/grep -v -F '.com.apple.containermanagerd.metadata.plist')
            
            if [[ -n "$content_check" ]] && [[ "$force" != "true" ]]; then
                # Directory has actual content (not just metadata) = internal storage data exists
                print_warning "⚠️  内蔵ストレージにデータが存在します"
                print_info "検出されたデータ:"
                echo "$content_check" | while read -r line; do
                    echo "  - $line"
                done
                echo ""
                print_info "内部データを外部ボリュームに統合します..."
                echo ""
                
                # Create temporary mount point
                local temp_migrate="/tmp/playcover_migrate_$$"
                sudo /bin/mkdir -p "$temp_migrate"
                
                # Mount volume temporarily
                if sudo /sbin/mount -t apfs -o nobrowse "$device" "$temp_migrate" 2>/dev/null; then
                    print_info "データをコピー中..."
                    sudo /usr/bin/rsync -aH --progress "$target_path/" "$temp_migrate/" 2>/dev/null
                    local rsync_exit=$?
                    sudo /usr/sbin/diskutil unmount "$temp_migrate" >/dev/null 2>&1
                    sudo /bin/rm -rf "$temp_migrate"
                    
                    if [[ $rsync_exit -eq 0 ]] || [[ $rsync_exit -eq 23 ]] || [[ $rsync_exit -eq 24 ]]; then
                        print_success "データの移行が完了しました"
                        print_info "内部ストレージをクリア中..."
                        sudo rm -rf "$target_path"
                        # Continue to mount below
                    else
                        print_error "データの移行に失敗しました (rsync exit: $rsync_exit)"
                        return 1
                    fi
                else
                    print_error "一時マウントに失敗しました"
                    sudo /bin/rm -rf "$temp_migrate"
                    return 1
                fi
            fi
        fi
    else
        # Create target directory if it doesn't exist
        sudo /bin/mkdir -p "$target_path"
    fi
    
    # Mount the volume with nobrowse option to hide from Finder/Desktop
    local device=$(get_volume_device "$volume_name" "$diskutil_cache")
    
    # Use mount command directly with nobrowse option
    # diskutil doesn't support nobrowse directly, so we use mount -o nobrowse
    if sudo /sbin/mount -t apfs -o nobrowse "$device" "$target_path" >/dev/null 2>&1; then
        print_success "マウント成功: $target_path"
        return 0
    else
        print_error "マウント失敗"
        return 1
    fi
}

# Quit application before unmounting (v4.7.0)
quit_app_for_bundle() {
    local bundle_id=$1
    
    # Skip if bundle_id is empty or is PlayCover itself
    if [[ -z "$bundle_id" ]] || [[ "$bundle_id" == "$PLAYCOVER_BUNDLE_ID" ]]; then
        return 0
    fi
    
    # Force quit any process matching the bundle_id
    /usr/bin/pkill -9 -f "$bundle_id" 2>/dev/null || true
    
    # Wait a moment for cleanup
    sleep 0.3
}

unmount_volume() {
    local volume_name=$1
    local bundle_id=$2  # Optional: if provided, quit the app first
    local diskutil_cache="${3:-}"  # Optional: pre-cached diskutil list output
    
    # Cache diskutil list output if not provided (execute only once)
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
        quit_app_for_bundle "$bundle_id"
    fi
    
    local device=$(get_volume_device "$volume_name" "$diskutil_cache")
    
    if sudo /usr/sbin/diskutil unmount "$device" >/dev/null 2>&1; then
        print_success "アンマウント成功"
        return 0
    else
        print_error "アンマウント失敗"
        return 1
    fi
}

#######################################################
# Module 5: Storage Detection & Size Calculation
#######################################################

# Get container size in human-readable format
get_container_size() {
    local container_path=$1
    
    if [[ ! -e "$container_path" ]]; then
        echo "0B"
        return
    fi
    
    # Use du -sh for total size (no sudo needed for user's own files)
    local size=$(/usr/bin/du -sh "$container_path" 2>/dev/null | /usr/bin/awk '{print $1}')
    
    if [[ -z "$size" ]]; then
        echo "0B"
    else
        echo "$size"
    fi
}

# Get storage free space (APFS volumes share space in same container)
# Uses df -H for decimal units (MB, GB, TB) instead of binary (MiB, GiB, TiB)
get_storage_free_space() {
    local path="${1:-$HOME}"  # Default to home directory if no path provided
    
    # Get free space using df -H (decimal units: 10^n)
    local free_space=$(/bin/df -H "$path" 2>/dev/null | /usr/bin/tail -1 | /usr/bin/awk '{print $4}')
    
    if [[ -z "$free_space" ]]; then
        echo "不明"
    else
        echo "$free_space"
    fi
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
    local disk_location=$(diskutil info "/dev/$disk_id" 2>/dev/null | /usr/bin/awk -F: '/Device Location:/ {gsub(/^ */, "", $2); print $2}')
    
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
# Module 6: IPA Installation Functions
#######################################################

check_playcover_volume_mount() {
    if [[ ! -d "$PLAYCOVER_CONTAINER" ]]; then
        sudo /bin/mkdir -p "$PLAYCOVER_CONTAINER"
    fi
    
    local is_mounted=$(/sbin/mount | /usr/bin/grep " on ${PLAYCOVER_CONTAINER} " | /usr/bin/grep -c "apfs")
    
    if [[ $is_mounted -gt 0 ]]; then
        PLAYCOVER_VOLUME_DEVICE=$(/sbin/mount | /usr/bin/grep " on ${PLAYCOVER_CONTAINER} " | /usr/bin/awk '{print $1}')
        return 0
    fi
    
    if ! volume_exists "$PLAYCOVER_VOLUME_NAME"; then
        print_error "PlayCover ボリュームが見つかりません"
        print_info "初期セットアップスクリプトを実行してください"
        exit_with_cleanup 1 "PlayCover ボリュームが見つかりません"
    fi
    
    local volume_device=$(get_volume_device "$PLAYCOVER_VOLUME_NAME")
    
    if [[ -z "$volume_device" ]]; then
        print_error "ボリュームデバイスの取得に失敗しました"
        exit_with_cleanup 1 "ボリュームデバイス取得エラー"
    fi
    
    PLAYCOVER_VOLUME_DEVICE="/dev/${volume_device}"
    
    local current_mount=$(/usr/sbin/diskutil info "$PLAYCOVER_VOLUME_DEVICE" 2>/dev/null | /usr/bin/grep "Mount Point" | /usr/bin/sed 's/.*: *//')
    
    if [[ -n "$current_mount" ]] && [[ "$current_mount" != "Not applicable (no file system)" ]]; then
        if ! sudo /usr/sbin/diskutil unmount force "$PLAYCOVER_VOLUME_DEVICE" 2>/dev/null; then
            print_error "ボリュームのアンマウントに失敗しました"
            exit_with_cleanup 1 "ボリュームアンマウントエラー"
        fi
    fi
    
    if sudo /sbin/mount -t apfs -o nobrowse "$PLAYCOVER_VOLUME_DEVICE" "$PLAYCOVER_CONTAINER"; then
        sudo /usr/sbin/chown -R $(id -u):$(id -g) "$PLAYCOVER_CONTAINER" 2>/dev/null || true
    else
        print_error "ボリュームのマウントに失敗しました"
        exit_with_cleanup 1 "ボリュームマウントエラー"
    fi
}

select_ipa_files() {
    print_header "インストールする IPA ファイルの選択"
    
    local selected=$(osascript <<'EOF' 2>/dev/null
try
    tell application "System Events"
        activate
        set theFiles to choose file with prompt "インストールする IPA ファイルを選択してください（複数選択可）:" of type {"ipa", "public.archive", "public.data"} with multiple selections allowed
        
        set posixPaths to {}
        repeat with aFile in theFiles
            set end of posixPaths to POSIX path of aFile
        end repeat
        
        set AppleScript's text item delimiters to linefeed
        return posixPaths as text
    end tell
on error errorMessage
    -- User cancelled, return empty string
    return ""
end try
EOF
)
    
    if [[ -z "$selected" ]]; then
        print_info "キャンセルされました"
        echo ""
        echo -n "Enterキーでメニューに戻る..."
        read
        return 1
    fi
    
    while IFS= read -r line; do
        if [[ -n "$line" ]] && [[ -f "$line" ]]; then
            if [[ ! "$line" =~ \.ipa$ ]]; then
                print_error "選択されたファイルは IPA ファイルではありません: ${line}"
                echo ""
                echo -n "Enterキーでメニューに戻る..."
                read
                return 1
            fi
            SELECTED_IPAS+=("$line")
        fi
    done <<< "$selected"
    
    TOTAL_IPAS=${#SELECTED_IPAS[@]}
    
    if [[ $TOTAL_IPAS -eq 0 ]]; then
        print_error "有効な IPA ファイルが選択されませんでした"
        echo ""
        echo -n "Enterキーでメニューに戻る..."
        read
        return 1
    fi
    
    if [[ $TOTAL_IPAS -gt 1 ]]; then
        BATCH_MODE=true
        print_success "IPA ファイルを ${TOTAL_IPAS} 個選択しました"
    else
        # Using KSH_ARRAYS (0-based indexing)
        print_success "$(basename "${SELECTED_IPAS[0]}")"
    fi
    
    echo ""
}

extract_ipa_info() {
    local ipa_file=$1
    
    local temp_dir=$(mktemp -d)
    
    local plist_path=$(unzip -l "$ipa_file" 2>/dev/null | /usr/bin/grep -E "Payload/.*\.app/Info\.plist" | head -n 1 | /usr/bin/awk '{print $NF}')
    
    if [[ -z "$plist_path" ]]; then
        print_error "IPA 内に Info.plist が見つかりません"
        rm -rf "$temp_dir"
        return 1
    fi
    
    if ! unzip -q "$ipa_file" "$plist_path" -d "$temp_dir" 2>/dev/null; then
        print_error "Info.plist の解凍に失敗しました"
        rm -rf "$temp_dir"
        return 1
    fi
    
    local info_plist="${temp_dir}/${plist_path}"
    
    if [[ -z "$info_plist" ]]; then
        print_error "Info.plist が見つかりません"
        rm -rf "$temp_dir"
        return 1
    fi
    
    APP_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$info_plist" 2>/dev/null)
    
    if [[ -z "$APP_BUNDLE_ID" ]]; then
        print_error "Bundle Identifier の取得に失敗しました"
        rm -rf "$temp_dir"
        return 1
    fi
    
    APP_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$info_plist" 2>/dev/null)
    if [[ -z "$APP_VERSION" ]]; then
        APP_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$info_plist" 2>/dev/null)
    fi
    
    local app_name_en=""
    app_name_en=$(/usr/libexec/PlistBuddy -c "Print :CFBundleDisplayName" "$info_plist" 2>/dev/null)
    
    if [[ -z "$app_name_en" ]]; then
        app_name_en=$(/usr/libexec/PlistBuddy -c "Print :CFBundleName" "$info_plist" 2>/dev/null)
    fi
    
    if [[ -z "$app_name_en" ]]; then
        print_error "アプリ名の取得に失敗しました"
        rm -rf "$temp_dir"
        return 1
    fi
    
    local app_name_ja=""
    local strings_path=$(unzip -l "$ipa_file" 2>/dev/null | /usr/bin/grep -E "Payload/.*\.app/ja\.lproj/InfoPlist\.strings" | head -n 1 | /usr/bin/awk '{print $NF}')
    if [[ -n "$strings_path" ]]; then
        unzip -q "$ipa_file" "$strings_path" -d "$temp_dir" 2>/dev/null || true
        local ja_strings="${temp_dir}/${strings_path}"
        if [[ -f "$ja_strings" ]]; then
            app_name_ja=$(plutil -convert xml1 -o - "$ja_strings" 2>/dev/null | /usr/bin/grep -A 1 "CFBundleDisplayName" | tail -n 1 | /usr/bin/sed 's/.*<string>\(.*\)<\/string>.*/\1/' || true)
        fi
    fi
    
    if [[ -n "$app_name_ja" ]]; then
        APP_NAME="$app_name_ja"
    else
        APP_NAME="$app_name_en"
    fi
    
    APP_NAME_EN="$app_name_en"
    APP_VOLUME_NAME=$(echo "$APP_NAME_EN" | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null | /usr/bin/sed 's/[^a-zA-Z0-9]//g' || echo "$APP_NAME_EN" | /usr/bin/sed 's/[^a-zA-Z0-9]//g')
    
    rm -rf "$temp_dir"
    
    print_info "${APP_NAME} (${APP_VERSION})"
    echo ""
    return 0
}

find_apfs_container() {
    local physical_disk=$1
    local container=""
    
    if [[ "$physical_disk" =~ disk[0-9]+ ]]; then
        local volume_info=$(/usr/sbin/diskutil info "$PLAYCOVER_VOLUME_DEVICE" 2>/dev/null)
        container=$(echo "$volume_info" | /usr/bin/grep "APFS Container:" | /usr/bin/awk '{print $NF}')
        
        if [[ -n "$container" ]]; then
            echo "$container"
            return 0
        fi
    fi
    
    local disk_num=$(echo "$physical_disk" | /usr/bin/sed -E 's|.*/disk([0-9]+).*|\1|')
    local disk_device="/dev/disk${disk_num}"
    
    local disk_info=$(/usr/sbin/diskutil info "$disk_device" 2>/dev/null)
    if echo "$disk_info" | /usr/bin/grep -q "APFS Container Scheme"; then
        container="disk${disk_num}"
        echo "$container"
        return 0
    fi
    
    echo "$container"
}

select_installation_disk() {
    local playcover_disk=""
    
    if [[ -n "$PLAYCOVER_VOLUME_DEVICE" ]]; then
        playcover_disk=$(echo "$PLAYCOVER_VOLUME_DEVICE" | /usr/bin/sed -E 's|/dev/(disk[0-9]+).*|\1|')
        local container=$(find_apfs_container "${playcover_disk}")
        
        if [[ -n "$container" ]]; then
            SELECTED_DISK="$container"
        else
            print_error "APFS コンテナの検出に失敗しました"
            return 1
        fi
    else
        print_error "PlayCover ボリュームのデバイス情報が見つかりません"
        return 1
    fi
    
    return 0
}

create_app_volume() {
    local existing_volume=""
    existing_volume=$(/usr/sbin/diskutil info "${APP_VOLUME_NAME}" 2>/dev/null | /usr/bin/awk '/Device Node:/ {gsub(/\/dev\//, "", $NF); print $NF}')
    
    if [[ -z "$existing_volume" ]]; then
        existing_volume=$(/usr/sbin/diskutil list 2>/dev/null | /usr/bin/grep -E "${APP_VOLUME_NAME}" | /usr/bin/grep "APFS" | head -n 1 | /usr/bin/awk '{print $NF}')
    fi
    
    if [[ -n "$existing_volume" ]]; then
        return 0
    fi
    
    if sudo /usr/sbin/diskutil apfs addVolume "$SELECTED_DISK" APFS "${APP_VOLUME_NAME}" -nomount > /tmp/apfs_create_app.log 2>&1; then
        sleep 1
        return 0
    else
        print_error "ボリュームの作成に失敗しました"
        /bin/cat /tmp/apfs_create_app.log
        return 1
    fi
}

mount_app_volume() {
    local target_path="${HOME}/Library/Containers/${APP_BUNDLE_ID}"
    
    if mount_volume "$APP_VOLUME_NAME" "$target_path"; then
        return 0
    else
        print_error "ボリュームのマウントに失敗しました"
        return 1
    fi
}

install_ipa_to_playcover() {
    local ipa_file=$1
    
    # Check if app is already installed
    local playcover_apps="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/Applications"
    local existing_app_path=""
    local existing_version=""
    local overwrite_choice=""
    local existing_mtime=0
    
    if [[ -d "$playcover_apps" ]]; then
        # Search for app with matching Bundle ID
        while IFS= read -r app_path; do
            if [[ -f "${app_path}/Info.plist" ]]; then
                local bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "${app_path}/Info.plist" 2>/dev/null)
                
                if [[ "$bundle_id" == "$APP_BUNDLE_ID" ]]; then
                    existing_app_path="$app_path"
                    existing_version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${app_path}/Info.plist" 2>/dev/null)
                    # Record CURRENT modification time BEFORE installation
                    existing_mtime=$(stat -f %m "$app_path" 2>/dev/null || echo 0)
                    break
                fi
            fi
        done < <(find "$playcover_apps" -name "*.app" -maxdepth 1 -type d 2>/dev/null)
        
        # Check if existing app was found and ask for confirmation OUTSIDE the loop
        if [[ -n "$existing_app_path" ]]; then
            print_warning "${APP_NAME} (${existing_version}) は既にインストール済みです"
            echo -n "上書きしますか？ (Y/n): "
            read overwrite_choice </dev/tty
            
            # Default to Yes if empty
            overwrite_choice=${overwrite_choice:-Y}
            
            if [[ ! "$overwrite_choice" =~ ^[Yy]$ ]]; then
                print_info "スキップしました"
                INSTALL_SUCCESS+=("$APP_NAME (スキップ)")
                
                # Still update mapping even if skipped
                update_mapping "$APP_VOLUME_NAME" "$APP_BUNDLE_ID" "$APP_NAME"
                
                echo ""
                return 0
            fi
        fi
    fi
    
    echo ""
    print_info "PlayCover でインストール中（完了まで待機）..."
    echo ""
    
    # Open IPA with PlayCover
    if ! open -a PlayCover "$ipa_file"; then
        print_error "PlayCover の起動に失敗しました"
        INSTALL_FAILED+=("$APP_NAME")
        return 1
    fi
    

    
    local max_wait=300  # 5 minutes
    local elapsed=0
    local check_interval=3
    local initial_check_done=false
    
    # PlayCover app settings path
    local app_settings_dir="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/App Settings"
    local app_settings_plist="${app_settings_dir}/${APP_BUNDLE_ID}.plist"
    
    # Track settings file updates (v5.0.0: Update count based detection)
    local settings_update_count=0
    local last_settings_mtime=0
    local initial_settings_exists=false
    
    # Check if settings file exists before installation starts
    if [[ -f "$app_settings_plist" ]]; then
        initial_settings_exists=true
        last_settings_mtime=$(stat -f %m "$app_settings_plist" 2>/dev/null || echo 0)
    fi
    
    # Detection Method (v5.0.1 - Settings File Update Count - Unified):
    # Ultra-simple approach based on real-world observation:
    # 
    # BOTH NEW and OVERWRITE INSTALL:
    #   - Wait for settings file 2nd update → Complete immediately
    # 
    # Reasoning:
    #   - NEW: 1st update happens too early (still processing)
    #   - OVERWRITE: 1st update is initial, 2nd is completion
    #   - Unified approach: Always wait for 2nd update
    # 
    # No stability checks, no complex conditions.
    # Just count settings file updates and complete on 2nd update.
    
    while [[ $elapsed -lt $max_wait ]]; do
        # Check if PlayCover is still running BEFORE sleep (v4.8.1 - immediate crash detection)
        if ! pgrep -x "PlayCover" > /dev/null; then
            echo ""
            echo ""
            print_error "PlayCover が終了しました"
            print_warning "インストール中にクラッシュした可能性があります"
            echo ""
            
            # Check if installation actually succeeded despite crash (using robust verification)
            local installation_succeeded=false
            if [[ -d "$playcover_apps" ]]; then
                while IFS= read -r app_path; do
                    if [[ -f "${app_path}/Info.plist" ]]; then
                        local bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "${app_path}/Info.plist" 2>/dev/null)
                        if [[ "$bundle_id" == "$APP_BUNDLE_ID" ]]; then
                            local current_mtime=$(stat -f %m "$app_path" 2>/dev/null || echo 0)
                            if [[ $current_mtime -gt $existing_mtime ]]; then
                                # Verify structure integrity
                                if [[ -d "${app_path}/_CodeSignature" ]]; then
                                    local app_name=$(/usr/libexec/PlistBuddy -c "Print :CFBundleName" "${app_path}/Info.plist" 2>/dev/null)
                                    if [[ -n "$app_name" ]]; then
                                        # v4.9.0: Simple check - settings file exists and is stable
                                        if [[ -f "$app_settings_plist" ]]; then
                                            installation_succeeded=true
                                            break
                                        fi
                                    fi
                                fi
                            fi
                        fi
                    fi
                done < <(find "$playcover_apps" -name "*.app" -maxdepth 1 -type d 2>/dev/null)
            fi
            
            if [[ "$installation_succeeded" == true ]]; then
                print_info "ただし、アプリのインストールは完了していました"
                print_success "インストール成功"
                INSTALL_SUCCESS+=("$APP_NAME")
                update_mapping "$APP_VOLUME_NAME" "$APP_BUNDLE_ID" "$APP_NAME"
                echo ""
                
                # Restart PlayCover for next installation if in batch mode
                if [[ $BATCH_MODE == true ]] && [[ $CURRENT_IPA_INDEX -lt $TOTAL_IPAS ]]; then
                    print_info "次のインストールのため PlayCover を準備中..."
                    sleep 2
                fi
                
                return 0
            else
                print_error "インストールは完了していませんでした"
                INSTALL_FAILED+=("$APP_NAME (PlayCoverクラッシュ)")
                echo ""
                
                # In batch mode, offer to continue automatically
                if [[ $BATCH_MODE == true ]] && [[ $CURRENT_IPA_INDEX -lt $TOTAL_IPAS ]]; then
                    print_warning "残り $((TOTAL_IPAS - CURRENT_IPA_INDEX)) 個のIPAがあります"
                    echo ""
                    echo -n "次のIPAに進みますか？ (Y/n): "
                    read continue_choice </dev/tty
                    
                    if [[ "$continue_choice" =~ ^[Nn]$ ]]; then
                        return 1
                    else
                        print_info "次のインストールのため PlayCover を準備中..."
                        sleep 2
                        return 0
                    fi
                else
                    return 1
                fi
            fi
        fi
        
        # Check if app was installed
        if [[ -d "$playcover_apps" ]]; then
            local found=false
            local current_app_mtime=0
            
            while IFS= read -r app_path; do
                if [[ -f "${app_path}/Info.plist" ]]; then
                    local bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "${app_path}/Info.plist" 2>/dev/null)
                    
                    if [[ "$bundle_id" == "$APP_BUNDLE_ID" ]]; then
                        # Phase 1: Basic structure validation
                        local structure_valid=false
                        
                        # Check Info.plist validity
                        if [[ -f "${app_path}/Info.plist" ]]; then
                            local app_name=$(/usr/libexec/PlistBuddy -c "Print :CFBundleName" "${app_path}/Info.plist" 2>/dev/null)
                            local app_version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${app_path}/Info.plist" 2>/dev/null)
                            
                            # Check _CodeSignature directory
                            if [[ -d "${app_path}/_CodeSignature" ]] && [[ -n "$app_name" ]] && [[ -n "$app_version" ]]; then
                                structure_valid=true
                            fi
                        fi
                        
                        if [[ "$structure_valid" == false ]]; then
                            continue
                        fi
                        
                        # Phase 2: Settings file update count check (v5.0.0)
                        if [[ -f "$app_settings_plist" ]]; then
                            local current_settings_mtime=$(stat -f %m "$app_settings_plist" 2>/dev/null || echo 0)
                            
                            if [[ $current_settings_mtime -gt 0 ]]; then
                                # Check if settings file was updated
                                if [[ $current_settings_mtime -ne $last_settings_mtime ]]; then
                                    # Settings file was updated!
                                    ((settings_update_count++))
                                    last_settings_mtime=$current_settings_mtime
                                fi
                                
                                # v5.0.1: Unified completion logic - Always wait for 2nd update
                                if [[ "$structure_valid" == true ]]; then
                                    # Both NEW and OVERWRITE: Wait for 2nd update = Complete
                                    if [[ $settings_update_count -ge 2 ]]; then
                                        found=true
                                        break
                                    fi
                                fi
                            fi
                        fi
                    fi
                fi
            done < <(find "$playcover_apps" -name "*.app" -maxdepth 1 -type d 2>/dev/null)
            
            if [[ "$found" == true ]]; then
                # v4.8.1: Final verification - ensure PlayCover is still running
                if ! pgrep -x "PlayCover" > /dev/null; then
                    echo ""
                    echo ""
                    print_warning "完了判定直後に PlayCover が終了しました"
                    print_info "最終確認を実施中..."
                    sleep 2
                    
                    # Re-verify the installation is truly complete
                    if [[ -f "${app_path}/Info.plist" ]] && [[ -f "$app_settings_plist" ]]; then
                        echo ""
                        print_success "インストールは正常に完了していました"
                    else
                        echo ""
                        print_error "インストールが不完全です"
                        INSTALL_FAILED+=("$APP_NAME (完了直後にPlayCoverクラッシュ)")
                        return 1
                    fi
                fi
                
                echo ""
                print_success "インストールが完了しました"
                INSTALL_SUCCESS+=("$APP_NAME")
                
                update_mapping "$APP_VOLUME_NAME" "$APP_BUNDLE_ID" "$APP_NAME"
                
                echo ""
                return 0
            fi
        fi
        
        initial_check_done=true
        
        sleep $check_interval
        elapsed=$((elapsed + check_interval))
        
        # Show progress indicator with detailed status (v5.0.1 - Unified)
        if [[ $settings_update_count -ge 2 ]]; then
            echo -n "✓"  # Complete (shouldn't reach here)
        elif [[ $settings_update_count -eq 1 ]]; then
            echo -n "◇"  # 1st update (waiting for 2nd)
        elif [[ $last_settings_mtime -gt 0 ]]; then
            echo -n "◆"  # Settings file exists but not updated yet
        else
            echo -n "."  # Waiting for 1st update
        fi
    done
    
    echo ""
    echo ""
    print_warning "インストール完了の自動検知がタイムアウトしました"
    echo ""
    echo -n "PlayCover でインストールが完了したら Enter キーを押してください: "
    read </dev/tty
    
    # Final verification
    if [[ -d "$playcover_apps" ]]; then
        while IFS= read -r app_path; do
            if [[ -f "${app_path}/Info.plist" ]]; then
                local bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "${app_path}/Info.plist" 2>/dev/null)
                
                if [[ "$bundle_id" == "$APP_BUNDLE_ID" ]]; then
                    print_success "インストールが確認されました"
                    INSTALL_SUCCESS+=("$APP_NAME")
                    
                    update_mapping "$APP_VOLUME_NAME" "$APP_BUNDLE_ID" "$APP_NAME"
                    
                    echo ""
                    return 0
                fi
            fi
        done < <(find "$playcover_apps" -name "*.app" -maxdepth 1 -type d 2>/dev/null)
    fi
    
    print_error "インストールが確認できませんでした"
    INSTALL_FAILED+=("$APP_NAME")
    echo ""
    return 1
}

#######################################################
# Module 7: Volume Management Functions (from Script 2)
#######################################################

ensure_playcover_main_volume() {
    if ! volume_exists "$PLAYCOVER_VOLUME_NAME"; then
        print_warning "PlayCover メインボリュームが見つかりません"
        return 1
    fi
    
    local pc_current_mount=$(get_mount_point "$PLAYCOVER_VOLUME_NAME")
    
    if [[ "$pc_current_mount" == "$PLAYCOVER_CONTAINER" ]]; then
        return 0
    fi
    
    print_info "PlayCover メインボリュームをマウント中..."
    mount_volume "$PLAYCOVER_VOLUME_NAME" "$PLAYCOVER_CONTAINER" "true"
}




individual_volume_control() {
    clear
    print_header "個別ボリューム操作"
    
    # Read mapping file directly
    if [[ ! -f "$MAPPING_FILE" ]]; then
        print_warning "マッピングファイルが見つかりません: $MAPPING_FILE"
        wait_for_enter
        return
    fi
    
    # Build array from file
    local -a mappings_array=()
    while IFS=$'\t' read -r volume_name bundle_id display_name; do
        # Skip empty lines
        [[ -z "$volume_name" || -z "$bundle_id" ]] && continue
        
        # Add to array
        mappings_array+=("${volume_name}|${bundle_id}|${display_name}")
    done < "$MAPPING_FILE"
    
    # Check if we have any mappings
    if [[ ${#mappings_array[@]} -eq 0 ]]; then
        print_warning "登録されているアプリボリュームがありません"
        wait_for_enter
        return
    fi
    
    echo "登録されているボリューム:"
    echo ""
    
    # Cache diskutil output once for performance
    local diskutil_cache=$(/usr/sbin/diskutil list 2>/dev/null)
    local mount_cache=$(/sbin/mount 2>/dev/null)
    
    # Display volumes with detailed status (single column)
    local index=1
    for ((i=0; i<${#mappings_array[@]}; i++)); do
        IFS='|' read -r volume_name bundle_id display_name <<< "${mappings_array[$i]}"
        
        local target_path="${HOME}/Library/Containers/${bundle_id}"
        local status_line=""
        local extra_info=""
        
        # Check if volume exists (using cached diskutil output)
        if ! echo "$diskutil_cache" | /usr/bin/grep -q "APFS Volume ${volume_name}"; then
            status_line="❌ ボリュームが見つかりません"
        else
            # Check actual mount point of the volume (could be anywhere)
            local actual_mount=$(get_mount_point "$volume_name")
            
            if [[ -n "$actual_mount" ]]; then
                # Volume is mounted somewhere
                if [[ "$actual_mount" == "$target_path" ]]; then
                    status_line="🟢 マウント済: ${actual_mount}"
                else
                    status_line="⚠️  マウント位置異常: ${actual_mount}"
                fi
            else
                # Volume is not mounted - check for internal storage
                status_line="⚪️ 未マウント"
                
                # Quick check: only if path exists and not a mount point
                if [[ -d "$target_path" ]] && ! echo "$mount_cache" | /usr/bin/grep -q " on ${target_path} "; then
                    # Check if directory has actual content (exclude macOS metadata)
                    local has_content=$(/bin/ls -A1 "$target_path" 2>/dev/null | /usr/bin/grep -v -x -F '.DS_Store' | /usr/bin/grep -v -x -F '.Spotlight-V100' | /usr/bin/grep -v -x -F '.Trashes' | /usr/bin/grep -v -x -F '.fseventsd' | /usr/bin/grep -v -x -F '.TemporaryItems' | /usr/bin/grep -v -F '.com.apple.containermanagerd.metadata.plist' | /usr/bin/head -1)
                    if [[ -n "$has_content" ]]; then
                        extra_info=" | 🏠 内蔵ストレージにデータ有"
                    fi
                fi
            fi
        fi
        
        echo "  ${index}. ${display_name}"
        echo "      ${status_line}${extra_info}"
        echo ""
        ((index++))
    done
    
    print_separator
    echo ""
    echo "操作を選択してください:"
    echo "  [番号] : 個別マウント/アンマウント"
    echo "  [m]    : 全ボリュームをマウント"
    echo "  [u]    : 全ボリュームをアンマウント"
    echo "  [0]    : 戻る"
    echo ""
    echo -n "選択: "
    read choice
    
    if [[ "$choice" == "0" ]]; then
        return
    fi
    
    # Batch operations
    if [[ "$choice" == "m" ]] || [[ "$choice" == "M" ]]; then
        authenticate_sudo
        batch_mount_all
        individual_volume_control
        return
    fi
    
    if [[ "$choice" == "u" ]] || [[ "$choice" == "U" ]]; then
        authenticate_sudo
        batch_unmount_all
        individual_volume_control
        return
    fi
    
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ $choice -lt 1 ]] || [[ $choice -gt ${#mappings_array[@]} ]]; then
        print_error "無効な選択です"
        sleep 2
        individual_volume_control
        return
    fi
    
    # Convert 1-based user input to 0-based array index
    local array_index=$((choice - 1))
    local selected_mapping="${mappings_array[$array_index]}"
    IFS='|' read -r volume_name bundle_id display_name <<< "$selected_mapping"
    
    authenticate_sudo
    
    local target_path="${HOME}/Library/Containers/${bundle_id}"
    local current_mount=$(get_mount_point "$volume_name")
    
    # Quick switch without confirmation
    if [[ -n "$current_mount" ]]; then
        # Currently mounted -> Unmount
        if ! volume_exists "$volume_name"; then
            clear
            print_header "${display_name} の操作"
            echo ""
            print_error "ボリュームが見つかりません"
            wait_for_enter
            individual_volume_control
            return
        fi
        
        # Special check for PlayCover volume - ensure PlayCover is not running
        if [[ "$bundle_id" == "$PLAYCOVER_BUNDLE_ID" ]] && is_playcover_running; then
            clear
            print_header "${display_name} の操作"
            echo ""
            print_error "PlayCoverが起動中です"
            print_info "PlayCoverを終了してから再度実行してください"
            wait_for_enter
            individual_volume_control
            return
        fi
        
        # Quit app first
        if [[ -n "$bundle_id" ]]; then
            /usr/bin/pkill -9 -f "$bundle_id" 2>/dev/null || true
            sleep 0.3
        fi
        
        local device=$(get_volume_device "$volume_name")
        if sudo /usr/sbin/diskutil unmount "$device" >/dev/null 2>&1; then
            # Success - show result
            clear
            print_header "${display_name} の操作"
            echo ""
            print_success "アンマウントしました"
            wait_for_enter
            individual_volume_control
            return
        else
            # Failed - show error
            clear
            print_header "${display_name} の操作"
            echo ""
            if /usr/bin/pgrep -f "$bundle_id" >/dev/null 2>&1; then
                print_error "アンマウント失敗: アプリが実行中です"
            else
                print_error "アンマウント失敗: ファイルが使用中の可能性があります"
            fi
            wait_for_enter
            individual_volume_control
            return
        fi
    else
        # Currently unmounted -> Mount
        if ! volume_exists "$volume_name"; then
            clear
            print_header "${display_name} の操作"
            echo ""
            print_error "ボリュームが見つかりません"
            wait_for_enter
            individual_volume_control
            return
        fi
        
        # Check for internal storage conflict (same logic as mount_volume)
        if [[ -e "$target_path" ]]; then
            local mount_check=$(/sbin/mount | /usr/bin/grep " on ${target_path} ")
            
            if [[ -z "$mount_check" ]]; then
                # Directory exists but is NOT a mount point
                # Check if it contains actual data (ignore macOS metadata)
                local content_check=$(/bin/ls -A1 "$target_path" 2>/dev/null | /usr/bin/grep -v -x -F '.DS_Store' | /usr/bin/grep -v -x -F '.Spotlight-V100' | /usr/bin/grep -v -x -F '.Trashes' | /usr/bin/grep -v -x -F '.fseventsd' | /usr/bin/grep -v -x -F '.TemporaryItems' | /usr/bin/grep -v -F '.com.apple.containermanagerd.metadata.plist')
                
                if [[ -n "$content_check" ]]; then
                    # Directory has actual content = internal storage data exists
                    clear
                    print_header "${display_name} の操作"
                    echo ""
                    print_error "内蔵ストレージにデータが存在します"
                    print_warning "先に内蔵データを削除またはバックアップしてください"
                    echo ""
                    echo -n "Enterキーで続行..."
                    read
                    individual_volume_control
                    return
                fi
            fi
        fi
        
        # Ensure PlayCover volume is mounted first (dependency requirement)
        if [[ "$bundle_id" != "$PLAYCOVER_BUNDLE_ID" ]]; then
            if ! ensure_playcover_main_volume >/dev/null 2>&1; then
                clear
                print_header "${display_name} の操作"
                echo ""
                print_error "PlayCover ボリュームのマウントに失敗しました"
                wait_for_enter
                individual_volume_control
                return
            fi
        fi
        
        # Try to mount
        local device=$(get_volume_device "$volume_name")
        if sudo /usr/sbin/diskutil mount -mountPoint "$target_path" "$device" >/dev/null 2>&1; then
            # Success - show result
            clear
            print_header "${display_name} の操作"
            echo ""
            print_success "マウントしました"
            wait_for_enter
            individual_volume_control
            return
        else
            # Failed - show error
            clear
            print_header "${display_name} の操作"
            echo ""
            print_error "マウントに失敗しました"
            wait_for_enter
            individual_volume_control
            return
        fi
    fi
}

# Batch mount all volumes (for individual volume control menu)
batch_mount_all() {
    clear
    print_header "全ボリュームをマウント"
    
    # Read mapping file directly
    if [[ ! -f "$MAPPING_FILE" ]]; then
        print_warning "マッピングファイルが見つかりません: $MAPPING_FILE"
        wait_for_enter
        return
    fi
    
    # Build array from file
    local -a mappings_array=()
    while IFS=$'\t' read -r volume_name bundle_id display_name; do
        [[ -z "$volume_name" || -z "$bundle_id" ]] && continue
        mappings_array+=("${volume_name}|${bundle_id}|${display_name}")
    done < "$MAPPING_FILE"
    
    if [[ ${#mappings_array[@]} -eq 0 ]]; then
        print_warning "登録されているアプリボリュームがありません"
        wait_for_enter
        return
    fi
    
    echo "ボリュームをマウント中..."
    echo ""
    
    local success_count=0
    local fail_count=0
    local index=1
    
    for ((i=0; i<${#mappings_array[@]}; i++)); do
        IFS='|' read -r volume_name bundle_id display_name <<< "${mappings_array[$i]}"
        
        echo "  ${index}. ${CYAN}${display_name}${NC}"
        
        if [[ "$bundle_id" == "$PLAYCOVER_BUNDLE_ID" ]]; then
            local pc_current_mount=$(get_mount_point "$PLAYCOVER_VOLUME_NAME")
            
            if [[ -n "$pc_current_mount" ]] && [[ "$pc_current_mount" != "$PLAYCOVER_CONTAINER" ]]; then
                echo "     ${YELLOW}⚠️  マウント位置が異なる為修正します${NC}"
                local pc_device=$(get_volume_device "$PLAYCOVER_VOLUME_NAME")
                if sudo /usr/sbin/diskutil unmount "$pc_device" >/dev/null 2>&1; then
                    if sudo /sbin/mount -t apfs -o nobrowse "$pc_device" "$PLAYCOVER_CONTAINER" >/dev/null 2>&1; then
                        echo "     ${GREEN}✅ マウント成功: ${PLAYCOVER_CONTAINER}${NC}"
                        ((success_count++))
                    else
                        echo "     ${RED}❌ マウント失敗: 再マウントに失敗${NC}"
                        ((fail_count++))
                    fi
                else
                    echo "     ${RED}❌ マウント失敗: アンマウントに失敗${NC}"
                    ((fail_count++))
                fi
            elif [[ "$pc_current_mount" == "$PLAYCOVER_CONTAINER" ]]; then
                echo "     ${GREEN}✅ 既にマウント済: ${PLAYCOVER_CONTAINER}${NC}"
                ((success_count++))
            else
                if ! volume_exists "$PLAYCOVER_VOLUME_NAME"; then
                    echo "     ${RED}❌ マウント失敗: ボリュームが見つかりません${NC}"
                    ((fail_count++))
                else
                    local pc_device=$(get_volume_device "$PLAYCOVER_VOLUME_NAME")
                    if sudo /sbin/mount -t apfs -o nobrowse "$pc_device" "$PLAYCOVER_CONTAINER" >/dev/null 2>&1; then
                        echo "     ${GREEN}✅ マウント成功: ${PLAYCOVER_CONTAINER}${NC}"
                        ((success_count++))
                    else
                        echo "     ${RED}❌ マウント失敗: マウントコマンドが失敗${NC}"
                        ((fail_count++))
                    fi
                fi
            fi
        else
            local target_path="${HOME}/Library/Containers/${bundle_id}"
            local current_mount=$(get_mount_point "$volume_name")
            
            if [[ -n "$current_mount" ]] && [[ "$current_mount" != "$target_path" ]]; then
                echo "     ${YELLOW}⚠️  マウント位置が異なる為修正します${NC}"
                local device=$(get_volume_device "$volume_name")
                if sudo /usr/sbin/diskutil unmount "$device" >/dev/null 2>&1; then
                    if sudo /sbin/mount -t apfs -o nobrowse "$device" "$target_path" >/dev/null 2>&1; then
                        echo "     ${GREEN}✅ マウント成功: ${target_path}${NC}"
                        ((success_count++))
                    else
                        echo "     ${RED}❌ マウント失敗: 再マウントに失敗${NC}"
                        ((fail_count++))
                    fi
                else
                    echo "     ${RED}❌ マウント失敗: アンマウントに失敗${NC}"
                    ((fail_count++))
                fi
            elif [[ "$current_mount" == "$target_path" ]]; then
                echo "     ${GREEN}✅ 既にマウント済: ${target_path}${NC}"
                ((success_count++))
            else
                if ! volume_exists "$volume_name"; then
                    echo "     ${RED}❌ マウント失敗: ボリュームが見つかりません${NC}"
                    ((fail_count++))
                else
                    if [[ -e "$target_path" ]]; then
                        local mount_check=$(/sbin/mount | /usr/bin/grep " on ${target_path} ")
                        if [[ -z "$mount_check" ]]; then
                            local content_check=$(/bin/ls -A1 "$target_path" 2>/dev/null | /usr/bin/grep -v -x -F '.DS_Store' | /usr/bin/grep -v -x -F '.Spotlight-V100' | /usr/bin/grep -v -x -F '.Trashes' | /usr/bin/grep -v -x -F '.fseventsd' | /usr/bin/grep -v -x -F '.TemporaryItems' | /usr/bin/grep -v -F '.com.apple.containermanagerd.metadata.plist')
                            if [[ -n "$content_check" ]]; then
                                echo "     ${RED}❌ マウント失敗: 内蔵ストレージにデータが存在します${NC}"
                                ((fail_count++))
                                echo ""
                                ((index++))
                                continue
                            fi
                        fi
                    fi
                    
                    local device=$(get_volume_device "$volume_name")
                    if sudo /sbin/mount -t apfs -o nobrowse "$device" "$target_path" >/dev/null 2>&1; then
                        echo "     ${GREEN}✅ マウント成功: ${target_path}${NC}"
                        ((success_count++))
                    else
                        echo "     ${RED}❌ マウント失敗: マウントコマンドが失敗${NC}"
                        ((fail_count++))
                    fi
                fi
            fi
        fi
        
        echo ""
        ((index++))
    done
    
    print_separator
    echo ""
    echo "${BLUE}ℹ️  成功: ${success_count} / 失敗: ${fail_count}${NC}"
    
    if [[ $fail_count -eq 0 ]]; then
        echo "${GREEN}✅ 全ボリュームのマウント完了${NC}"
    elif [[ $success_count -eq 0 ]]; then
        echo "${RED}❌ マウント失敗: 全てのボリュームがマウントできませんでした${NC}"
        echo ""
        echo "${YELLOW}対処法:${NC}"
        echo "  1. 外部SSDが正しく接続されているか確認"
        echo "  2. ボリュームが作成されているか確認（メニュー9）"
        echo "  3. 既存のマウント状態を確認（メニュー5）"
    else
        echo "${YELLOW}⚠️  一部マウントに失敗したボリュームがあります${NC}"
    fi
    wait_for_enter
}

# Batch unmount all volumes (for individual volume control menu)
batch_unmount_all() {
    clear
    print_header "全ボリュームをアンマウント"
    
    # Check if PlayCover is running
    if is_playcover_running; then
        print_error "PlayCoverが起動中です"
        print_info "PlayCoverを終了してから再度実行してください"
        wait_for_enter
        return
    fi
    
    # Read mapping file directly
    if [[ ! -f "$MAPPING_FILE" ]]; then
        print_warning "マッピングファイルが見つかりません: $MAPPING_FILE"
        wait_for_enter
        return
    fi
    
    # Build array from file
    local -a mappings_array=()
    while IFS=$'\t' read -r volume_name bundle_id display_name; do
        [[ -z "$volume_name" || -z "$bundle_id" ]] && continue
        mappings_array+=("${volume_name}|${bundle_id}|${display_name}")
    done < "$MAPPING_FILE"
    
    if [[ ${#mappings_array[@]} -eq 0 ]]; then
        print_warning "登録されているアプリボリュームがありません"
        wait_for_enter
        return
    fi
    
    echo "ボリュームをアンマウント中..."
    echo ""
    
    local success_count=0
    local fail_count=0
    
    for ((i=${#mappings_array[@]}-1; i>=0; i--)); do
        IFS='|' read -r volume_name bundle_id display_name <<< "${mappings_array[$i]}"
        
        local display_index=$((i + 1))
        echo "  ${display_index}. ${CYAN}${display_name}${NC}"
        
        local current_mount=$(get_mount_point "$volume_name")
        
        if [[ -z "$current_mount" ]]; then
            echo "     ${GREEN}✅ 既にアンマウント済${NC}"
            ((success_count++))
        else
            if [[ -n "$bundle_id" ]]; then
                /usr/bin/pkill -9 -f "$bundle_id" 2>/dev/null || true
                sleep 0.3
            fi
            
            local device=$(get_volume_device "$volume_name")
            if sudo /usr/sbin/diskutil unmount "$device" >/dev/null 2>&1; then
                echo "     ${GREEN}✅ アンマウント成功${NC}"
                ((success_count++))
            else
                if /usr/bin/pgrep -f "$bundle_id" >/dev/null 2>&1; then
                    echo "     ${RED}❌ アンマウント失敗: アプリが実行中です${NC}"
                else
                    echo "     ${RED}❌ アンマウント失敗: ファイルが使用中の可能性があります${NC}"
                fi
                ((fail_count++))
            fi
        fi
        echo ""
    done
    
    print_separator
    echo ""
    echo "${BLUE}ℹ️  成功: ${success_count} / 失敗: ${fail_count}${NC}"
    
    if [[ $fail_count -eq 0 ]]; then
        echo "${GREEN}✅ 全ボリュームのアンマウント完了${NC}"
    elif [[ $success_count -eq 0 ]]; then
        echo "${RED}❌ アンマウント失敗: 全てのボリュームがアンマウントできませんでした${NC}"
        echo ""
        echo "${YELLOW}対処法:${NC}"
        echo "  1. PlayCoverとアプリを終了してから再試行"
        echo "  2. Finderでファイルを開いている場合は閉じる"
        echo "  3. 強制アンマウント: diskutil unmount force /dev/diskX"
    else
        echo "${YELLOW}⚠️  一部アンマウントに失敗したボリュームがあります${NC}"
    fi
    wait_for_enter
}

# Get drive name for display (v4.7.0)
get_drive_name() {
    local playcover_device=$1
    
    if [[ -z "$playcover_device" ]]; then
        echo "不明なドライブ"
        return
    fi
    
    local disk_id=$(echo "$playcover_device" | /usr/bin/sed -E 's|/dev/(disk[0-9]+).*|\1|')
    local drive_info=$(/usr/sbin/diskutil info "$disk_id" 2>/dev/null)
    
    if [[ -n "$drive_info" ]]; then
        # Try to get device name
        local device_name=$(echo "$drive_info" | /usr/bin/grep "Device / Media Name:" | /usr/bin/sed 's/.*: *//')
        if [[ -n "$device_name" ]]; then
            echo "$device_name"
            return
        fi
        
        # Fallback to disk identifier
        echo "$disk_id"
    else
        echo "不明なドライブ"
    fi
}

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
    echo -n "続行しますか？ (Y/n): "
    read confirm
    
    # Default to Yes if empty
    confirm=${confirm:-Y}
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "キャンセルしました"
        wait_for_enter
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
        
        if [[ ${#mappings_array[@]} -gt 0 ]]; then
            print_info "登録済みボリュームをアンマウント中..."
            echo ""
            
            local success_count=0
            local fail_count=0
            
            # Unmount in reverse order (apps first, PlayCover last)
            for ((i=${#mappings_array[@]}-1; i>=0; i--)); do
                IFS='|' read -r volume_name bundle_id display_name <<< "${mappings_array[$i]}"
                
                # Check if this volume is on the target disk
                local device=$(get_volume_device "$volume_name" 2>/dev/null)
                if [[ -z "$device" ]]; then
                    continue
                fi
                
                local vol_disk=$(echo "$device" | /usr/bin/sed -E 's|(disk[0-9]+).*|\1|')
                if [[ "$vol_disk" != "$disk_id" ]]; then
                    continue
                fi
                
                echo "  ${CYAN}${display_name}${NC} (${volume_name})"
                
                local current_mount=$(get_mount_point "$volume_name")
                
                if [[ -z "$current_mount" ]]; then
                    echo "     ${GREEN}✅ 既にアンマウント済${NC}"
                    ((success_count++))
                else
                    if [[ -n "$bundle_id" ]]; then
                        quit_app_for_bundle "$bundle_id"
                    fi
                    
                    if sudo /usr/sbin/diskutil unmount "$device" >/dev/null 2>&1; then
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
    
    if sudo /usr/sbin/diskutil eject "$disk_id"; then
        print_success "ディスク ${drive_name} を安全に取り外しました"
        echo ""
        print_info "3秒後にターミナルを自動で閉じます..."
        sleep 3
        osascript -e 'tell application "Terminal" to close (every window whose name contains "playcover")' & exit 0
    else
        print_error "ディスクの取り外しに失敗しました"
        wait_for_enter
    fi
}

#######################################################
# Module 8: Storage Switching Functions (Complete Implementation)
#######################################################

switch_storage_location() {
    while true; do
        clear
        print_header "ストレージ切り替え（内蔵⇄外部）"
        
        local mappings_content=$(read_mappings)
        
        if [[ -z "$mappings_content" ]]; then
            print_warning "登録されているアプリボリュームがありません"
            wait_for_enter
            return
        fi
    
    # Display volume list with storage type and mount status
    echo "データステータス:"
    echo ""
    
    # Cache diskutil and mount output for performance
    local diskutil_cache=$(/usr/sbin/diskutil list 2>/dev/null)
    local mount_cache=$(/sbin/mount 2>/dev/null)
    
    declare -a mappings_array=()
    local index=1
    while IFS=$'\t' read -r volume_name bundle_id display_name; do
        if [[ "$bundle_id" == "$PLAYCOVER_BUNDLE_ID" ]]; then
            continue
        fi
        
        mappings_array+=("${volume_name}|${bundle_id}|${display_name}")
        
        local target_path="${HOME}/Library/Containers/${bundle_id}"
        local storage_icon=""
        local mount_status=""
        
        # Determine storage type using get_storage_type function
        local storage_type="unknown"
        if [[ -d "$target_path" ]]; then
            storage_type=$(get_storage_type "$target_path")
        fi
        
        # Get container size
        local container_size=$(get_container_size "$target_path")
        
        case "$storage_type" in
            "external")
                storage_icon="🔌 外部"
                mount_status="🟢 外部ストレージマウント済"
                ;;
            "internal")
                storage_icon="🏠 内部"
                mount_status="⚪️ 内部ストレージにデータ有"
                ;;
            "none")
                storage_icon="⚠️  データ無し"
                mount_status="⚪️ 外部ストレージ未マウント"
                container_size="0B"
                ;;
            *)
                storage_icon="⚠️  データ無し"
                mount_status="⚪️ 外部ストレージ未マウント"
                container_size="0B"
                ;;
        esac
        
        # Format with fixed spacing
        printf "  %s. %s\n" "$index" "$display_name"
        printf "      %-20s %s\n" "$storage_icon" "$mount_status"
        printf "      使用容量: %s\n" "$container_size"
        echo ""
        ((index++))
    done <<< "$mappings_content"
    
    print_separator
    echo ""
    echo "切り替えるアプリを選択してください:"
    echo "  [番号] : ストレージ切り替え"
    echo "  [0]    : 戻る"
    echo ""
    echo -n "選択: "
    read choice
    
    if [[ "$choice" == "0" ]]; then
        return
    fi
    
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ $choice -lt 1 ]] || [[ $choice -gt ${#mappings_array[@]} ]]; then
        print_error "無効な選択です"
        sleep 2
        continue
    fi
    
    # Convert 1-based user input to 0-based array index
    local array_index=$((choice - 1))
    local selected_mapping="${mappings_array[$array_index]}"
    IFS='|' read -r volume_name bundle_id display_name <<< "$selected_mapping"
    
    echo ""
    print_header "${display_name} のストレージ切り替え"
    
    local target_path="${HOME}/Library/Containers/${bundle_id}"
    local backup_path="${HOME}/Library/.playcover_backup_${bundle_id}"
    
    # Check current storage type
    local current_storage="unknown"
    if [[ -d "$target_path" ]]; then
        current_storage=$(get_storage_type "$target_path")
    fi
    
    # Get current size
    local current_size=$(get_container_size "$target_path")
    
    echo "${CYAN}現在の状態:${NC}"
    case "$current_storage" in
        "internal")
            echo "  💾 内蔵ストレージ"
            echo "     使用容量: ${current_size}"
            ;;
        "external")
            echo "  🔌 外部ストレージ"
            echo "     使用容量: ${current_size}"
            ;;
        *)
            echo "  ❓ 不明 / データなし"
            ;;
    esac
    echo ""
    
    # Determine target action and show appropriate free space
    local action=""
    local storage_free=""
    local storage_location=""
    
    case "$current_storage" in
        "internal")
            action="external"
            # Moving to external - show external drive free space
            storage_free=$(get_external_drive_free_space "$volume_name")
            storage_location="外部ドライブ"
            echo "${CYAN}実行する操作:${NC} 内蔵 → 外部ストレージへ移動"
            echo "${CYAN}移行先の空き容量:${NC} ${storage_free} ${MAGENTA}(${storage_location})${NC}"
            ;;
        "external")
            action="internal"
            # Moving to internal - show internal drive free space
            storage_free=$(get_storage_free_space "$HOME")
            storage_location="内蔵ドライブ"
            echo "${CYAN}実行する操作:${NC} 外部 → 内蔵ストレージへ移動"
            echo "${CYAN}移行先の空き容量:${NC} ${storage_free} ${MAGENTA}(${storage_location})${NC}"
            ;;
        "none")
            print_error "ストレージ切り替えを実行できません"
            echo ""
            echo "理由: データが存在しません（未マウント）"
            echo ""
            echo "推奨される操作:"
            echo "  ${CYAN}1.${NC} メインメニューのオプション3で外部ボリュームをマウント"
            echo "  ${CYAN}2.${NC} その後、このストレージ切り替え機能を使用"
            wait_for_enter
            continue
            return
            ;;
        *)
            print_error "現在のストレージ状態を判定できません"
            echo ""
            echo "考えられる原因:"
            echo "  - アプリがまだインストールされていない"
            echo "  - データディレクトリが存在しない"
            wait_for_enter
            continue
            return
            ;;
    esac
    
    echo ""
    print_warning "この操作には時間がかかる場合があります"
    echo ""
    echo -n "${YELLOW}続行しますか？ (Y/n):${NC} "
    read confirm
    
    # Default to Yes if empty
    confirm=${confirm:-Y}
    
    if [[ ! "$confirm" =~ ^[Yy] ]]; then
        print_info "キャンセルしました"
        wait_for_enter
        continue
        return
    fi
    
    # Authenticate sudo only when actually needed (before mount/copy operations)
    authenticate_sudo
    
    echo ""
    
    if [[ "$action" == "external" ]]; then
        # Internal -> External: Copy data to volume and mount
        print_info "内蔵から外部ストレージへデータを移行中..."
        
        # Check if volume exists
        if ! volume_exists "$volume_name"; then
            print_error "外部ボリュームが見つかりません: ${volume_name}"
            wait_for_enter
            continue
            return
        fi
        
        # For internal -> external, determine correct source path
        local source_path="$target_path"
        
        # Validate source path exists
        if [[ ! -d "$source_path" ]]; then
            print_error "コピー元が存在しません: $source_path"
            wait_for_enter
            continue
            return
        fi
        
        # Check if Data directory exists at root level
        if [[ -d "$source_path/Data" ]] && [[ -f "$source_path/.com.apple.containermanagerd.metadata.plist" ]]; then
            # Normal container structure - use as-is
            print_info "内蔵ストレージからコピーします: $source_path"
        else
            # Check for nested backup structure and find actual Data directory
            print_info "コンテナ構造を検証中..."
            
            local data_path=$(/usr/bin/find "$source_path" -type d -name "Data" -depth 3 2>/dev/null | head -1)
            if [[ -n "$data_path" ]]; then
                # Found Data directory - extract parent container path
                local container_path=$(dirname "$data_path")
                if [[ -f "$container_path/.com.apple.containermanagerd.metadata.plist" ]]; then
                    print_warning "ネストされた構造を検出しました"
                    print_info "実際のデータパス: $container_path"
                    source_path="$container_path"
                else
                    print_error "正しいコンテナ構造が見つかりません"
                    echo ""
                    print_info "デバッグ情報:"
                    echo "  検索開始: $source_path"
                    echo "  Data発見: $data_path"
                    echo "  親ディレクトリ: $container_path"
                    echo ""
                    echo -n "Enterキーで続行..."
                    read
                continue
                    return
                fi
            else
                print_error "内蔵ストレージにデータがありません"
                echo ""
                print_info "現在の状態:"
                echo "  パス: $source_path"
                echo ""
                print_info "考えられる原因:"
                echo "  - 外部ボリュームがまだマウントされている"
                echo "  - 内蔵ストレージへの移行が完了していない"
                echo "  - コンテナディレクトリが破損している"
                wait_for_enter
                continue
                return
            fi
        fi
        
        # Check disk space before migration
        print_info "転送前の容量チェック中..."
        local source_size_bytes=$(/usr/bin/du -sk "$source_path" 2>/dev/null | /usr/bin/awk '{print $1}')
        if [[ -z "$source_size_bytes" ]]; then
            print_error "コピー元のサイズを取得できませんでした"
            wait_for_enter
            continue
            return
        fi
        
        # Get available space on external volume (mount temporarily to check)
        local volume_device=$(get_volume_device "$volume_name")
        
        if [[ -z "$volume_device" ]]; then
            print_error "外部ボリュームのデバイス情報が取得できませんでした"
            echo ""
            print_info "デバッグ情報:"
            echo "  ボリューム名: $volume_name"
            wait_for_enter
            continue
            return
        fi
        
        print_info "外部ボリューム: $volume_device"
        
        local temp_check_mount="/tmp/playcover_check_$$"
        sudo /bin/mkdir -p "$temp_check_mount"
        
        # Check if volume is already mounted
        local existing_mount=$(diskutil info "$volume_device" 2>/dev/null | grep "Mount Point" | sed 's/.*: *//')
        local available_bytes=0
        local mount_cleanup_needed=false
        
        if [[ -n "$existing_mount" ]] && [[ "$existing_mount" != "Not applicable (no file system)" ]]; then
            # Volume already mounted - need to unmount it first for fresh mount later
            print_info "外部ボリュームは既にマウントされています: $existing_mount"
            available_bytes=$(df -k "$existing_mount" | tail -1 | /usr/bin/awk '{print $4}')
            mount_cleanup_needed=true
        else
            # Volume not mounted - mount it temporarily for capacity check
            print_info "外部ボリュームをマウント中..."
            if sudo /sbin/mount -t apfs -o nobrowse,rdonly "$volume_device" "$temp_check_mount" 2>/dev/null; then
                print_success "マウント成功"
                available_bytes=$(df -k "$temp_check_mount" | tail -1 | /usr/bin/awk '{print $4}')
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
                sudo /bin/rm -rf "$temp_check_mount"
                wait_for_enter
                continue
                return
            fi
        fi
        
        # Cleanup: Unmount after capacity check for clean state
        if [[ "$mount_cleanup_needed" == true ]]; then
            print_info "容量チェック完了、一時マウントをクリーンアップ中..."
            sudo /usr/sbin/diskutil unmount "$existing_mount" >/dev/null 2>&1
            sleep 1
        fi
        sudo /bin/rm -rf "$temp_check_mount" 2>/dev/null || true
        
        # Convert to human readable
        local source_size_mb=$((source_size_bytes / 1024))
        local available_mb=$((available_bytes / 1024))
        local required_mb=$((source_size_mb * 110 / 100))  # Add 10% safety margin
        
        echo ""
        print_info "容量チェック結果:"
        echo "  コピー元サイズ: ${source_size_mb} MB"
        echo "  転送先空き容量: ${available_mb} MB"
        echo "  必要容量（余裕込み）: ${required_mb} MB"
        echo ""
        
        if [[ $available_mb -lt $required_mb ]]; then
            print_error "容量不足: 転送先の空き容量が不足しています"
            echo ""
            echo "不足分: $((required_mb - available_mb)) MB"
            echo ""
            print_warning "このまま続行すると、転送が中途半端に終了する可能性があります"
            echo ""
            echo -n "${YELLOW}それでも続行しますか？ (y/N):${NC} "
            read force_continue
            
            if [[ ! "$force_continue" =~ ^[Yy]$ ]]; then
                print_info "キャンセルしました"
                wait_for_enter
                continue
                return
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
            unmount_volume "$volume_name" "$bundle_id" || true
            sleep 1
        fi
        
        # Create temporary mount point
        local temp_mount="/tmp/playcover_temp_$$"
        sudo /bin/mkdir -p "$temp_mount"
        
        # Mount volume temporarily (with nobrowse to hide from Finder)
        local volume_device=$(get_volume_device "$volume_name")
        print_info "ボリュームを一時マウント中..."
        if ! sudo /sbin/mount -t apfs -o nobrowse "$volume_device" "$temp_mount"; then
            print_error "ボリュームのマウントに失敗しました"
            sudo /bin/rm -rf "$temp_mount"
            wait_for_enter
            continue
            return
        fi
        
        # Debug: Show source path and content
        print_info "コピー元: ${source_path}"
        local file_count=$(/usr/bin/find "$source_path" -type f 2>/dev/null | wc -l | /usr/bin/xargs)
        local total_size=$(/usr/bin/du -sh "$source_path" 2>/dev/null | /usr/bin/awk '{print $1}')
        print_info "  ファイル数: ${file_count}"
        print_info "  データサイズ: ${total_size}"
        
        # Copy data from internal to external (incremental sync)
        print_info "データを差分転送中... (進捗が表示されます)"
        echo ""
        print_info "💡 差分コピーモード: 既存ファイルはスキップされます"
        echo ""
        
        # Use rsync with --update flag for incremental sync (skip existing files)
        # This is much faster when re-running after interruption
        # Exclude system metadata files and backup directories
        # Note: macOS rsync doesn't support --info=progress2, use --progress instead
        sudo /usr/bin/rsync -avH --update --progress \
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
            local copied_size=$(/usr/bin/du -sh "$temp_mount" 2>/dev/null | /usr/bin/awk '{print $1}')
            print_info "  コピー完了: ${copied_count} ファイル (${copied_size})"
        else
            echo ""
            print_error "データのコピーに失敗しました"
            print_info "一時マウントをクリーンアップ中..."
            sudo /usr/sbin/diskutil unmount "$temp_mount" 2>/dev/null || {
                sudo /usr/sbin/diskutil unmount force "$temp_mount" 2>/dev/null || true
            }
            sleep 1  # Wait for unmount to complete
            sudo /bin/rm -rf "$temp_mount" 2>/dev/null || true
            wait_for_enter
            continue
            return
        fi
        
        # Unmount temporary mount
        print_info "一時マウントをアンマウント中..."
        sudo /usr/sbin/diskutil unmount "$temp_mount" || {
            print_warning "通常のアンマウントに失敗、強制アンマウントを試みます..."
            sudo /usr/sbin/diskutil unmount force "$temp_mount"
        }
        sleep 1  # Wait for unmount to complete
        sudo /bin/rm -rf "$temp_mount"
        
        # Delete internal data (no backup needed)
        print_info "内蔵データを削除中..."
        sudo /bin/rm -rf "$target_path"
        
        # Mount volume to proper location
        print_info "ボリュームを正式にマウント中..."
        if mount_volume "$volume_name" "$target_path"; then
            echo ""
            print_success "外部ストレージへの切り替えが完了しました"
            print_info "保存場所: ${target_path}"
        else
            print_error "ボリュームのマウントに失敗しました"
        fi
        
    else
        # External -> Internal: Copy data from volume to internal and unmount
        print_info "外部から内蔵ストレージへデータを移行中..."
        
        # Check if volume exists
        if ! volume_exists "$volume_name"; then
            print_error "外部ボリュームが見つかりません: ${volume_name}"
            wait_for_enter
            continue
            return
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
            sudo /bin/mkdir -p "$temp_check_mount"
            local volume_device=$(get_volume_device "$volume_name")
            
            if ! sudo /sbin/mount -t apfs -o nobrowse,rdonly "$volume_device" "$temp_check_mount" 2>/dev/null; then
                print_error "外部ボリュームの容量チェックに失敗しました"
                sudo /bin/rm -rf "$temp_check_mount"
                wait_for_enter
                continue
                return
            fi
            check_mount_point="$temp_check_mount"
        fi
        
        local source_size_bytes=$(sudo /usr/bin/du -sk "$check_mount_point" 2>/dev/null | /usr/bin/awk '{print $1}')
        
        # Unmount temporary check mount if created
        if [[ -n "$temp_check_mount" ]]; then
            sudo /usr/sbin/diskutil unmount "$temp_check_mount" >/dev/null 2>&1
            sudo /bin/rm -rf "$temp_check_mount"
        fi
        
        if [[ -z "$source_size_bytes" ]]; then
            print_error "コピー元のサイズを取得できませんでした"
            wait_for_enter
            continue
            return
        fi
        
        # Get available space on internal disk (where target_path will be created)
        local internal_disk_path=$(dirname "$target_path")
        # If parent doesn't exist, check its parent
        while [[ ! -d "$internal_disk_path" ]] && [[ "$internal_disk_path" != "/" ]]; do
            internal_disk_path=$(dirname "$internal_disk_path")
        done
        
        local available_bytes=$(df -k "$internal_disk_path" | tail -1 | /usr/bin/awk '{print $4}')
        
        # Convert to human readable
        local source_size_mb=$((source_size_bytes / 1024))
        local available_mb=$((available_bytes / 1024))
        local required_mb=$((source_size_mb * 110 / 100))  # Add 10% safety margin
        
        echo ""
        print_info "容量チェック結果:"
        echo "  コピー元サイズ: ${source_size_mb} MB"
        echo "  転送先空き容量: ${available_mb} MB"
        echo "  必要容量（余裕込み）: ${required_mb} MB"
        echo ""
        
        if [[ $available_mb -lt $required_mb ]]; then
            print_error "容量不足: 転送先の空き容量が不足しています"
            echo ""
            echo "不足分: $((required_mb - available_mb)) MB"
            echo ""
            print_warning "このまま続行すると、転送が中途半端に終了する可能性があります"
            echo ""
            echo -n "${YELLOW}それでも続行しますか？ (y/N):${NC} "
            read force_continue
            
            if [[ ! "$force_continue" =~ ^[Yy]$ ]]; then
                print_info "キャンセルしました"
                wait_for_enter
                continue
                return
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
            sudo /bin/mkdir -p "$temp_mount"
            local volume_device=$(get_volume_device "$volume_name")
            if ! sudo /sbin/mount -t apfs -o nobrowse "$volume_device" "$temp_mount"; then
                print_error "ボリュームのマウントに失敗しました"
                sudo /bin/rm -rf "$temp_mount"
                wait_for_enter
                continue
                return
            fi
            source_mount="$temp_mount"
            temp_mount_created=true
        elif [[ "$current_mount" == "$target_path" ]]; then
            # Volume is mounted at target path - need to remount to temporary location
            print_info "外部ボリュームは ${target_path} にマウントされています"
            print_info "一時マウントポイントへ移動中..."
            
            local volume_device=$(get_volume_device "$volume_name")
            
            # Try normal unmount first
            local umount_output=$(sudo /usr/sbin/diskutil unmount "$target_path" 2>&1)
            local umount_exit=$?
            
            if [[ $umount_exit -ne 0 ]]; then
                print_warning "通常のアンマウントに失敗しました"
                echo "理由: $umount_output"
                echo ""
                print_info "強制アンマウントを試みます..."
                
                # Try force unmount
                umount_output=$(sudo /usr/sbin/diskutil unmount force "$target_path" 2>&1)
                umount_exit=$?
                
                if [[ $umount_exit -ne 0 ]]; then
                    print_error "強制アンマウントも失敗しました"
                    echo "理由: $umount_output"
                    echo ""
                    print_warning "このアプリが使用中の可能性があります"
                    print_info "推奨される対応:"
                    echo "  1. アプリが起動していないか確認"
                    echo "  2. Finderでこのディレクトリを開いていないか確認"
                    echo "  3. 上記を確認後、再度実行"
                    echo ""
                    echo -n "Enterキーで続行..."
                    read </dev/tty
                continue
                    return
                else
                    print_success "強制アンマウントに成功しました"
                fi
            fi
            
            sleep 1
            
            local temp_mount="/tmp/playcover_temp_$$"
            sudo /bin/mkdir -p "$temp_mount"
            if ! sudo /sbin/mount -t apfs -o nobrowse "$volume_device" "$temp_mount"; then
                print_error "一時マウントに失敗しました"
                sudo /sbin/mount -t apfs -o nobrowse "$volume_device" "$target_path" 2>/dev/null || true
                sudo /bin/rm -rf "$temp_mount"
                wait_for_enter
                continue
                return
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
        local total_size=$(sudo /usr/bin/du -sh "$source_mount" 2>/dev/null | /usr/bin/awk '{print $1}')
        print_info "  ファイル数: ${file_count}"
        print_info "  データサイズ: ${total_size}"
        
        # Remove existing internal data/mount point if it exists
        if [[ -e "$target_path" ]]; then
            print_info "既存データをクリーンアップ中..."
            sudo /bin/rm -rf "$target_path" 2>/dev/null || true
        fi
        
        # Create new internal directory
        sudo /bin/mkdir -p "$target_path"
        
        # Copy data from external to internal
        print_info "データをコピー中... (進捗が表示されます)"
        echo ""
        
        # Use rsync with progress for real-time progress (macOS compatible)
        # Exclude system metadata files and backup directories
        sudo /usr/bin/rsync -avH --ignore-errors --progress \
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
            sudo /usr/sbin/chown -R $(id -u):$(id -g) "$target_path"
            
            local copied_count=$(/usr/bin/find "$target_path" -type f 2>/dev/null | wc -l | /usr/bin/xargs)
            local copied_size=$(/usr/bin/du -sh "$target_path" 2>/dev/null | /usr/bin/awk '{print $1}')
            print_info "  コピー完了: ${copied_count} ファイル (${copied_size})"
        else
            echo ""
            print_error "データのコピーに失敗しました"
            
            # Cleanup: Unmount first, then clean up directories
            if [[ "$temp_mount_created" == true ]]; then
                print_info "一時マウントをクリーンアップ中..."
                sudo /usr/sbin/diskutil unmount "$source_mount" 2>/dev/null || {
                    sudo /usr/sbin/diskutil unmount force "$source_mount" 2>/dev/null || true
                }
                sleep 1  # Wait for unmount to complete
                sudo /bin/rm -rf "$source_mount" 2>/dev/null || true
            fi
            
            # Remove failed copy
            sudo /bin/rm -rf "$target_path" 2>/dev/null || true
            
            wait_for_enter
            continue
            return
        fi
        
        # Unmount volume
        if [[ "$temp_mount_created" == true ]]; then
            print_info "一時マウントをクリーンアップ中..."
            sudo /usr/sbin/diskutil unmount "$source_mount" 2>/dev/null || {
                sudo /usr/sbin/diskutil unmount force "$source_mount" 2>/dev/null || true
            }
            sleep 1  # Wait for unmount to complete
            sudo /bin/rm -rf "$source_mount"
        else
            print_info "外部ボリュームをアンマウント中..."
            unmount_volume "$volume_name" "$bundle_id" || true
        fi
        
        echo ""
        print_success "内蔵ストレージへの切り替えが完了しました"
        print_info "保存場所: ${target_path}"
    fi
    
    wait_for_enter
    done  # End of while true loop
}

#######################################################
# Module 9: Menu & UI Functions
#######################################################

show_quick_status() {
    local mappings_content=$(read_mappings)
    
    if [[ -z "$mappings_content" ]]; then
        return
    fi
    
    local external_count=0
    local internal_count=0
    local unmounted_count=0
    local total_count=0
    
    while IFS=$'\t' read -r volume_name bundle_id display_name; do
        # Skip PlayCover itself
        if [[ "$volume_name" == "PlayCover" ]]; then
            continue
        fi
        
        ((total_count++))
        
        local target_path="${HOME}/Library/Containers/${bundle_id}"
        local storage_type=$(get_storage_type "$target_path")
        
        case "$storage_type" in
            "external") ((external_count++)) ;;
            "internal") ((internal_count++)) ;;
            *) ((unmounted_count++)) ;;
        esac
    done <<< "$mappings_content"
    
    if [[ $total_count -gt 0 ]]; then
        echo "${CYAN}コンテナ情報${NC}"
        
        # Build status line dynamically (only show non-zero items)
        local status_parts=()
        
        if [[ $external_count -gt 0 ]]; then
            status_parts+=("${BLUE}🔌 外部マウント: ${external_count}件${NC}")
        fi
        
        if [[ $internal_count -gt 0 ]]; then
            status_parts+=("${YELLOW}🏠 内部マウント: ${internal_count}件${NC}")
        fi
        
        if [[ $unmounted_count -gt 0 ]]; then
            status_parts+=("${RED}❌ データ無し: ${unmounted_count}件${NC}")
        fi
        
        # Join status parts with separator
        local first=true
        for part in "${status_parts[@]}"; do
            if [[ "$first" == true ]]; then
                echo -n "$part"
                first=false
            else
                echo -n "　　$part"
            fi
        done
        echo ""
        
        if [[ $unmounted_count -gt 0 ]]; then
            echo "${RED}⚠️ データが入っていないコンテナがあります。マウントを行ってください。${NC}"
        fi
        
        echo ""
    fi
}

show_menu() {
    clear
    
    echo ""
    echo "${GREEN}PlayCover 統合管理ツール${NC}  ${BLUE}Version 4.16.0${NC}"
    echo ""
    
    show_quick_status
    
    echo "${BLUE}メインメニュー${NC}"
    echo ""
    echo "  ${GREEN}1.${NC} アプリ管理"
    echo "  ${YELLOW}2.${NC} ボリューム操作"
    echo "  ${CYAN}3.${NC} ストレージ切り替え（内蔵⇄外部）"
    echo ""
    
    # Dynamic eject menu label (v4.7.0)
    local eject_label="ディスク全体を取り外し"
    
    # Get current PlayCover volume device dynamically for menu display
    if volume_exists "$PLAYCOVER_VOLUME_NAME" 2>/dev/null; then
        local volume_device=$(get_volume_device "$PLAYCOVER_VOLUME_NAME" 2>/dev/null)
        if [[ -n "$volume_device" ]]; then
            local playcover_device="/dev/${volume_device}"
            local drive_name=$(get_drive_name "$playcover_device")
            eject_label="「${drive_name}」の取り外し"
        fi
    fi
    
    echo "  ${RED}4.${NC} ${eject_label}"
    echo "  ${BLUE}0.${NC} 終了"
    echo ""
    echo -n "${CYAN}選択 (0-4):${NC} "
}

show_mapping_info() {
    clear
    print_header "マッピング情報"
    
    if [[ ! -f "$MAPPING_FILE" ]]; then
        print_warning "マッピングファイルが見つかりません"
        wait_for_enter
        return
    fi
    
    local mappings_content=$(read_mappings)
    
    if [[ -z "$mappings_content" ]]; then
        print_warning "登録されているアプリがありません"
        wait_for_enter
        return
    fi
    
    echo "登録されているアプリ:"
    echo ""
    
    local index=1
    while IFS=$'\t' read -r volume_name bundle_id display_name; do
        echo "  ${index}. ${GREEN}${display_name}${NC}"
        echo "      ボリューム名: ${volume_name}"
        echo "      Bundle ID: ${bundle_id}"
        echo ""
        ((index++))
    done <<< "$mappings_content"
    
    echo -n "Enterキーで続行..."
    read
}

show_auto_mount_menu() {
    while true; do
        clear
        print_header "PlayCover 自動マウント設定"
        
        # Check LaunchAgent status
        local launch_agent_path="${HOME}/Library/LaunchAgents/com.playcover.automount.plist"
        local script_path="${HOME}/playcover-auto-mount.sh"
        local is_installed=false
        local is_loaded=false
        
        if [[ -f "$launch_agent_path" ]] && [[ -f "$script_path" ]]; then
            is_installed=true
            if launchctl list | grep -q "com.playcover.automount"; then
                is_loaded=true
            fi
        fi
        
        # Display current status
        echo "現在の状態:"
        echo ""
        if [[ "$is_installed" == true ]]; then
            if [[ "$is_loaded" == true ]]; then
                print_success "自動マウント機能: 有効 ✓"
            else
                print_warning "自動マウント機能: インストール済み（未読み込み）"
            fi
        else
            print_error "自動マウント機能: 未インストール"
        fi
        echo ""
        print_separator
        echo ""
        
        echo "${BLUE}メニュー${NC}"
        echo ""
        echo "  ${GREEN}1.${NC} 自動マウント機能をインストール"
        echo "  ${YELLOW}2.${NC} 自動マウント機能をアンインストール"
        echo "  ${CYAN}3.${NC} 動作確認・ログ表示"
        echo "  ${MAGENTA}4.${NC} インストール手順を表示"
        echo "  ${BLUE}0.${NC} 戻る"
        echo ""
        echo -n "${CYAN}選択 (0-4):${NC} "
        
        read choice
        
        case "$choice" in
            1)
                install_auto_mount
                ;;
            2)
                uninstall_auto_mount
                ;;
            3)
                check_auto_mount_status
                ;;
            4)
                show_auto_mount_setup_guide
                ;;
            0)
                return
                ;;
            *)
                print_error "無効な選択です"
                sleep 1
                ;;
        esac
    done
}

install_auto_mount() {
    clear
    print_header "自動マウント機能のインストール"
    
    local launch_agent_path="${HOME}/Library/LaunchAgents/com.playcover.automount.plist"
    local script_path="${HOME}/playcover-auto-mount.sh"
    
    # Check if already installed
    if [[ -f "$launch_agent_path" ]] && [[ -f "$script_path" ]]; then
        print_warning "自動マウント機能は既にインストールされています"
        echo ""
        echo -n "再インストールしますか？ (Y/n): "
        read confirm
        
        # Default to Yes if empty
        confirm=${confirm:-Y}
        
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            return
        fi
        
        # Unload existing LaunchAgent
        if launchctl list | grep -q "com.playcover.automount"; then
            print_info "既存のLaunchAgentをアンロード中..."
            launchctl unload "$launch_agent_path" 2>/dev/null
        fi
    fi
    
    # Step 1: Copy script
    print_info "スクリプトをコピー中..."
    if [[ -f "${SCRIPT_DIR}/playcover-auto-mount.sh" ]]; then
        cp "${SCRIPT_DIR}/playcover-auto-mount.sh" "$script_path"
        chmod +x "$script_path"
        print_success "スクリプトをコピーしました: $script_path"
    else
        print_error "スクリプトファイルが見つかりません: ${SCRIPT_DIR}/playcover-auto-mount.sh"
        wait_for_enter
        return
    fi
    
    # Step 2: Create LaunchAgents directory if not exists
    local launch_agents_dir="${HOME}/Library/LaunchAgents"
    if [[ ! -d "$launch_agents_dir" ]]; then
        mkdir -p "$launch_agents_dir"
    fi
    
    # Step 3: Copy and modify plist
    print_info "LaunchAgent plistを設定中..."
    if [[ -f "${SCRIPT_DIR}/com.playcover.automount.plist" ]]; then
        cp "${SCRIPT_DIR}/com.playcover.automount.plist" "$launch_agent_path"
        
        # Replace YOUR_USERNAME with actual username
        sed -i '' "s|/Users/YOUR_USERNAME/|${HOME}/|g" "$launch_agent_path"
        
        print_success "LaunchAgent plistを設定しました: $launch_agent_path"
    else
        print_error "plistファイルが見つかりません: ${SCRIPT_DIR}/com.playcover.automount.plist"
        wait_for_enter
        return
    fi
    
    # Step 4: Load LaunchAgent
    print_info "LaunchAgentを読み込み中..."
    if launchctl load "$launch_agent_path" 2>/dev/null; then
        print_success "LaunchAgentを読み込みました"
    else
        print_warning "LaunchAgentの読み込みに失敗しました（既に読み込まれている可能性）"
    fi
    
    echo ""
    print_separator
    echo ""
    print_success "自動マウント機能のインストールが完了しました！"
    echo ""
    echo "${CYAN}次のステップ:${NC}"
    echo "  ${GREEN}推奨:${NC} システムを再起動またはログアウト→ログイン"
    echo "  ${BLUE}理由:${NC} ログイン時にPlayCoverボリュームが自動マウントされます"
    echo ""
    echo "${CYAN}動作確認方法:${NC}"
    echo "  1. ログイン後、ボリュームがマウントされていることを確認"
    echo "  2. PlayCover.appを起動して正常動作を確認"
    echo ""
    echo "${YELLOW}ログファイル:${NC} ${HOME}/Library/Logs/playcover-auto-mount.log"
    echo ""
    echo "${MAGENTA}注意:${NC} WatchPaths方式は廃止し、ログイン時マウントに変更しました"
    echo "       これにより、PlayCover起動前の確実なマウントを実現"
    wait_for_enter
}

uninstall_auto_mount() {
    clear
    print_header "自動マウント機能のアンインストール"
    
    local launch_agent_path="${HOME}/Library/LaunchAgents/com.playcover.automount.plist"
    local script_path="${HOME}/playcover-auto-mount.sh"
    
    if [[ ! -f "$launch_agent_path" ]] && [[ ! -f "$script_path" ]]; then
        print_warning "自動マウント機能はインストールされていません"
        wait_for_enter
        return
    fi
    
    echo -n "${RED}自動マウント機能をアンインストールしますか？ (Y/n):${NC} "
    read confirm
    
    # Default to Yes if empty
    confirm=${confirm:-Y}
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "アンインストールをキャンセルしました"
        wait_for_enter
        return
    fi
    
    # Unload LaunchAgent
    if [[ -f "$launch_agent_path" ]]; then
        if launchctl list | grep -q "com.playcover.automount"; then
            print_info "LaunchAgentをアンロード中..."
            launchctl unload "$launch_agent_path" 2>/dev/null
            print_success "LaunchAgentをアンロードしました"
        fi
        
        print_info "plistファイルを削除中..."
        rm "$launch_agent_path"
        print_success "plistファイルを削除しました"
    fi
    
    # Remove script
    if [[ -f "$script_path" ]]; then
        print_info "スクリプトを削除中..."
        rm "$script_path"
        print_success "スクリプトを削除しました"
    fi
    
    echo ""
    print_separator
    echo ""
    print_success "自動マウント機能のアンインストールが完了しました"
    echo ""
    echo "${CYAN}ログファイルは残されています:${NC}"
    echo "  ${HOME}/Library/Logs/playcover-auto-mount.log"
    wait_for_enter
}

check_auto_mount_status() {
    clear
    print_header "自動マウント機能の動作確認"
    
    local launch_agent_path="${HOME}/Library/LaunchAgents/com.playcover.automount.plist"
    local script_path="${HOME}/playcover-auto-mount.sh"
    local log_file="${HOME}/Library/Logs/playcover-auto-mount.log"
    
    # Check installation
    echo "${CYAN}インストール状態:${NC}"
    echo ""
    
    if [[ -f "$script_path" ]]; then
        print_success "スクリプト: ${script_path}"
    else
        print_error "スクリプト: 未インストール"
    fi
    
    if [[ -f "$launch_agent_path" ]]; then
        print_success "LaunchAgent plist: ${launch_agent_path}"
    else
        print_error "LaunchAgent plist: 未インストール"
    fi
    
    echo ""
    
    # Check LaunchAgent status
    echo "${CYAN}LaunchAgent状態:${NC}"
    echo ""
    
    if launchctl list | grep -q "com.playcover.automount"; then
        print_success "LaunchAgent: 読み込み済み ✓"
        
        # Get PID if available
        local agent_info=$(launchctl list | grep "com.playcover.automount")
        echo "  詳細: $agent_info"
    else
        print_error "LaunchAgent: 未読み込み"
    fi
    
    echo ""
    print_separator
    echo ""
    
    # Show recent logs
    echo "${CYAN}最近のログ（最新10行）:${NC}"
    echo ""
    
    if [[ -f "$log_file" ]]; then
        tail -10 "$log_file" | while IFS= read -r line; do
            # Colorize log levels
            if echo "$line" | grep -q "ERROR"; then
                echo "${RED}${line}${NC}"
            elif echo "$line" | grep -q "SUCCESS"; then
                echo "${GREEN}${line}${NC}"
            elif echo "$line" | grep -q "INFO"; then
                echo "${BLUE}${line}${NC}"
            else
                echo "$line"
            fi
        done
    else
        print_warning "ログファイルが見つかりません: ${log_file}"
    fi
    
    echo ""
    print_separator
    echo ""
    
    # Test script manually
    echo -n "${CYAN}スクリプトを手動実行してテストしますか？ (y/N):${NC} "
    read test_confirm
    
    if [[ "$test_confirm" =~ ^[Yy]$ ]]; then
        echo ""
        print_info "スクリプトを実行中..."
        echo ""
        
        if [[ -x "$script_path" ]]; then
            "$script_path"
            local exit_code=$?
            
            echo ""
            if [[ $exit_code -eq 0 ]]; then
                print_success "スクリプトが正常に実行されました（終了コード: 0）"
            else
                print_error "スクリプトがエラーで終了しました（終了コード: ${exit_code}）"
            fi
        else
            print_error "スクリプトが実行可能ではありません"
        fi
    fi
    
    wait_for_enter
}

show_auto_mount_setup_guide() {
    clear
    print_header "自動マウント機能 - インストール手順"
    
    echo "${CYAN}概要:${NC}"
    echo "PlayCoverを未マウント状態で起動すると内蔵ストレージにデータが作成され、"
    echo "その後ボリュームをマウントできなくなる問題を解決します。"
    echo ""
    print_separator
    echo ""
    
    echo "${CYAN}解決策:${NC}"
    echo "ログイン時に自動的にPlayCoverボリュームをマウントするLaunchAgentを設定"
    echo ""
    print_separator
    echo ""
    
    echo "${CYAN}動作仕様:${NC}"
    echo "• ログイン時に自動実行（RunAtLoad）"
    echo "• 既にマウント済みの場合はスキップ"
    echo "• 内部ストレージに大量データがある場合は警告表示"
    echo "• 少量の初期データは自動クリア"
    echo ""
    print_separator
    echo ""
    
    echo "${CYAN}インストール手順:${NC}"
    echo ""
    echo "${GREEN}1. ファイル配置${NC}"
    echo "   このスクリプトの「${GREEN}1. 自動マウント機能をインストール${NC}」メニューから"
    echo "   自動的にインストールできます。"
    echo ""
    echo "${GREEN}2. 動作確認${NC}"
    echo "   a) システムを再起動またはログアウト→ログイン"
    echo "   b) ログイン後、自動的にボリュームがマウントされることを確認"
    echo "   c) PlayCover.appを起動して正常動作を確認"
    echo ""
    echo "${GREEN}3. ログ確認${NC}"
    echo "   ${YELLOW}${HOME}/Library/Logs/playcover-auto-mount.log${NC}"
    echo ""
    print_separator
    echo ""
    
    echo "${CYAN}安全性:${NC}"
    echo "• 内蔵ストレージにデータが既に存在する場合はマウントしません"
    echo "• データ消失リスクはありません"
    echo "• エラー時は通知で警告を表示します"
    echo ""
    print_separator
    echo ""
    
    echo "${CYAN}詳細情報:${NC}"
    echo "セットアップガイド: ${SCRIPT_DIR}/PLAYCOVER_AUTO_MOUNT_SETUP.md"
    echo ""
    
    echo -n "Enterキーで続行..."
    read
}

#######################################################
# Module 10: Main Execution
#######################################################

show_installed_apps() {
    local playcover_apps="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/Applications"
    local display_only="${1:-true}"  # Default to display mode
    
    # Check if mapping file exists
    if [[ ! -f "$MAPPING_FILE" ]]; then
        if [[ "$display_only" == "true" ]]; then
            echo "${YELLOW}インストール済みアプリ:${NC} ${BLUE}0個${NC}"
        fi
        return
    fi
    
    local mappings_content=$(read_mappings)
    
    if [[ -z "$mappings_content" ]]; then
        if [[ "$display_only" == "true" ]]; then
            echo "${YELLOW}インストール済みアプリ:${NC} ${BLUE}0個${NC}"
        fi
        return
    fi
    
    # Check if PlayCover Applications directory exists
    if [[ ! -d "$playcover_apps" ]]; then
        if [[ "$display_only" == "true" ]]; then
            echo "${YELLOW}インストール済みアプリ:${NC} ${RED}PlayCoverコンテナが見つかりません${NC}"
        fi
        return
    fi
    
    if [[ "$display_only" == "true" ]]; then
        echo "${YELLOW}インストール済みアプリ:${NC}"
        echo ""
    fi
    
    local installed_count=0
    local missing_count=0
    local index=1
    
    # Global arrays for uninstall workflow (declared in main if needed)
    if [[ "$display_only" == "false" ]]; then
        apps_list=()
        volumes_list=()
        bundles_list=()
        versions_list=()
    fi
    
    while IFS=$'\t' read -r volume_name bundle_id display_name; do
        # Skip PlayCover itself (it's not an iOS app)
        if [[ "$volume_name" == "PlayCover" ]]; then
            continue
        fi
        
        # Search for app in PlayCover Applications
        local app_found=false
        local app_version=""
        
        if [[ -d "$playcover_apps" ]]; then
            while IFS= read -r app_path; do
                if [[ -f "${app_path}/Info.plist" ]]; then
                    local found_bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "${app_path}/Info.plist" 2>/dev/null)
                    
                    if [[ "$found_bundle_id" == "$bundle_id" ]]; then
                        app_found=true
                        app_version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${app_path}/Info.plist" 2>/dev/null || echo "不明")
                        break
                    fi
                fi
            done < <(find "$playcover_apps" -maxdepth 1 -name "*.app" -type d 2>/dev/null)
        fi
        
        if [[ "$app_found" == true ]]; then
            # Get container path and size
            local container_path="${HOME}/Library/Containers/${bundle_id}"
            local container_size=$(get_container_size "$container_path")
            local storage_type=$(get_storage_type "$container_path")
            local storage_icon=""
            
            case "$storage_type" in
                "external")
                    storage_icon="${CYAN}💾${NC}"
                    ;;
                "internal")
                    storage_icon="${YELLOW}💽${NC}"
                    ;;
                "none")
                    storage_icon="${MAGENTA}📦${NC}"
                    container_size="0B"
                    ;;
                *)
                    storage_icon="${RED}?${NC}"
                    ;;
            esac
            
            if [[ "$display_only" == "true" ]]; then
                echo "  ${GREEN}✓${NC} ${display_name} ${BLUE}(v${app_version})${NC} ${storage_icon} ${container_size}"
            else
                echo "  ${CYAN}${index}.${NC} ${GREEN}${display_name}${NC} ${BLUE}(v${app_version})${NC}"
                echo "      Bundle ID: ${bundle_id}"
                echo "      ボリューム: ${volume_name}"
                echo "      使用容量: ${storage_icon} ${container_size}"
                echo ""
                apps_list+=("$display_name")
                volumes_list+=("$volume_name")
                bundles_list+=("$bundle_id")
                versions_list+=("$app_version")
                ((index++))
            fi
            ((installed_count++))
        else
            if [[ "$display_only" == "true" ]]; then
                echo "  ${RED}✗${NC} ${display_name} ${RED}(見つかりません)${NC}"
            fi
            ((missing_count++))
        fi
    done <<< "$mappings_content"
    
    if [[ "$display_only" == "true" ]]; then
        echo ""
        if [[ $missing_count -eq 0 ]]; then
            echo "${GREEN}合計: ${installed_count}個${NC}"
        else
            echo "${GREEN}インストール済: ${installed_count}個${NC}  ${RED}見つからない: ${missing_count}個${NC}"
        fi
    fi
    
    # Return installed count for uninstall workflow
    if [[ "$display_only" == "false" ]]; then
        return $installed_count
    fi
}

app_management_menu() {
    # Ensure PlayCover volume is mounted before showing menu
    local playcover_mounted=false
    
    if volume_exists "$PLAYCOVER_VOLUME_NAME" 2>/dev/null; then
        local pc_current_mount=$(get_mount_point "$PLAYCOVER_VOLUME_NAME")
        
        if [[ -z "$pc_current_mount" ]]; then
            # Volume exists but not mounted - try to mount it
            authenticate_sudo
            
            # Clear internal data first if needed
            if [[ -d "$PLAYCOVER_CONTAINER" ]]; then
                local storage_type=$(get_storage_type "$PLAYCOVER_CONTAINER")
                if [[ "$storage_type" == "internal" ]]; then
                    clear
                    print_warning "⚠️  PlayCoverボリュームが未マウントですが、内部ストレージにデータがあります"
                    echo ""
                    echo "${YELLOW}対処方法:${NC}"
                    echo "  1. 内部データを外部に移行してマウント（推奨）"
                    echo "  2. 内部データを削除してクリーンな状態でマウント"
                    echo "  3. キャンセル"
                    echo ""
                    echo -n "選択してください (1/2/3): "
                    read cleanup_choice
                    
                    case "$cleanup_choice" in
                        1|2)
                            # Call mount_playcover_main_volume which handles cleanup
                            mount_playcover_main_volume
                            playcover_mounted=true
                            ;;
                        *)
                            print_info "キャンセルしました"
                            echo ""
                            echo -n "Enterキーで続行..."
                            read
                            return
                            ;;
                    esac
                else
                    # No internal data, mount directly
                    mount_volume "$PLAYCOVER_VOLUME_NAME" "$PLAYCOVER_CONTAINER" "true" >/dev/null 2>&1
                    playcover_mounted=$?
                    [[ $playcover_mounted -eq 0 ]] && playcover_mounted=true || playcover_mounted=false
                fi
            else
                # Directory doesn't exist, create and mount
                mount_volume "$PLAYCOVER_VOLUME_NAME" "$PLAYCOVER_CONTAINER" "true" >/dev/null 2>&1
                playcover_mounted=$?
                [[ $playcover_mounted -eq 0 ]] && playcover_mounted=true || playcover_mounted=false
            fi
        elif [[ "$pc_current_mount" != "$PLAYCOVER_CONTAINER" ]]; then
            # Volume mounted to wrong location - remount
            authenticate_sudo
            unmount_volume "$PLAYCOVER_VOLUME_NAME" >/dev/null 2>&1 || true
            mount_volume "$PLAYCOVER_VOLUME_NAME" "$PLAYCOVER_CONTAINER" "true" >/dev/null 2>&1
            playcover_mounted=$?
            [[ $playcover_mounted -eq 0 ]] && playcover_mounted=true || playcover_mounted=false
        else
            # Already mounted correctly
            playcover_mounted=true
        fi
    fi
    
    # If PlayCover volume couldn't be mounted, show warning
    if [[ "$playcover_mounted" == false ]]; then
        clear
        print_warning "PlayCoverボリュームがマウントされていません"
        print_info "アプリ一覧を正しく表示するには、ボリュームをマウントしてください"
        wait_for_enter
    fi
    
    while true; do
        clear
        echo ""
        echo "${BLUE}アプリ管理${NC}"
        echo ""
        show_installed_apps
        echo ""
        echo "  ${GREEN}1.${NC} アプリをインストール"
        echo "  ${RED}2.${NC} アプリをアンインストール"
        echo "  ${CYAN}0.${NC} メインメニューに戻る"
        echo ""
        echo -n "${YELLOW}選択:${NC} "
        read choice
        
        case "$choice" in
            1)
                install_workflow
                ;;
            2)
                uninstall_workflow
                ;;
            0)
                return
                ;;
            *)
                print_error "無効な選択です"
                wait_for_enter
                ;;
        esac
    done
}

install_workflow() {
    clear
    
    # Reset global arrays at the start of workflow
    SELECTED_IPAS=()
    INSTALL_SUCCESS=()
    INSTALL_FAILED=()
    BATCH_MODE=false
    CURRENT_IPA_INDEX=0
    TOTAL_IPAS=0
    
    check_playcover_app
    check_mapping_file
    check_full_disk_access
    authenticate_sudo
    check_playcover_volume_mount
    
    select_ipa_files || return
    
    CURRENT_IPA_INDEX=0
    for ipa_file in "${SELECTED_IPAS[@]}"; do
        ((CURRENT_IPA_INDEX++))
        
        if [[ $BATCH_MODE == true ]]; then
            print_batch_progress "$CURRENT_IPA_INDEX" "$TOTAL_IPAS" "$(basename "$ipa_file")"
        fi
        
        extract_ipa_info "$ipa_file" || continue
        select_installation_disk || continue
        create_app_volume || continue
        mount_app_volume || continue
        install_ipa_to_playcover "$ipa_file" || continue
    done
    
    echo ""
    print_success "全ての処理が完了しました"
    
    if [[ ${#INSTALL_SUCCESS[@]} -gt 0 ]]; then
        echo ""
        print_success "インストール成功: ${#INSTALL_SUCCESS[@]} 個"
        for app in "${INSTALL_SUCCESS[@]}"; do
            echo "  ✓ $app"
        done
    fi
    
    if [[ ${#INSTALL_FAILED[@]} -gt 0 ]]; then
        echo ""
        print_error "インストール失敗: ${#INSTALL_FAILED[@]} 個"
        for app in "${INSTALL_FAILED[@]}"; do
            echo "  ✗ $app"
        done
    fi
    
    echo ""
    echo -n "Enterキーでメニューに戻る..."
    read
}

uninstall_workflow() {
    # Loop until user cancels or no more apps
    while true; do
        clear
        print_header "アプリのアンインストール"
        
        # Check mapping file
        if [[ ! -f "$MAPPING_FILE" ]]; then
            print_error "マッピングファイルが見つかりません"
            echo ""
            echo "まだアプリがインストールされていません。"
            wait_for_enter
            return
        fi
        
        local mappings_content=$(read_mappings)
        
        if [[ -z "$mappings_content" ]]; then
            print_success "すべてのアプリがアンインストールされました"
            echo ""
            echo "インストールされているアプリ: 0個"
            echo ""
            echo -n "Enterキーでメニューに戻る..."
            read
            return
        fi
    
    # Display installed apps using shared function
    echo ""
    show_installed_apps "false"
    local total_apps=$?
    
    if [[ $total_apps -eq 0 ]]; then
        print_warning "インストールされているアプリがありません"
        wait_for_enter
        return
    fi
    
    # Show uninstall options
    echo ""
    print_separator "$SEPARATOR_CHAR" "$CYAN"
    echo ""
    echo "${YELLOW}▼ アンインストール方法を選択${NC}"
    echo ""
    echo "  ${GREEN}個別削除${NC}: 1-${total_apps} の番号を入力"
    echo "  ${RED}一括削除${NC}: ${RED}ALL${NC} を入力（すべてのアプリを一度に削除）"
    echo "  ${CYAN}キャンセル${NC}: 0 を入力"
    echo ""
    echo -n "${YELLOW}選択:${NC} "
    read app_choice
    
    # Check for batch uninstall
    if [[ "$app_choice" == "ALL" ]] || [[ "$app_choice" == "all" ]]; then
        # Call batch uninstall function
        uninstall_all_apps
        return
    fi
    
    # Validate input for individual uninstall
    if [[ ! "$app_choice" =~ ^[0-9]+$ ]] || [[ $app_choice -lt 0 ]] || [[ $app_choice -gt $total_apps ]]; then
        print_error "無効な選択です"
        wait_for_enter
        continue
    fi
    
    if [[ $app_choice -eq 0 ]]; then
        return
    fi
    
    # Get selected app info (convert 1-based user input to 0-based array index)
    local array_index=$((app_choice - 1))
    local selected_app="${apps_list[$array_index]}"
    local selected_volume="${volumes_list[$array_index]}"
    local selected_bundle="${bundles_list[$array_index]}"
    
    # Check if trying to delete PlayCover volume with other apps remaining
    if [[ "$selected_volume" == "PlayCover" ]] && [[ $total_apps -gt 1 ]]; then
        echo ""
        print_error "PlayCoverボリュームは削除できません"
        echo ""
        echo "理由: 他のアプリがまだインストールされています"
        echo ""
        echo "PlayCoverボリュームを削除するには："
        echo "  1. 他のすべてのアプリを先にアンインストール"
        echo "  2. PlayCoverボリュームが最後に残った状態にする"
        echo "  3. その後、PlayCoverボリュームをアンインストール"
        echo ""
        echo "現在インストール済み: ${total_apps} 個のアプリ"
        wait_for_enter
        continue
    fi
    
    echo ""
    print_warning "以下のアプリをアンインストールします:"
    echo ""
    echo "  アプリ名: ${GREEN}${selected_app}${NC}"
    echo "  Bundle ID: ${selected_bundle}"
    echo "  ボリューム: ${selected_volume}"
    echo ""
    print_warning "この操作は以下を実行します:"
    echo "  1. PlayCover からアプリを削除 (Applications/)"
    echo "  2. アプリ設定を削除 (App Settings/)"
    echo "  3. Entitlements を削除"
    echo "  4. Keymapping を削除"
    echo "  5. Containersフォルダを削除"
    echo "  6. APFSボリュームをアンマウント"
    echo "  7. APFSボリュームを削除"
    echo "  8. マッピング情報を削除"
    echo ""
    print_error "この操作は取り消せません！"
    echo ""
    echo -n "${RED}本当にアンインストールしますか？ (yes/NO):${NC} "
    read confirm
    
    if [[ "$confirm" != "yes" ]]; then
        print_info "キャンセルしました"
        wait_for_enter
        return
    fi
    
    # Authenticate sudo before volume operations
    authenticate_sudo
    
    # Start uninstallation
    echo ""
    print_info "${selected_app} を削除中..."
    echo ""
    
    # Step 1: Remove app from PlayCover Applications/
    local playcover_apps="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/Applications"
    local app_path="${playcover_apps}/${selected_bundle}.app"
    
    if [[ -d "$app_path" ]]; then
        if ! rm -rf "$app_path" 2>/dev/null; then
            print_error "アプリの削除に失敗しました"
            wait_for_enter
            return
        fi
    fi
    
    # Step 2-5: Remove settings, entitlements, keymapping, containers (silent)
    local app_settings="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/App Settings/${selected_bundle}.plist"
    rm -f "$app_settings" 2>/dev/null
    
    local entitlements_file="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/Entitlements/${selected_bundle}.plist"
    rm -f "$entitlements_file" 2>/dev/null
    
    local keymapping_file="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/Keymapping/${selected_bundle}.plist"
    rm -f "$keymapping_file" 2>/dev/null
    
    local containers_dir="${HOME}/Library/Containers/${selected_bundle}"
    rm -rf "$containers_dir" 2>/dev/null
    
    # Step 7: Unmount volume if mounted (silent)
    local volume_mount_point="${PLAYCOVER_CONTAINER}/${selected_volume}"
    if mount | grep -q "$volume_mount_point"; then
        diskutil unmount "$volume_mount_point" >/dev/null 2>&1
    fi
    
    # Step 8: Delete APFS volume
    local volume_device=$(diskutil list | grep "$selected_volume" | awk '{print $NF}')
    
    if [[ -n "$volume_device" ]]; then
        if ! sudo diskutil apfs deleteVolume "$volume_device" >/dev/null 2>&1; then
            print_error "ボリュームの削除に失敗しました"
            echo ""
            echo "手動で削除してください: sudo diskutil apfs deleteVolume $volume_device"
            wait_for_enter
            return
        fi
    fi
    
    # Step 9: Remove from mapping file (silent)
    if ! remove_mapping "$selected_bundle"; then
        print_error "マッピング情報の削除に失敗しました"
        wait_for_enter
        return
    fi
    
    # Step 10: If PlayCover volume, remove PlayCover.app and exit
    if [[ "$selected_volume" == "PlayCover" ]]; then
        echo ""
        local playcover_app="/Applications/PlayCover.app"
        if [[ -d "$playcover_app" ]]; then
            rm -rf "$playcover_app" 2>/dev/null
        fi
        
        print_success "PlayCover を完全にアンインストールしました"
        echo ""
        print_warning "このスクリプトは今後使用できません（PlayCoverを再インストールすると使用可能）"
        echo ""
        echo -n "Enterキーでターミナルを終了します..."
        read
        exit 0
    fi
    
    echo ""
    print_success "✓ ${selected_app}"
    echo ""
    
    # Check if there are more apps
    local remaining_content=$(read_mappings)
    if [[ -z "$remaining_content" ]]; then
        print_success "すべてのアプリがアンインストールされました"
        echo ""
        echo -n "Enterキーでメニューに戻る..."
        read
        return
    else
        local remaining_count=$(echo "$remaining_content" | wc -l | tr -d ' ')
        echo ""
        echo "${CYAN}残り ${remaining_count} 個のアプリがインストールされています${NC}"
        wait_for_enter
        # Loop continues to show uninstall menu again
    fi
    done
}

uninstall_all_apps() {
    clear
    print_header "全アプリ一括アンインストール"
    
    # Check mapping file
    if [[ ! -f "$MAPPING_FILE" ]]; then
        print_error "マッピングファイルが見つかりません"
        echo ""
        echo "まだアプリがインストールされていません。"
        wait_for_enter
        return
    fi
    
    local mappings_content=$(read_mappings)
    
    if [[ -z "$mappings_content" ]]; then
        print_warning "インストールされているアプリがありません"
        wait_for_enter
        return
    fi
    
    # Count total apps
    local total_apps=$(echo "$mappings_content" | wc -l | tr -d ' ')
    
    # Display all installed apps
    echo ""
    echo "以下のアプリをすべて削除します:"
    echo ""
    
    local -a apps_list=()
    local -a volumes_list=()
    local -a bundles_list=()
    local index=1
    
    while IFS=$'\t' read -r volume_name bundle_id display_name; do
        apps_list+=("$display_name")
        volumes_list+=("$volume_name")
        bundles_list+=("$bundle_id")
        echo "  ${CYAN}${index}.${NC} ${GREEN}${display_name}${NC}"
        echo "      Bundle ID: ${bundle_id}"
        echo "      ボリューム: ${volume_name}"
        echo ""
        ((index++))
    done <<< "$mappings_content"
    
    echo "${YELLOW}合計: ${total_apps} 個のアプリ${NC}"
    echo ""
    print_warning "この操作は以下を実行します:"
    echo "  1. すべてのアプリを PlayCover から削除"
    echo "  2. すべての設定ファイルを削除"
    echo "  3. すべての Entitlements を削除"
    echo "  4. すべての Keymapping を削除"
    echo "  5. すべての Containersフォルダを削除"
    echo "  6. すべての APFSボリュームをアンマウント・削除"
    echo "  7. すべてのマッピング情報を削除"
    echo ""
    print_error "この操作は取り消せません！"
    print_error "PlayCoverを含むすべてのアプリが削除されます！"
    echo ""
    echo -n "${RED}本当にすべてのアプリをアンインストールしますか？ (yes/NO):${NC} "
    read confirm
    
    if [[ "$confirm" != "yes" ]]; then
        print_info "キャンセルしました"
        wait_for_enter
        return
    fi
    
    # Start batch uninstallation
    echo ""
    
    local success_count=0
    local fail_count=0
    
    # Loop through all apps (using KSH_ARRAYS - 0-based indexing)
    for ((i=0; i<${#apps_list[@]}; i++)); do
        local app_name="${apps_list[$i]}"
        local volume_name="${volumes_list[$i]}"
        local bundle_id="${bundles_list[$i]}"
        local current=$((i + 1))  # Display 1-based counter to user
        
        # Step 1: Remove app from PlayCover
        local playcover_apps="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/Applications"
        local app_path="${playcover_apps}/${bundle_id}.app"
        
        if [[ -d "$app_path" ]]; then
            rm -rf "$app_path" 2>/dev/null
        fi
        
        # Step 2: Remove app settings
        local app_settings="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/App Settings/${bundle_id}.plist"
        if [[ -f "$app_settings" ]]; then
            rm -f "$app_settings" 2>/dev/null
        fi
        
        # Step 3: Remove entitlements
        local entitlements_file="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/Entitlements/${bundle_id}.plist"
        if [[ -f "$entitlements_file" ]]; then
            rm -f "$entitlements_file" 2>/dev/null
        fi
        
        # Step 4: Remove keymapping
        local keymapping_file="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/Keymapping/${bundle_id}.plist"
        if [[ -f "$keymapping_file" ]]; then
            rm -f "$keymapping_file" 2>/dev/null
        fi
        
        # Step 5: Remove Containers folder
        local containers_dir="${HOME}/Library/Containers/${bundle_id}"
        if [[ -d "$containers_dir" ]]; then
            rm -rf "$containers_dir" 2>/dev/null
        fi
        
        # Step 6: Unmount and delete APFS volume
        local volume_mount_point="${PLAYCOVER_CONTAINER}/${volume_name}"
        if mount | grep -q "$volume_mount_point"; then
            diskutil unmount "$volume_mount_point" >/dev/null 2>&1
        fi
        
        # Find and delete volume
        local volume_device=$(diskutil list | grep "$volume_name" | awk '{print $NF}')
        if [[ -n "$volume_device" ]]; then
            if sudo diskutil apfs deleteVolume "$volume_device" >/dev/null 2>&1; then
                print_success "✓ ${app_name}"
                ((success_count++))
            else
                print_error "✗ ${app_name} (ボリューム削除失敗)"
                ((fail_count++))
            fi
        else
            print_success "✓ ${app_name}"
            ((success_count++))
        fi
    done
    
    # Step 7: Clear entire mapping file (silent)
    echo ""
    if acquire_mapping_lock; then
        > "$MAPPING_FILE"
        release_mapping_lock
    fi
    
    # Step 8: Remove PlayCover.app (silent)
    local playcover_app="/Applications/PlayCover.app"
    rm -rf "$playcover_app" 2>/dev/null
    
    # Summary
    print_success "PlayCover と全アプリを完全削除しました (${success_count} 個)"
    if [[ $fail_count -gt 0 ]]; then
        echo "  ${RED}失敗: ${fail_count} 個${NC}"
    fi
    echo ""
    print_warning "このスクリプトは今後使用できません（PlayCoverを再インストールすると使用可能）"
    echo ""
    echo -n "Enterキーでターミナルを終了します..."
    read
    exit 0
}

#######################################################
# Module 16: Initial Setup Functions (from 0_playcover-initial-setup.command)
#######################################################

check_architecture() {
    print_header "アーキテクチャの確認"
    
    local arch=$(uname -m)
    
    if [[ "$arch" == "arm64" ]]; then
        print_success "Apple Silicon Mac を検出しました (${arch})"
        return 0
    else
        print_error "このスクリプトはApple Silicon Mac専用です"
        print_error "検出されたアーキテクチャ: ${arch}"
        wait_for_enter
        exit 1
    fi
    
    echo ""
}

check_xcode_tools() {
    print_header "Xcode Command Line Tools の確認"
    
    if xcode-select -p >/dev/null 2>&1; then
        local xcode_path=$(xcode-select -p)
        print_success "Xcode Command Line Tools が存在します"
        print_info "パス: ${xcode_path}"
        NEED_XCODE_TOOLS=false
    else
        print_warning "Xcode Command Line Tools が見つかりません"
        NEED_XCODE_TOOLS=true
    fi
    
    echo ""
}

check_homebrew() {
    print_header "Homebrew の確認"
    
    if command -v brew >/dev/null 2>&1; then
        local brew_version=$(brew --version | head -n 1)
        print_success "Homebrew が存在します"
        print_info "${brew_version}"
        NEED_HOMEBREW=false
    else
        print_warning "Homebrew が見つかりません"
        NEED_HOMEBREW=true
    fi
    
    echo ""
}

check_playcover_installation() {
    print_header "PlayCover の確認"
    
    if [[ -d "/Applications/PlayCover.app" ]]; then
        print_success "PlayCover が存在します"
        if [[ -f "/Applications/PlayCover.app/Contents/Info.plist" ]]; then
            local version=$(defaults read "/Applications/PlayCover.app/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "不明")
            print_info "バージョン: ${version}"
        fi
        NEED_PLAYCOVER=false
    else
        print_warning "PlayCover が見つかりません"
        NEED_PLAYCOVER=true
    fi
    
    echo ""
}

select_external_disk() {
    print_header "コンテナボリューム作成先の選択"
    
    local root_device=$(diskutil info / | grep "Device Node:" | awk '{print $3}')
    local internal_disk=$(echo "$root_device" | sed -E 's/disk([0-9]+).*/disk\1/')
    
    print_info "利用可能な外部ストレージを検索中..."
    echo ""
    
    local -a external_disks
    local -a disk_info
    local -a seen_disks
    local index=1
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^/dev/disk[0-9]+ ]]; then
            local disk_id=$(echo "$line" | sed -E 's|^/dev/(disk[0-9]+).*|\1|')
            local full_line="$line"
            
            local already_seen=false
            for seen in "${seen_disks[@]}"; do
                if [[ "$seen" == "$disk_id" ]]; then
                    already_seen=true
                    break
                fi
            done
            
            if $already_seen; then
                continue
            fi
            
            seen_disks+=("$disk_id")
            
            if [[ ! "$full_line" =~ "physical" ]]; then
                continue
            fi
            
            if [[ "$disk_id" == "$internal_disk" ]]; then
                continue
            fi
            
            if [[ "$full_line" =~ "internal" ]]; then
                continue
            fi
            
            local device_name=$(diskutil info "/dev/$disk_id" | grep "Device / Media Name:" | sed 's/.*: *//')
            local total_size=$(diskutil info "/dev/$disk_id" | grep "Disk Size:" | sed 's/.*: *//' | awk '{print $1, $2}')
            
            if [[ -z "$device_name" ]] || [[ -z "$total_size" ]]; then
                continue
            fi
            
            local is_removable=$(diskutil info "/dev/$disk_id" | grep "Removable Media:" | grep "Yes")
            local protocol=$(diskutil info "/dev/$disk_id" | grep "Protocol:" | sed 's/.*: *//')
            local location=$(diskutil info "/dev/$disk_id" | grep "Device Location:" | sed 's/.*: *//')
            
            if [[ -n "$is_removable" ]] || \
               [[ "$protocol" =~ (USB|Thunderbolt|PCI-Express) ]] || \
               [[ "$location" =~ External ]]; then
                external_disks+=("/dev/$disk_id")
                local display_protocol="${protocol:-不明}"
                disk_info+=("${index}. ${device_name} (${total_size}) [${display_protocol}]")
                ((index++))
            fi
        fi
    done < <(diskutil list)
    
    if [[ ${#external_disks[@]} -eq 0 ]]; then
        print_error "外部ストレージが見つかりません"
        print_info "外部ストレージを接続してから再実行してください"
        wait_for_enter
        exit 1
    fi
    
    for info in "${disk_info[@]}"; do
        echo "$info"
    done
    
    echo ""
    
    # If only one disk, auto-select with Enter key
    if [[ ${#external_disks[@]} -eq 1 ]]; then
        echo -n "ボリューム作成先を選択してください (1-${#external_disks[@]}) [Enter=1]: "
        read selection
        # Default to 1 if empty
        selection=${selection:-1}
    else
        echo -n "ボリューム作成先を選択してください (1-${#external_disks[@]}): "
        read selection
    fi
    
    if [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -ge 1 ]] && [[ $selection -le ${#external_disks[@]} ]]; then
        # Convert 1-based user input to 0-based array index
        local array_index=$((selection - 1))
        SELECTED_DISK="${external_disks[$array_index]}"
        print_success "選択されたディスク: ${disk_info[$array_index]}"
    else
        print_error "無効な選択です"
        sleep 1
        osascript -e 'tell application "Terminal" to close (every window whose name contains "playcover")' & exit 1
    fi
    
    echo ""
}

confirm_software_installations() {
    print_header "追加インストール項目の確認"
    
    local need_install=false
    local install_items=()
    
    if $NEED_XCODE_TOOLS; then
        install_items+=("Xcode Command Line Tools")
        need_install=true
    fi
    
    if $NEED_HOMEBREW; then
        install_items+=("Homebrew")
        need_install=true
    fi
    
    if $NEED_PLAYCOVER; then
        install_items+=("playcover-community")
        need_install=true
    fi
    
    if ! $need_install; then
        print_success "すべての必要なソフトウェアがインストール済みです"
        echo ""
        return 0
    fi
    
    print_warning "以下の項目をインストールする必要があります:"
    for item in "${install_items[@]}"; do
        echo "  - ${item}"
    done
    echo ""
    
    echo -n "インストールを続行しますか? (Y/n): "
    read response
    
    case "$response" in
        [nN]|[nN][oO])
            print_info "ユーザーによりインストールがキャンセルされました"
            sleep 1
            osascript -e 'tell application "Terminal" to close (every window whose name contains "playcover")' & exit 0
            ;;
        *)
            print_success "インストールを続行します"
            echo ""
            ;;
    esac
}

create_playcover_main_volume() {
    print_header "PlayCover ボリュームの作成"
    
    if diskutil info "${PLAYCOVER_VOLUME_NAME}" >/dev/null 2>&1; then
        local existing_volume=$(diskutil info "${PLAYCOVER_VOLUME_NAME}" | grep "Mount Point:" | sed 's/.*: *//')
        print_warning "「${PLAYCOVER_VOLUME_NAME}」ボリュームが既に存在します"
        print_info "既存のボリュームを使用します: ${existing_volume}"
        echo ""
        return 0
    fi
    
    print_info "新しいAPFSボリュームを作成中..."
    
    local container=""
    local disk_num=$(echo "$SELECTED_DISK" | sed -E 's|/dev/disk([0-9]+)|\1|')
    
    while IFS= read -r line; do
        if [[ "$line" =~ "APFS Container" ]] && [[ "$line" =~ disk[0-9]+ ]]; then
            local found_container=$(echo "$line" | grep -oE 'disk[0-9]+')
            local container_info=$(diskutil info "$found_container" 2>/dev/null)
            if echo "$container_info" | grep -q "APFS Physical Store.*disk${disk_num}"; then
                container="$found_container"
                break
            fi
        fi
    done < <(diskutil apfs list)
    
    if [[ -z "$container" ]]; then
        print_error "APFSコンテナが見つかりません"
        print_info "選択されたディスク: $SELECTED_DISK"
        wait_for_enter
        exit 1
    fi
    
    if sudo diskutil apfs addVolume "$container" APFS "${PLAYCOVER_VOLUME_NAME}" -nomount > /tmp/apfs_create.log 2>&1; then
        print_success "ボリューム「${PLAYCOVER_VOLUME_NAME}」を作成しました"
    else
        print_error "ボリュームの作成に失敗しました"
        wait_for_enter
        exit 1
    fi
    
    echo ""
}

mount_playcover_main_volume() {
    print_header "PlayCoverボリュームのマウント"
    
    local volume_device=$(diskutil info "${PLAYCOVER_VOLUME_NAME}" | grep "Device Node:" | awk '{print $3}')
    
    if [[ -z "$volume_device" ]]; then
        print_error "ボリュームデバイスが見つかりません"
        wait_for_enter
        exit 1
    fi
    
    local current_mount=$(diskutil info "${PLAYCOVER_VOLUME_NAME}" | grep "Mount Point:" | sed 's/.*: *//')
    if [[ "$current_mount" == "$PLAYCOVER_CONTAINER" ]]; then
        print_success "ボリュームは既にマウントされています"
        print_info "マウントポイント: ${PLAYCOVER_CONTAINER}"
        echo ""
        return 0
    fi
    
    if [[ -n "$current_mount" ]] && [[ "$current_mount" != "Not applicable (no file system)" ]]; then
        print_info "ボリュームが別の場所にマウントされています: ${current_mount}"
        print_info "アンマウント中..."
        if ! sudo diskutil unmount force "$volume_device" 2>/dev/null; then
            print_error "ボリュームのアンマウントに失敗しました"
            wait_for_enter
            exit 1
        fi
        print_success "アンマウントしました"
    fi
    
    local has_internal_data=false
    local has_external_data=false
    
    if [[ -d "$PLAYCOVER_CONTAINER" ]]; then
        if [[ $(find "$PLAYCOVER_CONTAINER" -mindepth 1 -maxdepth 1 ! -name ".*" 2>/dev/null | wc -l) -gt 0 ]]; then
            has_internal_data=true
        fi
    fi
    
    local temp_mount="/tmp/playcover_temp_mount_$$"
    mkdir -p "$temp_mount"
    
    if sudo mount -t apfs -o nobrowse "$volume_device" "$temp_mount" 2>/dev/null; then
        if [[ $(find "$temp_mount" -mindepth 1 -maxdepth 1 ! -name ".*" 2>/dev/null | wc -l) -gt 0 ]]; then
            has_external_data=true
        fi
        sudo umount "$temp_mount" 2>/dev/null
    fi
    
    rmdir "$temp_mount" 2>/dev/null
    
    if $has_internal_data && $has_external_data; then
        print_warning "内部ストレージと外部ストレージの両方にデータが存在します"
        echo ""
        print_info "内部データを外部ストレージに統合してクリーンアップします"
        echo ""
        
        mkdir -p "$temp_mount"
        sudo mount -t apfs -o nobrowse "$volume_device" "$temp_mount"
        print_info "内部データを外部に統合中..."
        sudo rsync -aH --progress "$PLAYCOVER_CONTAINER/" "$temp_mount/" 2>/dev/null || true
        sudo umount "$temp_mount"
        rmdir "$temp_mount"
        print_info "内部ストレージをクリア中..."
        sudo rm -rf "$PLAYCOVER_CONTAINER"
        print_success "内部データを外部に統合しました"
    elif $has_internal_data; then
        print_warning "⚠️  PlayCoverボリューム未マウント状態でPlayCoverが起動され、内部ストレージにデータが作成されています"
        echo ""
        print_info "内部データを外部に移行してクリーンアップします"
        echo ""
        
        mkdir -p "$temp_mount"
        sudo mount -t apfs -o nobrowse "$volume_device" "$temp_mount"
        print_info "データをコピー中..."
        sudo rsync -aH --progress "$PLAYCOVER_CONTAINER/" "$temp_mount/" 2>/dev/null || true
        sudo umount "$temp_mount"
        rmdir "$temp_mount"
        print_info "内部ストレージをクリア中..."
        sudo rm -rf "$PLAYCOVER_CONTAINER"
        print_success "内部データを外部に移行しました"
    else
        if [[ -d "$PLAYCOVER_CONTAINER" ]]; then
            sudo rm -rf "$PLAYCOVER_CONTAINER"
        fi
    fi
    
    sudo mkdir -p "$PLAYCOVER_CONTAINER"
    
    print_info "ボリュームをマウント中..."
    if sudo mount -t apfs -o nobrowse "$volume_device" "$PLAYCOVER_CONTAINER"; then
        print_success "ボリュームを正常にマウントしました"
        print_info "マウントポイント: ${PLAYCOVER_CONTAINER}"
        sudo chown -R $(id -u):$(id -g) "$PLAYCOVER_CONTAINER" 2>/dev/null || true
    else
        print_error "ボリュームのマウントに失敗しました"
        wait_for_enter
        exit 1
    fi
    
    echo ""
}

install_xcode_tools() {
    print_info "Xcode Command Line Tools をインストール中..."
    xcode-select --install 2>/dev/null || true
    print_warning "Xcode Command Line Tools のインストールダイアログが表示されます"
    print_info "インストールが完了するまでお待ちください..."
    while ! xcode-select -p >/dev/null 2>&1; do
        sleep 5
    done
    print_success "Xcode Command Line Tools のインストールが完了しました"
}

install_homebrew() {
    print_info "Homebrew をインストール中..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" < /dev/null > /tmp/homebrew_install.log 2>&1
    if [[ ! -f "${HOME}/.zprofile" ]] || ! grep -q "/opt/homebrew/bin/brew" "${HOME}/.zprofile"; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "${HOME}/.zprofile"
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
    print_success "Homebrew のインストールが完了しました"
}

install_playcover() {
    print_info "PlayCover をインストール中..."
    brew install --cask playcover-community > /tmp/playcover_install.log 2>&1
    print_success "PlayCover のインストールが完了しました"
}

perform_software_installations() {
    print_header "追加ソフトウェアのインストール"
    
    if $NEED_XCODE_TOOLS; then
        install_xcode_tools
        echo ""
    fi
    
    if $NEED_HOMEBREW; then
        install_homebrew
        echo ""
    fi
    
    if $NEED_PLAYCOVER; then
        install_playcover
        echo ""
    fi
    
    if ! $NEED_XCODE_TOOLS && ! $NEED_HOMEBREW && ! $NEED_PLAYCOVER; then
        print_info "インストールが必要な項目はありません"
        echo ""
    fi
}

create_initial_mapping() {
    print_header "マッピングデータの作成"
    
    if ! acquire_mapping_lock; then
        print_error "マッピングファイルのロック取得に失敗しました"
        wait_for_enter
        exit 1
    fi
    
    local mapping_exists=false
    if [[ -f "$MAPPING_FILE" ]]; then
        if grep -q "^${PLAYCOVER_VOLUME_NAME}	${PLAYCOVER_BUNDLE_ID}$" "$MAPPING_FILE" 2>/dev/null; then
            print_warning "マッピングデータが既に存在します"
            mapping_exists=true
        fi
    fi
    
    if ! $mapping_exists; then
        echo "${PLAYCOVER_VOLUME_NAME}	${PLAYCOVER_BUNDLE_ID}" >> "$MAPPING_FILE"
        print_success "マッピングデータを作成しました"
        print_info "ファイル: ${MAPPING_FILE}"
        print_info "データ: ${PLAYCOVER_VOLUME_NAME} → ${PLAYCOVER_BUNDLE_ID}"
    fi
    
    release_mapping_lock
    
    echo ""
}

#######################################################
# Module 17: Environment Check & Initial Setup Flow
#######################################################

is_playcover_environment_ready() {
    # Check if PlayCover is installed
    if [[ ! -d "/Applications/PlayCover.app" ]]; then
        return 1
    fi
    
    # Check if PlayCover volume exists
    if ! diskutil info "${PLAYCOVER_VOLUME_NAME}" >/dev/null 2>&1; then
        return 1
    fi
    
    # Check if mapping file exists
    if [[ ! -f "$MAPPING_FILE" ]]; then
        return 1
    fi
    
    return 0
}

run_initial_setup() {
    clear
    
    print_header "PlayCover 初回セットアップ"
    
    print_warning "このツールを使用するには初期セットアップが必要です"
    echo ""
    
    print_info "セットアップには以下が必要です:"
    echo "  - Apple Silicon Mac"
    echo "  - ターミナルへのフルディスクアクセス権限"
    echo "  - Homebrew（未インストールの場合は自動インストール）"
    echo "  - PlayCover（未インストールの場合は自動インストール）"
    echo "  - 外部ストレージ（SSD推奨）"
    echo ""
    
    echo -n "${YELLOW}初回セットアップを開始しますか？ (y/N):${NC} "
    read response
    
    # Default to No if empty
    response=${response:-N}
    
    case "$response" in
        [yY]|[yY][eE][sS])
            print_success "セットアップを開始します"
            echo ""
            ;;
        *)
            print_info "セットアップをキャンセルしました"
            sleep 1
            osascript -e 'tell application "Terminal" to close (every window whose name contains "playcover")' & exit 0
            ;;
    esac
    
    # Run integrated initial setup
    check_architecture
    check_full_disk_access
    check_xcode_tools
    check_homebrew
    check_playcover_installation
    authenticate_sudo
    select_external_disk
    confirm_software_installations
    
    # Proceed directly to installation
    create_playcover_main_volume
    mount_playcover_main_volume
    perform_software_installations
    create_initial_mapping
    
    # Setup complete
    print_header "セットアップ完了"
    print_success "PlayCover の外部ストレージ環境構築が完了しました"
    echo ""
    print_info "設定内容:"
    echo "  ボリューム名: ${PLAYCOVER_VOLUME_NAME}"
    echo "  マウント先: ${PLAYCOVER_CONTAINER}"
    echo "  マッピングファイル: ${MAPPING_FILE}"
    echo ""
    print_info "PlayCover Complete Manager のメニューに移動します..."
    sleep 3
}

#######################################################
# Module 17: Main Execution
#######################################################

main() {
    # Check if PlayCover environment is ready
    if ! is_playcover_environment_ready; then
        run_initial_setup
        
        # Re-check after setup
        if ! is_playcover_environment_ready; then
            print_error "初期セットアップが完了しましたが、環境が正しく構成されていません"
            wait_for_enter
            exit 1
        fi
    fi
    
    check_mapping_file
    
    # Clean up duplicate entries in mapping file
    deduplicate_mappings
    
    while true; do
        show_menu
        read choice
        
        case "$choice" in
            1)
                app_management_menu
                ;;
            2)
                individual_volume_control
                ;;
            3)
                continue
                ;;
            4)
                eject_disk
                ;;
            0)
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

# Trap Ctrl+C
trap 'echo ""; print_info "終了します"; sleep 1; osascript -e '"'"'tell application "Terminal" to close (every window whose name contains "playcover")'"'"' & exit 0' INT

# Execute main
main
