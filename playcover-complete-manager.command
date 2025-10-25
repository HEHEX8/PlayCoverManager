#!/bin/zsh

#######################################################
# PlayCover Complete Manager
# macOS Tahoe 26.0.1 Compatible
# Version: 4.4.3 - Fix Lock Mechanism + Duplicate Prevention
#######################################################

# Note: set -e is NOT used here to allow graceful error handling
# Volume operations require explicit error checking

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
readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly MAPPING_FILE="${SCRIPT_DIR}/playcover-map.txt"
readonly MAPPING_LOCK_FILE="${MAPPING_FILE}.lock"

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

print_header() {
    echo ""
    echo "${BLUE}▼ $1${NC}"
    echo "${BLUE}───────────────────────────────────────────────────────────────────────────────────────────────────${NC}"
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

print_batch_progress() {
    local current=$1
    local total=$2
    local app_name=$3
    
    echo ""
    echo "${MAGENTA}▶ 処理中: ${current}/${total} - ${app_name}${NC}"
    echo "${MAGENTA}───────────────────────────────────────────────────────────────────────────────────────────────────${NC}"
    echo ""
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
    print_info "PlayCover アプリの確認中..."
    
    if [[ ! -d "/Applications/PlayCover.app" ]]; then
        print_error "PlayCover が見つかりません"
        print_warning "PlayCover を /Applications にインストールしてください"
        exit_with_cleanup 1 "PlayCover が見つかりません"
    fi
    
    print_success "PlayCover が見つかりました"
    echo ""
}

check_full_disk_access() {
    print_info "フルディスクアクセス権限の確認中..."
    
    # Check if we can access a protected directory (e.g., Safari's directory)
    # This is a more reliable test for Full Disk Access
    local test_path="${HOME}/Library/Safari"
    
    if [[ ! -d "$test_path" ]]; then
        # Safari directory doesn't exist, try another test
        test_path="${HOME}/Library/Mail"
    fi
    
    # Try to list the directory - if FDA is granted, this will succeed
    if /bin/ls "$test_path" >/dev/null 2>&1; then
        print_success "フルディスクアクセス権限が確認されました"
        echo ""
        return 0
    else
        print_warning "Terminal にフルディスクアクセス権限がありません"
        print_info "システム設定 > プライバシーとセキュリティ > フルディスクアクセス"
        print_info "から Terminal を有効にしてください"
        echo ""
        echo -n "設定完了後、Enterキーを押してください..."
        read
        
        # Re-check after user confirmation
        if /bin/ls "$test_path" >/dev/null 2>&1; then
            print_success "権限が確認されました"
            echo ""
            return 0
        else
            print_error "権限が確認できませんでした"
            print_warning "この状態で続行すると、エラーが発生する可能性があります"
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

volume_exists() {
    local volume_name=$1
    /usr/sbin/diskutil list | /usr/bin/grep -q "APFS Volume ${volume_name}"
}

get_volume_device() {
    local volume_name=$1
    /usr/sbin/diskutil list | /usr/bin/grep "APFS Volume ${volume_name}" | /usr/bin/awk '{print $NF}'
}

get_mount_point() {
    local volume_name=$1
    local device=$(get_volume_device "$volume_name")
    
    if [[ -z "$device" ]]; then
        echo ""
        return 1
    fi
    
    /usr/sbin/diskutil info "$device" 2>/dev/null | /usr/bin/grep "Mount Point:" | /usr/bin/sed 's/.*Mount Point: *//' | /usr/bin/sed 's/ *$//'
}

mount_volume() {
    local volume_name=$1
    local target_path=$2
    local force=${3:-false}
    
    # Check if volume exists
    if ! volume_exists "$volume_name"; then
        print_error "ボリューム '${volume_name}' が見つかりません"
        return 1
    fi
    
    # Get current mount point
    local current_mount=$(get_mount_point "$volume_name")
    
    # If already mounted at target, nothing to do
    if [[ "$current_mount" == "$target_path" ]]; then
        print_info "既にマウント済みです: $target_path"
        return 0
    fi
    
    # If mounted elsewhere, unmount first
    if [[ -n "$current_mount" ]] && [[ "$current_mount" != "$target_path" ]]; then
        print_info "別の場所にマウントされています: $current_mount"
        print_info "アンマウント中..."
        
        local device=$(get_volume_device "$volume_name")
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
                print_error "❌ マウントがブロックされました"
                print_warning "このアプリは現在、内蔵ストレージで動作しています"
                print_info "検出されたデータ:"
                echo "$content_check" | while read -r line; do
                    echo "  - $line"
                done
                echo ""
                print_info "外部ボリュームをマウントする前に、以下を実行してください:"
                echo ""
                echo "  1. ストレージ切り替え機能（メニュー6）を使用"
                echo "  2. 「内蔵 → 外部」への切り替えを実行"
                echo ""
                print_info "または、内蔵データを手動でバックアップしてから削除:"
                echo "  sudo mv \"$target_path\" \"${target_path}.backup\""
                echo ""
                return 1
            fi
        fi
    else
        # Create target directory if it doesn't exist
        sudo /bin/mkdir -p "$target_path"
    fi
    
    # Mount the volume with nobrowse option to hide from Finder/Desktop
    local device=$(get_volume_device "$volume_name")
    
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

unmount_volume() {
    local volume_name=$1
    
    if ! volume_exists "$volume_name"; then
        print_warning "ボリューム '${volume_name}' が見つかりません"
        return 1
    fi
    
    local current_mount=$(get_mount_point "$volume_name")
    
    if [[ -z "$current_mount" ]]; then
        print_info "既にアンマウント済みです"
        return 0
    fi
    
    local device=$(get_volume_device "$volume_name")
    
    if sudo /usr/sbin/diskutil unmount "$device" >/dev/null 2>&1; then
        print_success "アンマウント成功"
        return 0
    else
        print_error "アンマウント失敗"
        return 1
    fi
}

#######################################################
# Module 5: Storage Detection
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
    local disk_location=$(diskutil info "/dev/$disk_id" 2>/dev/null | /usr/bin/grep "Device Location:" | /usr/bin/awk -F: '{print $2}' | /usr/bin/sed 's/^ *//')
    
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

is_on_external_volume() {
    local container_path=$1
    local storage_type=$(get_storage_type "$container_path")
    [[ "$storage_type" == "external" ]]
}

#######################################################
# Module 6: IPA Installation Functions
#######################################################

check_playcover_volume_mount() {
    print_header "PlayCover ボリュームのマウント確認"
    
    if [[ ! -d "$PLAYCOVER_CONTAINER" ]]; then
        sudo /bin/mkdir -p "$PLAYCOVER_CONTAINER"
    fi
    
    local is_mounted=$(/sbin/mount | /usr/bin/grep " on ${PLAYCOVER_CONTAINER} " | /usr/bin/grep -c "apfs")
    
    if [[ $is_mounted -gt 0 ]]; then
        print_success "PlayCover ボリュームは既にマウント済みです"
        PLAYCOVER_VOLUME_DEVICE=$(/sbin/mount | /usr/bin/grep " on ${PLAYCOVER_CONTAINER} " | /usr/bin/awk '{print $1}')
        print_info "デバイス: ${PLAYCOVER_VOLUME_DEVICE}"
        echo ""
        return 0
    fi
    
    if ! volume_exists "$PLAYCOVER_VOLUME_NAME"; then
        print_error "PlayCover ボリュームが見つかりません"
        print_info "初期セットアップスクリプトを実行してください"
        print_info "実行: ${INITIAL_SETUP_SCRIPT}"
        exit_with_cleanup 1 "PlayCover ボリュームが見つかりません"
    fi
    
    local volume_device=$(get_volume_device "$PLAYCOVER_VOLUME_NAME")
    
    if [[ -z "$volume_device" ]]; then
        print_error "ボリュームデバイスの取得に失敗しました"
        exit_with_cleanup 1 "ボリュームデバイス取得エラー"
    fi
    
    PLAYCOVER_VOLUME_DEVICE="/dev/${volume_device}"
    print_info "ボリュームを発見: ${PLAYCOVER_VOLUME_DEVICE}"
    
    local current_mount=$(/usr/sbin/diskutil info "$PLAYCOVER_VOLUME_DEVICE" 2>/dev/null | /usr/bin/grep "Mount Point" | /usr/bin/sed 's/.*: *//')
    
    if [[ -n "$current_mount" ]] && [[ "$current_mount" != "Not applicable (no file system)" ]]; then
        print_info "ボリュームが別の場所にマウントされています: ${current_mount}"
        if ! sudo /usr/sbin/diskutil unmount force "$PLAYCOVER_VOLUME_DEVICE" 2>/dev/null; then
            print_error "ボリュームのアンマウントに失敗しました"
            exit_with_cleanup 1 "ボリュームアンマウントエラー"
        fi
    fi
    
    print_info "PlayCover ボリュームをマウント中..."
    if sudo /sbin/mount -t apfs -o nobrowse "$PLAYCOVER_VOLUME_DEVICE" "$PLAYCOVER_CONTAINER"; then
        print_success "ボリュームを正常にマウントしました"
        sudo /usr/sbin/chown -R $(id -u):$(id -g) "$PLAYCOVER_CONTAINER" 2>/dev/null || true
        echo ""
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
on error
    tell application "System Events"
        activate
        set theFiles to choose file with prompt "インストールする IPA ファイルを選択してください（複数選択可、.ipa）:" with multiple selections allowed
        
        set posixPaths to {}
        repeat with aFile in theFiles
            set thePath to POSIX path of aFile
            if thePath does not end with ".ipa" then
                error "選択されたファイルに IPA ファイル以外が含まれています: " & thePath
            end if
            set end of posixPaths to thePath
        end repeat
        
        set AppleScript's text item delimiters to linefeed
        return posixPaths as text
    end tell
end try
EOF
)
    
    if [[ -z "$selected" ]]; then
        print_error "IPA ファイルが選択されませんでした"
        exit_with_cleanup 1 "IPA ファイル未選択"
    fi
    
    while IFS= read -r line; do
        if [[ -n "$line" ]] && [[ -f "$line" ]]; then
            if [[ ! "$line" =~ \.ipa$ ]]; then
                print_error "選択されたファイルは IPA ファイルではありません: ${line}"
                exit_with_cleanup 1 "無効なファイル形式"
            fi
            SELECTED_IPAS+=("$line")
        fi
    done <<< "$selected"
    
    TOTAL_IPAS=${#SELECTED_IPAS[@]}
    
    if [[ $TOTAL_IPAS -eq 0 ]]; then
        print_error "有効な IPA ファイルが選択されませんでした"
        exit_with_cleanup 1 "有効なファイルなし"
    fi
    
    print_success "IPA ファイルを ${TOTAL_IPAS} 個選択しました"
    
    echo ""
    print_info "選択されたファイル:"
    local idx=1
    for ipa in "${SELECTED_IPAS[@]}"; do
        echo "  ${idx}. $(basename "$ipa")"
        ((idx++))
    done
    
    if [[ $TOTAL_IPAS -gt 1 ]]; then
        BATCH_MODE=true
        echo ""
        print_info "複数の IPA ファイルを順次処理します"
    fi
    
    echo ""
}

extract_ipa_info() {
    local ipa_file=$1
    print_header "IPA 情報の取得"
    
    local temp_dir=$(mktemp -d)
    
    print_info "IPA ファイルを解析中..."
    print_info "ファイル: $(basename "$ipa_file")"
    
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
    
    print_success "IPA 情報を取得しました"
    print_info "アプリ名: ${APP_NAME}"
    if [[ -n "$APP_VERSION" ]]; then
        print_info "バージョン: ${APP_VERSION}"
    fi
    print_info "Bundle ID: ${APP_BUNDLE_ID}"
    print_info "ボリューム名: ${APP_VOLUME_NAME}"
    
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
    if [[ "$BATCH_MODE" != true ]] || [[ $CURRENT_IPA_INDEX -eq 1 ]]; then
        print_header "インストール先ディスクの選択"
    fi
    
    local playcover_disk=""
    
    if [[ -n "$PLAYCOVER_VOLUME_DEVICE" ]]; then
        playcover_disk=$(echo "$PLAYCOVER_VOLUME_DEVICE" | /usr/bin/sed -E 's|/dev/(disk[0-9]+).*|\1|')
        
        if [[ "$BATCH_MODE" != true ]] || [[ $CURRENT_IPA_INDEX -eq 1 ]]; then
            print_info "PlayCover ボリュームが存在するディスク: ${playcover_disk}"
            print_info "PlayCover ボリュームデバイス: ${PLAYCOVER_VOLUME_DEVICE}"
        fi
        
        local container=$(find_apfs_container "${playcover_disk}")
        
        if [[ -n "$container" ]]; then
            SELECTED_DISK="$container"
            if [[ "$BATCH_MODE" != true ]] || [[ $CURRENT_IPA_INDEX -eq 1 ]]; then
                print_success "インストール先を自動選択しました: ${SELECTED_DISK}"
            fi
        else
            print_error "APFS コンテナの検出に失敗しました"
            return 1
        fi
    else
        print_error "PlayCover ボリュームのデバイス情報が見つかりません"
        return 1
    fi
    
    if [[ "$BATCH_MODE" != true ]] || [[ $CURRENT_IPA_INDEX -eq 1 ]]; then
        echo ""
    fi
    return 0
}

create_app_volume() {
    print_header "アプリボリュームの作成"
    
    local existing_volume=""
    existing_volume=$(/usr/sbin/diskutil info "${APP_VOLUME_NAME}" 2>/dev/null | /usr/bin/grep "Device Node:" | /usr/bin/awk '{print $NF}' | /usr/bin/sed 's|/dev/||')
    
    if [[ -z "$existing_volume" ]]; then
        existing_volume=$(/usr/sbin/diskutil list 2>/dev/null | /usr/bin/grep -E "${APP_VOLUME_NAME}" | /usr/bin/grep "APFS" | head -n 1 | /usr/bin/awk '{print $NF}')
    fi
    
    if [[ -n "$existing_volume" ]]; then
        print_warning "ボリューム「${APP_VOLUME_NAME}」は既に存在します"
        print_info "既存のボリュームを使用します"
        echo ""
        return 0
    fi
    
    print_info "ボリューム「${APP_VOLUME_NAME}」を作成中..."
    
    if sudo /usr/sbin/diskutil apfs addVolume "$SELECTED_DISK" APFS "${APP_VOLUME_NAME}" -nomount > /tmp/apfs_create_app.log 2>&1; then
        print_success "ボリュームを作成しました"
        sleep 1
        echo ""
        return 0
    else
        print_error "ボリュームの作成に失敗しました"
        /bin/cat /tmp/apfs_create_app.log
        return 1
    fi
}

mount_app_volume() {
    print_header "アプリボリュームのマウント"
    
    local target_path="${HOME}/Library/Containers/${APP_BUNDLE_ID}"
    
    if mount_volume "$APP_VOLUME_NAME" "$target_path"; then
        print_success "ボリュームをマウントしました"
        echo ""
        return 0
    else
        print_error "ボリュームのマウントに失敗しました"
        return 1
    fi
}

install_ipa_to_playcover() {
    local ipa_file=$1
    print_header "PlayCover へのインストール"
    
    # Check if app is already installed
    local playcover_apps="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/Applications"
    local existing_app_path=""
    
    print_info "既存アプリを検索中..."
    
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
            print_warning "このアプリは既にインストールされています"
            print_info "既存バージョン: ${existing_version}"
            print_info "新バージョン: ${APP_VERSION}"
            echo ""
            echo -n "上書きインストールしますか？ (y/N): "
            read overwrite_choice </dev/tty
            
            if [[ ! "$overwrite_choice" =~ ^[Yy]$ ]]; then
                print_info "インストールをスキップしました"
                INSTALL_SUCCESS+=("$APP_NAME (スキップ)")
                
                # Still update mapping even if skipped
                update_mapping "$APP_VOLUME_NAME" "$APP_BUNDLE_ID" "$APP_NAME"
                
                echo ""
                return 0
            fi
        fi
    fi
    
    echo ""
    print_info "PlayCover でインストールを開始します..."
    print_info "ファイル: $(basename "$ipa_file")"
    echo ""
    print_warning "PlayCover ウィンドウが開きます"
    print_info "インストールが完了するまでお待ちください"
    echo ""
    
    # Open IPA with PlayCover
    if ! open -a PlayCover "$ipa_file"; then
        print_error "PlayCover の起動に失敗しました"
        INSTALL_FAILED+=("$APP_NAME")
        return 1
    fi
    
    # Wait for installation to complete
    print_info "インストールの完了を待機中..."
    print_info "（PlayCover設定ファイルとアプリ構造を監視しています）"
    echo ""
    
    local max_wait=300  # 5 minutes
    local elapsed=0
    local check_interval=3
    local initial_check_done=false
    
    # PlayCover app settings path
    local app_settings_dir="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/App Settings"
    local app_settings_plist="${app_settings_dir}/${APP_BUNDLE_ID}.plist"
    
    # Track file modification stability (shortened from 9s to 6s)
    local last_mtime=0
    local stable_count=0
    local required_stable_checks=2  # Shortened to 6 seconds (2 checks * 3 seconds)
    
    # Detection Method (v4.2.1 - Correct Implementation):
    # Phase 1: Structure validation (Info.plist + _CodeSignature)
    # Phase 2: PlayCover App Settings file check (MOST RELIABLE)
    #          File: ~/Library/Containers/io.playcover.PlayCover/App Settings/[BundleID].plist
    # Phase 3: File stability confirmation (shortened to 6 seconds)
    # Success criteria: Phase 1 + (Phase 2 OR Phase 3)
    
    while [[ $elapsed -lt $max_wait ]]; do
        sleep $check_interval
        elapsed=$((elapsed + check_interval))
        
        # Check if PlayCover is still running
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
                                        # Check PlayCover settings file creation
                                        if [[ -f "$app_settings_plist" ]]; then
                                            installation_succeeded=true
                                            break
                                        fi
                                        # If settings file doesn't exist yet, accept structure validity as fallback
                                        installation_succeeded=true
                                        break
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
                        
                        # Phase 2: PlayCover settings file check (most reliable)
                        local settings_created=false
                        if [[ -f "$app_settings_plist" ]]; then
                            # App settings file was created by PlayCover
                            settings_created=true
                        fi
                        
                        # Phase 3: Stability check (shortened to 6 seconds)
                        current_app_mtime=$(find "$app_path" -type f -exec stat -f %m {} \; 2>/dev/null | sort -n | tail -1)
                        
                        if [[ -n "$existing_app_path" ]]; then
                            # App already existed - check if it's being updated
                            if [[ $current_app_mtime -gt $existing_mtime ]]; then
                                # Files are being modified
                                if [[ $current_app_mtime -eq $last_mtime ]]; then
                                    # No new changes in this check - increment stability counter
                                    ((stable_count++))
                                    
                                    # Combined check: structure + (settings file OR stability)
                                    if [[ "$structure_valid" == true ]] && { [[ "$settings_created" == true ]] || [[ $stable_count -ge $required_stable_checks ]]; }; then
                                        # Installation confirmed by multiple indicators
                                        found=true
                                        break
                                    fi
                                else
                                    # Still modifying files - reset stability counter
                                    stable_count=0
                                    last_mtime=$current_app_mtime
                                fi
                            fi
                        else
                            # New installation - app appeared after we started
                            if [[ "$initial_check_done" == true ]]; then
                                # Check stability for new installation too
                                if [[ $current_app_mtime -eq $last_mtime ]]; then
                                    ((stable_count++))
                                    
                                    # Combined check: structure + (settings file OR stability)
                                    if [[ "$structure_valid" == true ]] && { [[ "$settings_created" == true ]] || [[ $stable_count -ge $required_stable_checks ]]; }; then
                                        found=true
                                        break
                                    fi
                                else
                                    stable_count=0
                                    last_mtime=$current_app_mtime
                                fi
                            fi
                        fi
                    fi
                fi
            done < <(find "$playcover_apps" -name "*.app" -maxdepth 1 -type d 2>/dev/null)
            
            if [[ "$found" == true ]]; then
                echo ""
                print_success "インストールが完了しました"
                INSTALL_SUCCESS+=("$APP_NAME")
                
                update_mapping "$APP_VOLUME_NAME" "$APP_BUNDLE_ID" "$APP_NAME"
                
                echo ""
                return 0
            fi
        fi
        
        initial_check_done=true
        
        # Show progress indicator with more detailed status
        if [[ $stable_count -gt 0 ]]; then
            echo -n "✓"  # Show checkmark when stable
        else
            echo -n "."  # Show dot when still changing
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

mount_all_volumes() {
    clear
    print_header "全ボリュームのマウント"
    
    authenticate_sudo
    ensure_playcover_main_volume
    
    local mappings_content=$(read_mappings)
    
    if [[ -z "$mappings_content" ]]; then
        print_warning "登録されているアプリボリュームがありません"
        echo ""
        echo -n "Enterキーで続行..."
        read
        return
    fi
    
    local success_count=0
    local fail_count=0
    
    while IFS=$'\t' read -r volume_name bundle_id display_name; do
        if [[ "$bundle_id" == "$PLAYCOVER_BUNDLE_ID" ]]; then
            continue
        fi
        
        echo ""
        print_info "マウント中: ${display_name}"
        
        local target_path="${HOME}/Library/Containers/${bundle_id}"
        
        if mount_volume "$volume_name" "$target_path"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
    done <<< "$mappings_content"
    
    echo ""
    print_success "マウント完了"
    print_info "成功: ${success_count} / 失敗: ${fail_count}"
    echo ""
    echo -n "Enterキーで続行..."
    read
}

unmount_all_volumes() {
    clear
    print_header "全ボリュームのアンマウント"
    
    authenticate_sudo
    
    local mappings_content=$(read_mappings)
    
    if [[ -z "$mappings_content" ]]; then
        print_warning "登録されているアプリボリュームがありません"
        echo ""
        echo -n "Enterキーで続行..."
        read
        return
    fi
    
    local success_count=0
    local fail_count=0
    
    while IFS=$'\t' read -r volume_name bundle_id display_name; do
        if [[ "$bundle_id" == "$PLAYCOVER_BUNDLE_ID" ]]; then
            continue
        fi
        
        echo ""
        print_info "アンマウント中: ${display_name}"
        
        if unmount_volume "$volume_name"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
    done <<< "$mappings_content"
    
    echo ""
    print_success "アンマウント完了"
    print_info "成功: ${success_count} / 失敗: ${fail_count}"
    echo ""
    echo -n "Enterキーで続行..."
    read
}

show_status() {
    clear
    print_header "ボリューム状態確認"
    
    local mappings_content=$(read_mappings)
    
    if [[ -z "$mappings_content" ]]; then
        print_warning "登録されているアプリボリュームがありません"
        echo ""
        echo -n "Enterキーで続行..."
        read
        return
    fi
    
    local index=1
    while IFS=$'\t' read -r volume_name bundle_id display_name; do
        if [[ "$bundle_id" == "$PLAYCOVER_BUNDLE_ID" ]]; then
            continue
        fi
        
        local target_path="${HOME}/Library/Containers/${bundle_id}"
        local storage_type=$(get_storage_type "$target_path")
        local status_icon=""
        local status_text=""
        
        case "$storage_type" in
            "external")
                status_icon="${GREEN}🔌${NC}"
                status_text="外部ストレージ（マウント済み）"
                ;;
            "internal")
                status_icon="${YELLOW}💾${NC}"
                status_text="内蔵ストレージ"
                ;;
            "none")
                status_icon="${BLUE}⚪${NC}"
                status_text="データなし（アンマウント済み）"
                ;;
            *)
                status_icon="❓"
                status_text="不明"
                ;;
        esac
        
        echo "  ${index}. ${status_icon} ${display_name}"
        echo "      ${status_text}"
        echo ""
        ((index++))
    done <<< "$mappings_content"
    
    echo -n "Enterキーで続行..."
    read
}

individual_volume_control() {
    clear
    print_header "個別ボリューム操作"
    
    local mappings_content=$(read_mappings)
    
    if [[ -z "$mappings_content" ]]; then
        print_warning "登録されているアプリボリュームがありません"
        echo ""
        echo -n "Enterキーで続行..."
        read
        return
    fi
    
    echo "登録されているボリューム:"
    echo ""
    
    declare -a mappings_array=()
    local index=1
    while IFS=$'\t' read -r volume_name bundle_id display_name; do
        if [[ "$bundle_id" == "$PLAYCOVER_BUNDLE_ID" ]]; then
            continue
        fi
        
        mappings_array+=("${volume_name}|${bundle_id}|${display_name}")
        
        local target_path="${HOME}/Library/Containers/${bundle_id}"
        local storage_type=$(get_storage_type "$target_path")
        local status_icon=""
        
        case "$storage_type" in
            "external") status_icon="${GREEN}✅${NC}" ;;
            "internal") status_icon="${YELLOW}💾${NC}" ;;
            "none") status_icon="${BLUE}⭕${NC}" ;;
            *) status_icon="❓" ;;
        esac
        
        local current_mount=$(get_mount_point "$volume_name")
        local status_text="アンマウント済み"
        
        if [[ -n "$current_mount" ]]; then
            if [[ "$current_mount" == "$target_path" ]]; then
                status_text="正常にマウント済み"
            else
                status_text="異なる場所にマウント済み"
            fi
        fi
        
        echo "  ${index}. ${status_icon} ${display_name}"
        echo "      (${status_text})"
        echo ""
        ((index++))
    done <<< "$mappings_content"
    
    echo "${BLUE}───────────────────────────────────────────────────────────────────────────────────────────────────${NC}"
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
    
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ $choice -lt 1 ]] || [[ $choice -gt ${#mappings_array[@]} ]]; then
        print_error "無効な選択です"
        sleep 2
        individual_volume_control
        return
    fi
    
    local selected_mapping="${mappings_array[$choice]}"
    IFS='|' read -r volume_name bundle_id display_name <<< "$selected_mapping"
    
    authenticate_sudo
    
    echo ""
    print_header "${display_name} の操作"
    
    local target_path="${HOME}/Library/Containers/${bundle_id}"
    local current_mount=$(get_mount_point "$volume_name")
    
    if [[ -n "$current_mount" ]]; then
        echo "${CYAN}現在: マウント済み${NC}"
        echo ""
        echo -n "アンマウントしますか？ (y/N): "
        read confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            echo ""
            unmount_volume "$volume_name"
        fi
    else
        echo "${CYAN}現在: アンマウント済み${NC}"
        echo ""
        echo -n "マウントしますか？ (Y/n): "
        read confirm
        
        if [[ ! "$confirm" =~ ^[Nn]$ ]]; then
            echo ""
            ensure_playcover_main_volume
            echo ""
            mount_volume "$volume_name" "$target_path"
        fi
    fi
    
    echo ""
    echo -n "Enterキーで続行..."
    read
    
    individual_volume_control
}

eject_disk() {
    clear
    print_header "ディスク全体を取り外し"
    
    authenticate_sudo
    
    print_warning "この操作により、全てのPlayCoverボリュームがアンマウントされます"
    echo ""
    echo -n "続行しますか？ (y/N): "
    read confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "キャンセルしました"
        echo ""
        echo -n "Enterキーで続行..."
        read
        return
    fi
    
    echo ""
    print_info "全ボリュームをアンマウント中..."
    
    local mappings_content=$(read_mappings)
    
    if [[ -n "$mappings_content" ]]; then
        while IFS=$'\t' read -r volume_name bundle_id display_name; do
            unmount_volume "$volume_name" >/dev/null 2>&1 || true
        done <<< "$mappings_content"
    fi
    
    if [[ -n "$PLAYCOVER_VOLUME_DEVICE" ]]; then
        local disk_id=$(echo "$PLAYCOVER_VOLUME_DEVICE" | /usr/bin/sed -E 's|/dev/(disk[0-9]+).*|\1|')
        
        print_info "ディスク ${disk_id} を取り外し中..."
        
        if sudo /usr/sbin/diskutil eject "$disk_id"; then
            print_success "ディスクを安全に取り外しました"
        else
            print_error "ディスクの取り外しに失敗しました"
        fi
    fi
    
    echo ""
    echo -n "Enterキーで続行..."
    read
}

#######################################################
# Module 8: Storage Switching Functions (Complete Implementation)
#######################################################

switch_storage_location() {
    clear
    print_header "ストレージ切り替え（内蔵⇄外部）"
    
    local mappings_content=$(read_mappings)
    
    if [[ -z "$mappings_content" ]]; then
        print_warning "登録されているアプリボリュームがありません"
        echo ""
        echo -n "Enterキーで続行..."
        read
        return
    fi
    
    # Display volume list with current storage type
    echo "登録されているボリューム:"
    echo ""
    
    declare -a mappings_array=()
    local index=1
    while IFS=$'\t' read -r volume_name bundle_id display_name; do
        if [[ "$bundle_id" == "$PLAYCOVER_BUNDLE_ID" ]]; then
            continue
        fi
        
        mappings_array+=("${volume_name}|${bundle_id}|${display_name}")
        
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
    done <<< "$mappings_content"
    
    echo "${BLUE}───────────────────────────────────────────────────────────────────────────────────────────────────${NC}"
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
    
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ $choice -lt 1 ]] || [[ $choice -gt ${#mappings_array[@]} ]]; then
        print_error "無効な選択です"
        sleep 2
        switch_storage_location
        return
    fi
    
    authenticate_sudo
    
    local selected_mapping="${mappings_array[$choice]}"
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
        
        # Check disk space before migration
        print_info "転送前の容量チェック中..."
        local source_size_bytes=$(sudo /usr/bin/du -sk "$target_path" 2>/dev/null | /usr/bin/awk '{print $1}')
        if [[ -z "$source_size_bytes" ]]; then
            print_error "コピー元のサイズを取得できませんでした"
            echo ""
            echo -n "Enterキーで続行..."
            read
            switch_storage_location
            return
        fi
        
        # Get available space on external volume (mount temporarily to check)
        local volume_device=$(get_volume_device "$volume_name")
        local temp_check_mount="/tmp/playcover_check_$$"
        sudo /bin/mkdir -p "$temp_check_mount"
        
        if ! sudo /sbin/mount -t apfs -o nobrowse,rdonly "$volume_device" "$temp_check_mount" 2>/dev/null; then
            print_error "外部ボリュームの容量チェックに失敗しました"
            sudo /bin/rm -rf "$temp_check_mount"
            echo ""
            echo -n "Enterキーで続行..."
            read
            switch_storage_location
            return
        fi
        
        local available_bytes=$(df -k "$temp_check_mount" | tail -1 | /usr/bin/awk '{print $4}')
        sudo /usr/sbin/diskutil unmount "$temp_check_mount" >/dev/null 2>&1
        sudo /bin/rm -rf "$temp_check_mount"
        
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
                echo ""
                echo -n "Enterキーで続行..."
                read
                switch_storage_location
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
            unmount_volume "$volume_name" || true
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
            echo ""
            echo -n "Enterキーで続行..."
            read
            switch_storage_location
            return
        fi
        
        # Debug: Show source path and content
        print_info "コピー元: ${target_path}"
        local file_count=$(sudo /usr/bin/find "$target_path" -type f 2>/dev/null | wc -l | /usr/bin/xargs)
        local total_size=$(sudo /usr/bin/du -sh "$target_path" 2>/dev/null | /usr/bin/awk '{print $1}')
        print_info "  ファイル数: ${file_count}"
        print_info "  データサイズ: ${total_size}"
        
        # Copy data from internal to external
        print_info "データをコピー中... (進捗が表示されます)"
        echo ""
        
        # Use rsync with info=progress2 for real-time progress bar
        sudo /usr/bin/rsync -avH --ignore-errors --info=progress2 "$target_path/" "$temp_mount/"
        local rsync_exit=$?
        
        if [[ $rsync_exit -eq 0 ]] || [[ $rsync_exit -eq 23 ]] || [[ $rsync_exit -eq 24 ]]; then
            echo ""
            print_success "データのコピーが完了しました"
            
            local copied_count=$(sudo /usr/bin/find "$temp_mount" -type f 2>/dev/null | wc -l | /usr/bin/xargs)
            local copied_size=$(sudo /usr/bin/du -sh "$temp_mount" 2>/dev/null | /usr/bin/awk '{print $1}')
            print_info "  コピー完了: ${copied_count} ファイル (${copied_size})"
        else
            echo ""
            print_error "データのコピーに失敗しました"
            sudo /usr/sbin/umount "$temp_mount"
            sudo /bin/rm -rf "$temp_mount"
            echo ""
            echo -n "Enterキーで続行..."
            read
            switch_storage_location
            return
        fi
        
        # Unmount temporary mount
        sudo /usr/sbin/umount "$temp_mount"
        sudo /bin/rm -rf "$temp_mount"
        
        # Backup internal data
        print_info "内蔵データをバックアップ中..."
        sudo /bin/mv "$target_path" "$backup_path"
        
        # Mount volume to proper location
        print_info "ボリュームを正式にマウント中..."
        if mount_volume "$volume_name" "$target_path"; then
            print_success "外部ストレージへの切り替えが完了しました"
            echo ""
            print_info "内蔵データは以下にバックアップされています:"
            echo "  ${backup_path}"
            echo ""
            
            # Ask user to verify operation
            print_warning "【重要】動作確認をしてください"
            echo ""
            echo "アプリを起動して正常に動作するか確認してください:"
            echo "  アプリ名: ${display_name}"
            echo "  保存場所: ${target_path}"
            echo ""
            echo -n "正常に動作しましたか？ (y/N): "
            read verification_result </dev/tty
            
            if [[ "$verification_result" =~ ^[Yy]$ ]]; then
                echo ""
                print_success "動作確認が完了しました"
                print_info "バックアップを削除しています..."
                
                if sudo /bin/rm -rf "$backup_path" 2>/dev/null; then
                    print_success "バックアップを削除しました"
                else
                    print_warning "バックアップの削除に失敗しました"
                    print_info "手動で削除してください: sudo rm -rf \"${backup_path}\""
                fi
            else
                echo ""
                print_error "動作に問題があったため、元に戻します"
                print_info "外部ボリュームをアンマウント中..."
                unmount_volume "$volume_name" || true
                
                print_info "内蔵データを復元中..."
                if sudo /bin/mv "$backup_path" "$target_path" 2>/dev/null; then
                    print_success "元の状態に復元しました"
                else
                    print_error "復元に失敗しました"
                    print_warning "バックアップは残っています: ${backup_path}"
                    print_info "手動で復元してください: sudo mv \"${backup_path}\" \"${target_path}\""
                fi
            fi
        else
            print_error "ボリュームのマウントに失敗しました"
            print_info "内蔵データを復元中..."
            sudo /bin/mv "$backup_path" "$target_path"
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
                echo ""
                echo -n "Enterキーで続行..."
                read
                switch_storage_location
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
            echo ""
            echo -n "Enterキーで続行..."
            read
            switch_storage_location
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
                echo ""
                echo -n "Enterキーで続行..."
                read
                switch_storage_location
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
                echo ""
                echo -n "Enterキーで続行..."
                read
                switch_storage_location
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
                    switch_storage_location
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
                echo ""
                echo -n "Enterキーで続行..."
                read
                switch_storage_location
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
        
        # Backup if it exists
        if [[ -e "$target_path" ]]; then
            print_info "既存ディレクトリをバックアップ中..."
            sudo /bin/mv "$target_path" "$backup_path" 2>/dev/null || {
                print_warning "バックアップに失敗しましたが続行します"
            }
        fi
        
        # Create new internal directory
        sudo /bin/mkdir -p "$target_path"
        
        # Copy data from external to internal
        print_info "データをコピー中... (進捗が表示されます)"
        echo ""
        
        # Use rsync with info=progress2 for real-time progress bar
        sudo /usr/bin/rsync -avH --ignore-errors --info=progress2 "$source_mount/" "$target_path/"
        local rsync_exit=$?
        
        if [[ $rsync_exit -eq 0 ]] || [[ $rsync_exit -eq 23 ]] || [[ $rsync_exit -eq 24 ]]; then
            echo ""
            print_success "データのコピーが完了しました"
            
            local copied_count=$(sudo /usr/bin/find "$target_path" -type f 2>/dev/null | wc -l | /usr/bin/xargs)
            local copied_size=$(sudo /usr/bin/du -sh "$target_path" 2>/dev/null | /usr/bin/awk '{print $1}')
            print_info "  コピー完了: ${copied_count} ファイル (${copied_size})"
            
            sudo /usr/sbin/chown -R $(id -u):$(id -g) "$target_path"
        else
            echo ""
            print_error "データのコピーに失敗しました"
            sudo /bin/rm -rf "$target_path"
            if [[ -d "$backup_path" ]]; then
                print_info "バックアップを復元中..."
                sudo /bin/mv "$backup_path" "$target_path"
            fi
            
            if [[ "$temp_mount_created" == true ]]; then
                sudo /usr/sbin/umount "$source_mount" 2>/dev/null || true
                sudo /bin/rm -rf "$source_mount"
            fi
            
            echo ""
            echo -n "Enterキーで続行..."
            read
            switch_storage_location
            return
        fi
        
        # Unmount volume
        if [[ "$temp_mount_created" == true ]]; then
            print_info "一時マウントをクリーンアップ中..."
            sudo /usr/sbin/umount "$source_mount" 2>/dev/null || true
            sudo /bin/rm -rf "$source_mount"
        else
            print_info "外部ボリュームをアンマウント中..."
            unmount_volume "$volume_name" || true
        fi
        
        print_success "内蔵ストレージへの切り替えが完了しました"
        
        if [[ -d "$backup_path" ]]; then
            echo ""
            print_info "元の外部マウントポイントは以下にバックアップされています:"
            echo "  ${backup_path}"
            echo ""
            
            # Ask user to verify operation
            print_warning "【重要】動作確認をしてください"
            echo ""
            echo "アプリを起動して正常に動作するか確認してください:"
            echo "  アプリ名: ${display_name}"
            echo "  保存場所: ${target_path}"
            echo ""
            echo -n "正常に動作しましたか？ (y/N): "
            read verification_result </dev/tty
            
            if [[ "$verification_result" =~ ^[Yy]$ ]]; then
                # User confirmed OK - delete backup and unmount volume
                print_success "動作確認が完了しました"
                print_info "バックアップを削除しています..."
                
                if sudo /bin/rm -rf "$backup_path" 2>/dev/null; then
                    print_success "バックアップを削除しました"
                else
                    print_warning "バックアップの削除に失敗しました"
                    print_info "手動で削除してください: sudo rm -rf \"${backup_path}\""
                fi
            else
                # User reported issues - rollback
                print_error "動作に問題があったため、元に戻します"
                
                # Remove internal data
                print_info "内蔵データを削除中..."
                sudo /bin/rm -rf "$target_path"
                
                # Restore from backup and remount
                print_info "外部ボリュームを復元中..."
                if sudo /bin/mv "$backup_path" "$target_path" 2>/dev/null; then
                    print_success "ディレクトリを復元しました"
                fi
                
                print_info "外部ボリュームを再マウント中..."
                if mount_volume "$volume_name" "$target_path"; then
                    print_success "元の状態に復元しました"
                else
                    print_error "再マウントに失敗しました"
                    print_warning "バックアップは残っています: ${backup_path}"
                    print_info "手動で復元してください:"
                    echo "  1. sudo mv \"${backup_path}\" \"${target_path}\""
                    echo "  2. sudo /sbin/mount -t apfs -o nobrowse \"/dev/disk*s*\" \"${target_path}\""
                fi
            fi
        fi
    fi
    
    echo ""
    echo -n "Enterキーで続行..."
    read
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
        if [[ "$bundle_id" == "$PLAYCOVER_BUNDLE_ID" ]]; then
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
        echo "${CYAN}【現在のステータス】${NC}"
        echo "  ${GREEN}🔌 外部ストレージ: ${external_count}/${total_count}${NC}    ${YELLOW}💾 内蔵ストレージ: ${internal_count}/${total_count}${NC}    ${BLUE}⚪ データなし: ${unmounted_count}/${total_count}${NC}"
        echo ""
    fi
}

show_menu() {
    clear
    
    echo ""
    echo "${CYAN}═══════════════════════════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "                            ${GREEN}PlayCover 統合管理ツール${NC}"
    echo ""
    echo "                      ${BLUE}macOS Tahoe 26.0.1 対応版${NC}  -  ${BLUE}Version 3.0.1${NC}"
    echo ""
    echo "${CYAN}═══════════════════════════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    show_quick_status
    
    echo "${BLUE}▼ メインメニュー${NC}"
    echo ""
    echo "  ${GREEN}【アプリ管理】${NC}                         ${YELLOW}【ボリューム管理】${NC}                    ${CYAN}【ストレージ管理】${NC}"
    echo "  1. アプリをインストール                3. 全ボリュームをマウント              6. ストレージ切り替え（内蔵⇄外部）"
    echo "  2. アプリをアンインストール            4. 全ボリュームをアンマウント          7. ストレージ状態確認"
    echo "                                         5. 個別ボリューム操作"
    echo ""
    echo "  ${RED}【システム】${NC}"
    echo "  8. ディスク全体を取り外し              9. マッピング情報を表示                0. 終了"
    echo ""
    echo "${CYAN}───────────────────────────────────────────────────────────────────────────────────────────────────${NC}"
    echo ""
    echo -n "${CYAN}選択 (0-9):${NC} "
}

show_mapping_info() {
    clear
    print_header "マッピング情報"
    
    if [[ ! -f "$MAPPING_FILE" ]]; then
        print_warning "マッピングファイルが見つかりません"
        echo ""
        echo -n "Enterキーで続行..."
        read
        return
    fi
    
    local mappings_content=$(read_mappings)
    
    if [[ -z "$mappings_content" ]]; then
        print_warning "登録されているアプリがありません"
        echo ""
        echo -n "Enterキーで続行..."
        read
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

#######################################################
# Module 10: Main Execution
#######################################################

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
    
    select_ipa_files
    
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
            echo ""
            echo -n "Enterキーで続行..."
            read
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
    
    # Display installed apps
    echo ""
    echo "インストールされているアプリ:"
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
    
    local total_apps=${#apps_list[@]}
    
    if [[ $total_apps -eq 0 ]]; then
        print_warning "インストールされているアプリがありません"
        echo ""
        echo -n "Enterキーで続行..."
        read
        return
    fi
    
    # Show uninstall options
    echo ""
    echo "${CYAN}───────────────────────────────────────────────────────────────────────────────────────────────────${NC}"
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
        echo ""
        echo -n "Enterキーで続行..."
        read
        continue
    fi
    
    if [[ $app_choice -eq 0 ]]; then
        return
    fi
    
    # Get selected app info (array index is choice - 1)
    local selected_index=$((app_choice - 1))
    local selected_app="${apps_list[$selected_index]}"
    local selected_volume="${volumes_list[$selected_index]}"
    local selected_bundle="${bundles_list[$selected_index]}"
    
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
        echo ""
        echo -n "Enterキーで続行..."
        read
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
        echo ""
        echo -n "Enterキーで続行..."
        read
        return
    fi
    
    # Start uninstallation
    echo ""
    print_info "アンインストールを開始します..."
    echo ""
    
    # Step 1: Remove app from PlayCover Applications/
    local playcover_apps="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/Applications"
    local app_path="${playcover_apps}/${selected_bundle}.app"
    
    if [[ -d "$app_path" ]]; then
        print_info "PlayCover からアプリを削除中..."
        if rm -rf "$app_path" 2>/dev/null; then
            print_success "アプリを削除しました"
        else
            print_error "アプリの削除に失敗しました"
            echo ""
            echo -n "Enterキーで続行..."
            read
            return
        fi
    else
        print_warning "アプリが見つかりませんでした（既に削除済み）"
    fi
    
    # Step 2: Remove app settings from App Settings/
    local app_settings="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/App Settings/${selected_bundle}.plist"
    if [[ -f "$app_settings" ]]; then
        print_info "アプリ設定を削除中..."
        rm -f "$app_settings" 2>/dev/null
        print_success "設定を削除しました"
    fi
    
    # Step 3: Remove entitlements from Entitlements/
    local entitlements_dir="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/Entitlements"
    local entitlements_file="${entitlements_dir}/${selected_bundle}.plist"
    if [[ -f "$entitlements_file" ]]; then
        print_info "Entitlements を削除中..."
        rm -f "$entitlements_file" 2>/dev/null
        print_success "Entitlements を削除しました"
    fi
    
    # Step 4: Remove keymapping from Keymapping/
    local keymapping_dir="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/Keymapping"
    local keymapping_file="${keymapping_dir}/${selected_bundle}.plist"
    if [[ -f "$keymapping_file" ]]; then
        print_info "Keymapping を削除中..."
        rm -f "$keymapping_file" 2>/dev/null
        print_success "Keymapping を削除しました"
    fi
    
    # Step 5: Remove Containers folder for the app
    local containers_dir="${HOME}/Library/Containers/${selected_bundle}"
    if [[ -d "$containers_dir" ]]; then
        print_info "Containersフォルダを削除中..."
        if rm -rf "$containers_dir" 2>/dev/null; then
            print_success "Containersフォルダを削除しました"
        else
            print_warning "Containersフォルダの削除に失敗しました"
        fi
    fi
    
    # Step 7: Unmount volume if mounted
    local volume_mount_point="${PLAYCOVER_CONTAINER}/${selected_volume}"
    if mount | grep -q "$volume_mount_point"; then
        print_info "ボリュームをアンマウント中..."
        if diskutil unmount "$volume_mount_point" >/dev/null 2>&1; then
            print_success "ボリュームをアンマウントしました"
        else
            print_warning "アンマウントに失敗しました（続行します）"
        fi
    fi
    
    # Step 8: Delete APFS volume
    print_info "APFSボリュームを削除中..."
    
    # Find the volume device
    local volume_device=$(diskutil list | grep "$selected_volume" | awk '{print $NF}')
    
    if [[ -n "$volume_device" ]]; then
        if sudo diskutil apfs deleteVolume "$volume_device" >/dev/null 2>&1; then
            print_success "ボリュームを削除しました"
        else
            print_error "ボリュームの削除に失敗しました"
            echo ""
            echo "手動で削除する必要があります:"
            echo "  sudo diskutil apfs deleteVolume $volume_device"
            echo ""
            echo -n "Enterキーで続行..."
            read
            return
        fi
    else
        print_warning "ボリュームが見つかりませんでした（既に削除済み）"
    fi
    
    # Step 9: Remove from mapping file
    print_info "マッピング情報を削除中..."
    
    # Use remove_mapping function for consistency
    if ! remove_mapping "$selected_bundle"; then
        print_error "マッピング情報の削除に失敗しました"
        echo ""
        echo -n "Enterキーで続行..."
        read
        return
    fi
    
    print_success "マッピング情報を削除しました"
    
    echo ""
    print_success "アンインストールが完了しました"
    echo ""
    echo "削除したアプリ: ${GREEN}${selected_app}${NC}"
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
        echo "${CYAN}残り ${remaining_count} 個のアプリがインストールされています${NC}"
        echo ""
        echo -n "${YELLOW}続けて別のアプリをアンインストールしますか？ (y/N):${NC} "
        read continue_uninstall
        
        if [[ ! "$continue_uninstall" =~ ^[Yy] ]]; then
            return
        fi
        # Loop continues for next uninstallation
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
        echo ""
        echo -n "Enterキーで続行..."
        read
        return
    fi
    
    local mappings_content=$(read_mappings)
    
    if [[ -z "$mappings_content" ]]; then
        print_warning "インストールされているアプリがありません"
        echo ""
        echo -n "Enterキーで続行..."
        read
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
        echo ""
        echo -n "Enterキーで続行..."
        read
        return
    fi
    
    # Start batch uninstallation
    echo ""
    print_info "一括アンインストールを開始します..."
    echo ""
    
    local success_count=0
    local fail_count=0
    
    # Loop through all apps (zsh arrays are 1-indexed by default)
    for ((i=1; i<=${#apps_list[@]}; i++)); do
        local app_name="${apps_list[$i]}"
        local volume_name="${volumes_list[$i]}"
        local bundle_id="${bundles_list[$i]}"
        local current=$i
        
        echo ""
        print_info "[${current}/${total_apps}] ${app_name} を削除中..."
        echo ""
        
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
    
    # Step 7: Clear entire mapping file
    echo ""
    print_info "マッピング情報をクリア中..."
    
    # Use acquire_mapping_lock function for consistency
    if acquire_mapping_lock; then
        # Clear mapping file
        > "$MAPPING_FILE"
        release_mapping_lock
        print_success "マッピング情報をクリアしました"
    else
        print_warning "マッピングファイルのロック取得に失敗しました"
    fi
    
    # Summary
    echo ""
    echo "${CYAN}═══════════════════════════════════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    print_success "一括アンインストールが完了しました"
    echo ""
    echo "  ${GREEN}成功: ${success_count} 個${NC}"
    if [[ $fail_count -gt 0 ]]; then
        echo "  ${RED}失敗: ${fail_count} 個${NC}"
    fi
    echo ""
    echo -n "Enterキーでメニューに戻る..."
    read
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
        echo ""
        echo -n "Enterキーで続行..."
        read
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
        echo ""
        echo -n "Enterキーで続行..."
        read
        exit 1
    fi
    
    for info in "${disk_info[@]}"; do
        echo "$info"
    done
    
    echo ""
    echo -n "ボリューム作成先を選択してください (1-${#external_disks[@]}): "
    read selection
    
    if [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -ge 1 ]] && [[ $selection -le ${#external_disks[@]} ]]; then
        SELECTED_DISK="${external_disks[$selection]}"
        print_success "選択されたディスク: ${disk_info[$selection]}"
    else
        print_error "無効な選択です"
        echo ""
        echo -n "Enterキーで続行..."
        read
        exit 1
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
            echo ""
            echo -n "Enterキーで続行..."
            read
            exit 0
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
        echo ""
        echo -n "Enterキーで続行..."
        read
        exit 1
    fi
    
    if sudo diskutil apfs addVolume "$container" APFS "${PLAYCOVER_VOLUME_NAME}" -nomount > /tmp/apfs_create.log 2>&1; then
        print_success "ボリューム「${PLAYCOVER_VOLUME_NAME}」を作成しました"
    else
        print_error "ボリュームの作成に失敗しました"
        echo ""
        echo -n "Enterキーで続行..."
        read
        exit 1
    fi
    
    echo ""
}

mount_playcover_main_volume() {
    print_header "PlayCoverボリュームのマウント"
    
    local volume_device=$(diskutil info "${PLAYCOVER_VOLUME_NAME}" | grep "Device Node:" | awk '{print $3}')
    
    if [[ -z "$volume_device" ]]; then
        print_error "ボリュームデバイスが見つかりません"
        echo ""
        echo -n "Enterキーで続行..."
        read
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
            echo ""
            echo -n "Enterキーで続行..."
            read
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
        echo "1. 内部ストレージのデータを使用 (外部を上書き)"
        echo "2. 外部ストレージのデータを使用 (内部を削除)"
        echo ""
        echo -n "選択してください (1/2): "
        read data_choice
        
        case "$data_choice" in
            1)
                print_info "内部ストレージのデータを使用します"
                mkdir -p "$temp_mount"
                sudo mount -t apfs -o nobrowse "$volume_device" "$temp_mount"
                print_info "外部ストレージをクリア中..."
                sudo rm -rf "$temp_mount"/* "$temp_mount"/.[!.]* 2>/dev/null || true
                print_info "データをコピー中..."
                sudo cp -R "$PLAYCOVER_CONTAINER"/* "$temp_mount"/ 2>/dev/null || true
                sudo cp -R "$PLAYCOVER_CONTAINER"/.[!.]* "$temp_mount"/ 2>/dev/null || true
                sudo umount "$temp_mount"
                rmdir "$temp_mount"
                print_info "内部ストレージをクリア中..."
                sudo rm -rf "$PLAYCOVER_CONTAINER"
                ;;
            2)
                print_info "外部ストレージのデータを使用します"
                print_info "内部ストレージをクリア中..."
                sudo rm -rf "$PLAYCOVER_CONTAINER"
                ;;
            *)
                print_error "無効な選択です"
                echo ""
                echo -n "Enterキーで続行..."
                read
                exit 1
                ;;
        esac
    elif $has_internal_data; then
        print_info "内部ストレージのデータを外部に移行します"
        mkdir -p "$temp_mount"
        sudo mount -t apfs -o nobrowse "$volume_device" "$temp_mount"
        print_info "データをコピー中..."
        sudo cp -R "$PLAYCOVER_CONTAINER"/* "$temp_mount"/ 2>/dev/null || true
        sudo cp -R "$PLAYCOVER_CONTAINER"/.[!.]* "$temp_mount"/ 2>/dev/null || true
        sudo umount "$temp_mount"
        rmdir "$temp_mount"
        print_info "内部ストレージをクリア中..."
        sudo rm -rf "$PLAYCOVER_CONTAINER"
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
        echo ""
        echo -n "Enterキーで続行..."
        read
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
        echo ""
        echo -n "Enterキーで続行..."
        read
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
    
    echo -n "${YELLOW}初回セットアップを開始しますか？ (Y/n):${NC} "
    read response
    
    case "$response" in
        [nN]|[nN][oO])
            print_info "セットアップをキャンセルしました"
            echo ""
            print_info "PlayCoverをインストール後、再度実行してください"
            echo ""
            echo -n "Enterキーで続行..."
            read
            exit 0
            ;;
        *)
            print_success "セットアップを開始します"
            echo ""
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
    
    # Final confirmation
    print_header "最終確認"
    print_warning "以下の操作を実行します:"
    echo "  1. 外部ストレージに PlayCover ボリュームを作成"
    echo "  2. PlayCover コンテナを外部ストレージにマウント"
    if $NEED_XCODE_TOOLS || $NEED_HOMEBREW || $NEED_PLAYCOVER; then
        echo "  3. 不足しているソフトウェアをインストール"
    fi
    echo ""
    print_info "選択されたディスク: ${SELECTED_DISK}"
    print_info "マウント先: ${PLAYCOVER_CONTAINER}"
    echo ""
    echo -n "続行してもよろしいですか? (Y/n): "
    read final_confirm
    
    case "$final_confirm" in
        [nN]|[nN][oO])
            print_info "ユーザーにより処理がキャンセルされました"
            echo ""
            echo -n "Enterキーで続行..."
            read
            exit 0
            ;;
        *)
            print_success "処理を開始します"
            echo ""
            ;;
    esac
    
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
            echo ""
            echo -n "Enterキーで続行..."
            read
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
                install_workflow
                ;;
            2)
                uninstall_workflow
                ;;
            3)
                mount_all_volumes
                ;;
            4)
                unmount_all_volumes
                ;;
            5)
                individual_volume_control
                ;;
            6)
                switch_storage_location
                ;;
            7)
                show_status
                ;;
            8)
                eject_disk
                ;;
            9)
                show_mapping_info
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
