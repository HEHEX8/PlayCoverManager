#!/bin/zsh

#######################################################
# PlayCover IPA Installation Script (Batch Mode)
# macOS Tahoe 26.0.1 Compatible
# Version: 2.0.0 - Batch Installation Support
#######################################################

set -e

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
readonly INITIAL_SETUP_SCRIPT="${SCRIPT_DIR}/0_playcover-initial-setup.command"

# Global variables
declare -a SELECTED_IPAS=()  # Array for multiple IPAs
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

print_batch_progress() {
    local current=$1
    local total=$2
    local app_name=$3
    
    echo ""
    echo "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "${MAGENTA}  処理中: ${current}/${total} - ${app_name}${NC}"
    echo "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
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
        # Close terminal window without confirmation prompt
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
# 01. PlayCover App Existence Check
#######################################################

check_playcover_app() {
    print_header "01. PlayCover アプリの確認"
    
    if [[ -d "/Applications/PlayCover.app" ]]; then
        print_success "PlayCover が見つかりました"
        return 0
    else
        print_error "PlayCover がインストールされていません"
        echo ""
        print_warning "初期セットアップスクリプトを実行してください:"
        print_info "  ${INITIAL_SETUP_SCRIPT}"
        echo ""
        exit_with_cleanup 1 "PlayCover が未インストール"
    fi
    
    echo ""
}

#######################################################
# 02. PlayCover Mapping Check
#######################################################

check_playcover_mapping() {
    print_header "02. PlayCover マッピングの確認"
    
    if [[ ! -f "$MAPPING_FILE" ]]; then
        print_error "マッピングファイルが見つかりません"
        echo ""
        print_warning "初期セットアップスクリプトを実行してください:"
        print_info "  ${INITIAL_SETUP_SCRIPT}"
        echo ""
        exit_with_cleanup 1 "マッピングファイル不在"
    fi
    
    if grep -q "^${PLAYCOVER_VOLUME_NAME}[[:space:]]${PLAYCOVER_BUNDLE_ID}$" "$MAPPING_FILE" 2>/dev/null; then
        print_success "PlayCover のマッピングが登録されています"
    else
        print_error "PlayCover のマッピングが登録されていません"
        echo ""
        print_warning "初期セットアップスクリプトを実行してください:"
        print_info "  ${INITIAL_SETUP_SCRIPT}"
        echo ""
        exit_with_cleanup 1 "PlayCover マッピング未登録"
    fi
    
    echo ""
}

#######################################################
# 03. Full Disk Access Check
#######################################################

check_full_disk_access() {
    print_header "03. フルディスクアクセスの確認"
    
    local test_path="${HOME}/Library/Safari"
    
    if ls "$test_path" >/dev/null 2>&1; then
        print_success "フルディスクアクセス権限が付与されています"
    else
        print_error "フルディスクアクセス権限が必要です"
        echo ""
        print_warning "以下の手順で権限を付与してください:"
        echo "  1. システム設定を開く"
        echo "  2. プライバシーとセキュリティ > フルディスクアクセス"
        echo "  3. ターミナル.app を追加"
        echo ""
        exit_with_cleanup 1 "フルディスクアクセス権限なし"
    fi
    
    echo ""
}

#######################################################
# 04. Sudo Pre-authentication
#######################################################

authenticate_sudo() {
    print_header "04. スーパーユーザー権限の取得"
    
    print_info "管理者パスワードを入力してください..."
    if sudo -v; then
        SUDO_AUTHENTICATED=true
        print_success "認証に成功しました"
        
        # Keep sudo alive
        (while true; do sudo -n true; sleep 50; done 2>/dev/null) &
    else
        print_error "認証に失敗しました"
        exit_with_cleanup 1 "sudo認証失敗"
    fi
    
    echo ""
}

#######################################################
# 05. PlayCover Volume Mount Check
#######################################################

check_playcover_volume_mount() {
    print_header "05. PlayCover ボリュームのマウント確認"
    
    # Check if container path is a mount point
    if mount | grep -q " on ${PLAYCOVER_CONTAINER} "; then
        print_success "PlayCover ボリュームは既にマウントされています"
        
        # Get volume device
        PLAYCOVER_VOLUME_DEVICE=$(mount | grep " on ${PLAYCOVER_CONTAINER} " | awk '{print $1}')
        print_info "デバイス: ${PLAYCOVER_VOLUME_DEVICE}"
    else
        print_warning "PlayCover ボリュームがマウントされていません"
        mount_playcover_volume
    fi
    
    echo ""
}

mount_playcover_volume() {
    print_info "PlayCover ボリュームを検索中..."
    
    # Find PlayCover volume
    local volume_device=$(diskutil list | grep -E "${PLAYCOVER_VOLUME_NAME}.*APFS" | head -n 1 | awk '{print $NF}')
    
    if [[ -z "$volume_device" ]]; then
        print_error "PlayCover ボリュームが見つかりません"
        echo ""
        print_warning "初期セットアップスクリプトを実行してください:"
        print_info "  ${INITIAL_SETUP_SCRIPT}"
        echo ""
        exit_with_cleanup 1 "PlayCover ボリューム不在"
    fi
    
    PLAYCOVER_VOLUME_DEVICE="/dev/${volume_device}"
    print_info "ボリュームを発見: ${PLAYCOVER_VOLUME_DEVICE}"
    
    # Check if volume is mounted elsewhere
    local current_mount=$(diskutil info "$PLAYCOVER_VOLUME_DEVICE" 2>/dev/null | grep "Mount Point" | sed 's/.*: *//')
    
    if [[ -n "$current_mount" ]] && [[ "$current_mount" != "Not applicable (no file system)" ]]; then
        print_info "ボリュームが別の場所にマウントされています: ${current_mount}"
        if ! sudo diskutil unmount force "$PLAYCOVER_VOLUME_DEVICE" 2>/dev/null; then
            print_error "ボリュームのアンマウントに失敗しました"
            exit_with_cleanup 1 "ボリュームアンマウントエラー"
        fi
    fi
    
    # Mount to container path with nobrowse option (hide from Finder/Desktop)
    print_info "PlayCover ボリュームをマウント中..."
    if sudo mount -t apfs -o nobrowse "$PLAYCOVER_VOLUME_DEVICE" "$PLAYCOVER_CONTAINER"; then
        print_success "ボリュームを正常にマウントしました"
        sudo chown -R $(id -u):$(id -g) "$PLAYCOVER_CONTAINER" 2>/dev/null || true
    else
        print_error "ボリュームのマウントに失敗しました"
        exit_with_cleanup 1 "ボリュームマウントエラー"
    fi
}

#######################################################
# 06. IPA Selection (Multiple Files)
#######################################################

select_ipa_files() {
    print_header "06. インストールする IPA ファイルの選択"
    
    # Use AppleScript to select multiple IPA files
    local selected=$(osascript <<'EOF' 2>/dev/null
try
    tell application "System Events"
        activate
        -- Allow multiple file selection
        set theFiles to choose file with prompt "インストールする IPA ファイルを選択してください（複数選択可）:" of type {"ipa", "public.archive", "public.data"} with multiple selections allowed
        
        -- Convert file list to POSIX paths
        set posixPaths to {}
        repeat with aFile in theFiles
            set end of posixPaths to POSIX path of aFile
        end repeat
        
        -- Join paths with newline
        set AppleScript's text item delimiters to linefeed
        return posixPaths as text
    end tell
on error
    -- Fallback: allow all files with multiple selection
    tell application "System Events"
        activate
        set theFiles to choose file with prompt "インストールする IPA ファイルを選択してください（複数選択可、.ipa）:" with multiple selections allowed
        
        set posixPaths to {}
        repeat with aFile in theFiles
            set thePath to POSIX path of aFile
            -- Verify .ipa extension
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
    
    # Parse selected files into array
    while IFS= read -r line; do
        if [[ -n "$line" ]] && [[ -f "$line" ]]; then
            # Verify file extension
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
    
    # Display selected files
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
        print_info "バッチモード: 複数の IPA ファイルを順次処理します"
    fi
    
    echo ""
}

#######################################################
# 07. Extract IPA Information
#######################################################

extract_ipa_info() {
    local ipa_file=$1
    print_header "07. IPA 情報の取得"
    
    # Create temporary directory for extraction
    local temp_dir=$(mktemp -d)
    
    print_info "IPA ファイルを解析中..."
    print_info "ファイル: $(basename "$ipa_file")"
    
    # Extract only Info.plist for faster processing
    # Find Info.plist path in zip without extracting everything
    local plist_path=$(unzip -l "$ipa_file" 2>/dev/null | grep -E "Payload/.*\.app/Info\.plist" | head -n 1 | awk '{print $NF}')
    
    if [[ -z "$plist_path" ]]; then
        print_error "IPA 内に Info.plist が見つかりません"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Extract only the Info.plist file
    if ! unzip -q "$ipa_file" "$plist_path" -d "$temp_dir" 2>/dev/null; then
        print_error "Info.plist の解凍に失敗しました"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Find Info.plist
    local info_plist="${temp_dir}/${plist_path}"
    
    if [[ -z "$info_plist" ]]; then
        print_error "Info.plist が見つかりません"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Extract Bundle Identifier
    APP_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$info_plist" 2>/dev/null)
    
    if [[ -z "$APP_BUNDLE_ID" ]]; then
        print_error "Bundle Identifier の取得に失敗しました"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Extract App Version
    APP_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$info_plist" 2>/dev/null)
    if [[ -z "$APP_VERSION" ]]; then
        APP_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$info_plist" 2>/dev/null)
    fi
    
    # Extract English App Name first (always needed for volume naming)
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
    
    # Extract Japanese App Name (priority: ja_JP localization)
    local app_name_ja=""
    
    # Try to get localized Japanese name from InfoPlist.strings
    local strings_path=$(unzip -l "$ipa_file" 2>/dev/null | grep -E "Payload/.*\.app/ja\.lproj/InfoPlist\.strings" | head -n 1 | awk '{print $NF}')
    if [[ -n "$strings_path" ]]; then
        # Extract Japanese strings file
        unzip -q "$ipa_file" "$strings_path" -d "$temp_dir" 2>/dev/null || true
        local ja_strings="${temp_dir}/${strings_path}"
        if [[ -f "$ja_strings" ]]; then
            # Try to extract CFBundleDisplayName from Japanese strings
            app_name_ja=$(plutil -convert xml1 -o - "$ja_strings" 2>/dev/null | grep -A 1 "CFBundleDisplayName" | tail -n 1 | sed 's/.*<string>\(.*\)<\/string>.*/\1/' || true)
        fi
    fi
    
    # Set APP_NAME (Japanese first, then English fallback)
    if [[ -n "$app_name_ja" ]]; then
        APP_NAME="$app_name_ja"
    else
        APP_NAME="$app_name_en"
    fi
    
    # Always set APP_NAME_EN for volume naming
    APP_NAME_EN="$app_name_en"
    
    # Clean up English name for volume naming (remove spaces and symbols, keep only alphanumeric)
    APP_VOLUME_NAME=$(echo "$APP_NAME_EN" | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null | sed 's/[^a-zA-Z0-9]//g' || echo "$APP_NAME_EN" | sed 's/[^a-zA-Z0-9]//g')
    
    # Cleanup
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

#######################################################
# 08. Select Installation Destination
#######################################################

select_installation_disk() {
    # Skip header in batch mode to avoid clutter
    if [[ "$BATCH_MODE" != true ]] || [[ $CURRENT_IPA_INDEX -eq 1 ]]; then
        print_header "08. インストール先ディスクの選択"
    fi
    
    # Find disk where PlayCover volume is located
    local playcover_disk=""
    
    if [[ -n "$PLAYCOVER_VOLUME_DEVICE" ]]; then
        # Extract disk number from volume device (e.g., /dev/disk5s1 -> disk5)
        playcover_disk=$(echo "$PLAYCOVER_VOLUME_DEVICE" | sed -E 's|/dev/(disk[0-9]+).*|\1|')
        
        if [[ "$BATCH_MODE" != true ]] || [[ $CURRENT_IPA_INDEX -eq 1 ]]; then
            print_info "PlayCover ボリュームが存在するディスク: ${playcover_disk}"
            print_info "PlayCover ボリュームデバイス: ${PLAYCOVER_VOLUME_DEVICE}"
        fi
        
        # Find APFS container for this disk
        local container=$(find_apfs_container "${playcover_disk}")
        
        if [[ -n "$container" ]]; then
            SELECTED_DISK="$container"
            if [[ "$BATCH_MODE" != true ]] || [[ $CURRENT_IPA_INDEX -eq 1 ]]; then
                print_success "インストール先を自動選択しました: ${SELECTED_DISK}"
            fi
        else
            print_error "APFS コンテナの検出に失敗しました"
            print_info "デバッグ: diskutil list の出力を確認中..."
            diskutil list | grep -A 5 "$playcover_disk"
            echo ""
            print_info "デバッグ: diskutil info の出力を確認中..."
            diskutil info "$PLAYCOVER_VOLUME_DEVICE" | grep -E "(Container|Type|APFS)"
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

find_apfs_container() {
    local physical_disk=$1
    local container=""
    
    # Method 1: Get APFS Container directly from the volume device
    if [[ "$physical_disk" =~ disk[0-9]+ ]]; then
        # If input is a volume device (e.g., disk5s1), get info from PLAYCOVER_VOLUME_DEVICE
        local volume_info=$(diskutil info "$PLAYCOVER_VOLUME_DEVICE" 2>/dev/null)
        
        # Extract APFS Container from volume info
        container=$(echo "$volume_info" | grep "APFS Container:" | awk '{print $NF}')
        
        if [[ -n "$container" ]]; then
            echo "$container"
            return 0
        fi
    fi
    
    # Method 2: Check if the disk itself is already a container
    local disk_num=$(echo "$physical_disk" | sed -E 's|.*/disk([0-9]+).*|\1|')
    local disk_device="/dev/disk${disk_num}"
    
    local disk_info=$(diskutil info "$disk_device" 2>/dev/null)
    if echo "$disk_info" | grep -q "APFS Container Scheme"; then
        # This disk is an APFS container
        container="disk${disk_num}"
        echo "$container"
        return 0
    fi
    
    # Method 3: Look for synthesized disk with same base number
    while IFS= read -r line; do
        if [[ "$line" =~ /dev/(disk${disk_num})[[:space:]].*synthesized ]]; then
            local found_disk=$(echo "$line" | grep -oE 'disk[0-9]+' | head -n 1)
            container="$found_disk"
            echo "$container"
            return 0
        fi
    done < <(diskutil list)
    
    # Method 4: Use diskutil apfs list to find container
    while IFS= read -r line; do
        if [[ "$line" =~ "APFS Container" ]]; then
            local found_container=$(echo "$line" | grep -oE 'disk[0-9]+')
            if [[ -n "$found_container" ]]; then
                local container_info=$(diskutil info "$found_container" 2>/dev/null)
                # Check if this container is on the same physical disk
                if echo "$container_info" | grep -q "disk${disk_num}"; then
                    container="$found_container"
                    echo "$container"
                    return 0
                fi
            fi
        fi
    done < <(diskutil apfs list)
    
    echo "$container"
}

#######################################################
# 09. Create App Volume
#######################################################

create_app_volume() {
    print_header "09. アプリボリュームの作成"
    
    # Check if volume already exists - use diskutil info for reliable detection
    local existing_volume=""
    existing_volume=$(diskutil info "${APP_VOLUME_NAME}" 2>/dev/null | grep "Device Node:" | awk '{print $NF}' | sed 's|/dev/||')
    
    # Fallback: search in diskutil list
    if [[ -z "$existing_volume" ]]; then
        existing_volume=$(diskutil list 2>/dev/null | grep -E "${APP_VOLUME_NAME}" | grep "APFS" | head -n 1 | awk '{print $NF}')
    fi
    
    if [[ -n "$existing_volume" ]]; then
        print_warning "ボリューム「${APP_VOLUME_NAME}」は既に存在します"
        
        # Verify the volume is valid
        print_info "ボリュームの整合性を確認中..."
        if diskutil info "/dev/${existing_volume}" 2>/dev/null | grep -q "File System Personality.*APFS"; then
            print_success "既存のボリュームは有効です"
            
            # Check mount status using diskutil info
            local mount_point=$(diskutil info "/dev/${existing_volume}" 2>/dev/null | grep "Mount Point:" | sed 's/.*: *//')
            if [[ -n "$mount_point" ]] && [[ "$mount_point" != "Not applicable (no file system)" ]]; then
                print_info "既存のマウントをアンマウント中: ${mount_point}"
                sudo diskutil unmount "/dev/${existing_volume}" 2>/dev/null || {
                    print_warning "アンマウントに失敗しました（強制アンマウントを試行）"
                    sudo umount -f "$mount_point" 2>/dev/null || true
                }
            fi
        else
            print_error "既存のボリュームが破損している可能性があります"
            
            # In batch mode, auto-recreate without prompting
            if [[ "$BATCH_MODE" == true ]]; then
                print_info "既存のボリュームを自動で再作成します..."
                sudo diskutil apfs deleteVolume "/dev/${existing_volume}" 2>/dev/null || {
                    print_error "ボリュームの削除に失敗しました"
                    return 1
                }
                existing_volume=""
            else
                echo ""
                echo "ボリュームを再作成しますか？ (y/n): "
                read recreate_choice
                if [[ "$recreate_choice" == "y" ]]; then
                    print_info "既存のボリュームを削除中..."
                    sudo diskutil apfs deleteVolume "/dev/${existing_volume}" 2>/dev/null || {
                        print_error "ボリュームの削除に失敗しました"
                        return 1
                    }
                    existing_volume=""
                else
                    return 1
                fi
            fi
        fi
    fi
    
    if [[ -z "$existing_volume" ]]; then
        # Confirmation prompt before creating volume (skip in batch mode after first confirmation)
        if [[ "$BATCH_MODE" != true ]] || [[ $CURRENT_IPA_INDEX -eq 1 ]]; then
            echo ""
            echo "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo "${BLUE}  ボリューム作成の確認${NC}"
            echo "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
            echo "  ${GREEN}アプリ名:${NC} ${APP_NAME}"
            if [[ -n "$APP_VERSION" ]]; then
                echo "  ${GREEN}バージョン:${NC} ${APP_VERSION}"
            fi
            echo "  ${GREEN}Bundle ID:${NC} ${APP_BUNDLE_ID}"
            echo "  ${GREEN}ボリューム名:${NC} ${APP_VOLUME_NAME}"
            echo "  ${GREEN}作成先:${NC} ${SELECTED_DISK}"
            echo ""
            
            if [[ "$BATCH_MODE" == true ]]; then
                echo -n "残り ${TOTAL_IPAS} 個のアプリのボリュームを作成しますか？ (Y/n): "
            else
                echo -n "このボリュームを作成しますか？ (Y/n): "
            fi
            
            read create_choice
            
            if [[ "$create_choice" =~ ^[Nn] ]]; then
                print_info "ボリューム作成をキャンセルしました"
                return 1
            fi
        fi
        
        print_info "ボリューム「${APP_VOLUME_NAME}」を作成中..."
        
        # Create volume WITH -nomount to prevent auto-mounting to /Volumes/
        if sudo diskutil apfs addVolume "$SELECTED_DISK" APFS "${APP_VOLUME_NAME}" -nomount > /tmp/apfs_create_app.log 2>&1; then
            print_success "ボリュームを作成しました"
            
            # Wait a moment for the system to register the new volume
            sleep 1
            
            # Get the newly created volume device - try multiple methods
            local new_volume=""
            
            # Method 1: Use diskutil info with volume name (most reliable)
            new_volume=$(diskutil info "${APP_VOLUME_NAME}" 2>/dev/null | grep "Device Node:" | awk '{print $NF}' | sed 's|/dev/||')
            if [[ -n "$new_volume" ]]; then
                print_info "新規ボリュームデバイス: /dev/${new_volume} (diskutil info から検出)"
            fi
            
            # Method 2: Check if mounted at /Volumes/
            if [[ -z "$new_volume" ]] && [[ -d "/Volumes/${APP_VOLUME_NAME}" ]]; then
                new_volume=$(diskutil info "/Volumes/${APP_VOLUME_NAME}" 2>/dev/null | grep "Device Node:" | awk '{print $NF}' | sed 's|/dev/||')
                if [[ -n "$new_volume" ]]; then
                    print_info "新規ボリュームデバイス: /dev/${new_volume} (/Volumes から検出)"
                fi
            fi
            
            # Method 3: Search in diskutil list
            if [[ -z "$new_volume" ]]; then
                new_volume=$(diskutil list 2>/dev/null | grep "${APP_VOLUME_NAME}" | grep "APFS" | head -n 1 | awk '{print $NF}')
                if [[ -n "$new_volume" ]]; then
                    print_info "新規ボリュームデバイス: /dev/${new_volume} (diskutil list から検出)"
                fi
            fi
            
            # Method 4: Search in specific container
            if [[ -z "$new_volume" ]]; then
                new_volume=$(diskutil list "${SELECTED_DISK}" 2>/dev/null | grep "${APP_VOLUME_NAME}" | head -n 1 | awk '{print $NF}')
                if [[ -n "$new_volume" ]]; then
                    print_info "新規ボリュームデバイス: /dev/${new_volume} (コンテナから検出)"
                fi
            fi
            
            # Method 5: Search in diskutil apfs list
            if [[ -z "$new_volume" ]]; then
                new_volume=$(diskutil apfs list 2>/dev/null | grep -B 5 "${APP_VOLUME_NAME}" | grep "APFS Volume Disk" | head -n 1 | grep -oE 'disk[0-9]+s[0-9]+')
                if [[ -n "$new_volume" ]]; then
                    print_info "新規ボリュームデバイス: /dev/${new_volume} (APFS list から検出)"
                fi
            fi
            
            if [[ -n "$new_volume" ]]; then
                # Verify the new volume
                if diskutil info "/dev/${new_volume}" 2>/dev/null | grep -q "File System Personality.*APFS"; then
                    print_success "ボリュームの検証: OK"
                else
                    print_error "ボリュームの検証: 失敗"
                    return 1
                fi
                
                # Unmount the auto-mounted volume
                sudo diskutil unmount "/dev/${new_volume}" 2>/dev/null || true
            else
                print_error "作成したボリュームが見つかりません"
                echo ""
                print_info "デバッグ情報:"
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                echo "ボリューム名: ${APP_VOLUME_NAME}"
                echo "対象コンテナ: ${SELECTED_DISK}"
                echo ""
                print_info "/Volumes/ の確認:"
                ls -la /Volumes/ | grep -i "$(echo ${APP_VOLUME_NAME} | cut -c1-10)" || echo "  (見つかりません)"
                echo ""
                print_info "diskutil list の出力:"
                diskutil list 2>/dev/null | grep -i "$(echo ${APP_VOLUME_NAME} | cut -c1-10)" || echo "  (見つかりません)"
                echo ""
                print_info "作成ログ:"
                cat /tmp/apfs_create_app.log
                echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                return 1
            fi
        else
            print_error "ボリュームの作成に失敗しました"
            cat /tmp/apfs_create_app.log
            return 1
        fi
    fi
    
    echo ""
    return 0
}

#######################################################
# 10. Mount App Volume with Data Handling
#######################################################

mount_app_volume() {
    print_header "10. アプリボリュームのマウント"
    
    local app_container="${HOME}/Library/Containers/${APP_BUNDLE_ID}"
    
    # Try multiple methods to find the volume device
    local volume_device=""
    
    # Method 1: Use diskutil info with volume name (most reliable, same as 0_playcover-initial-setup)
    volume_device=$(diskutil info "${APP_VOLUME_NAME}" 2>/dev/null | grep "Device Node:" | awk '{print $NF}' | sed 's|/dev/||')
    
    if [[ -n "$volume_device" ]]; then
        print_info "ボリュームを発見: ${APP_VOLUME_NAME}"
    fi
    
    # Method 2: Check if volume is mounted at /Volumes/ and get device from there
    if [[ -z "$volume_device" ]] && [[ -d "/Volumes/${APP_VOLUME_NAME}" ]]; then
        print_info "ボリュームは /Volumes/${APP_VOLUME_NAME} にマウントされています"
        volume_device=$(diskutil info "/Volumes/${APP_VOLUME_NAME}" 2>/dev/null | grep "Device Node:" | awk '{print $NF}' | sed 's|/dev/||')
        if [[ -n "$volume_device" ]]; then
            print_info "デバイスノードを取得: ${volume_device}"
        fi
    fi
    
    # Method 3: Search by volume name in diskutil list
    if [[ -z "$volume_device" ]]; then
        volume_device=$(diskutil list 2>/dev/null | grep -E "${APP_VOLUME_NAME}" | grep "APFS" | head -n 1 | awk '{print $NF}')
    fi
    
    # Method 4: Search in the specific container
    if [[ -z "$volume_device" ]]; then
        print_info "コンテナ内でボリュームを検索中..."
        volume_device=$(diskutil list "${SELECTED_DISK}" 2>/dev/null | grep "${APP_VOLUME_NAME}" | head -n 1 | awk '{print $NF}')
    fi
    
    # Method 5: Use diskutil apfs list to find volumes in container
    if [[ -z "$volume_device" ]]; then
        print_info "コンテナのボリューム一覧から検索中..."
        # Get all volumes in the container
        local container_volumes=$(diskutil apfs list "${SELECTED_DISK}" 2>/dev/null | grep -E "APFS Volume.*${APP_VOLUME_NAME}" -A 2 | grep "disk" | head -n 1)
        if [[ -n "$container_volumes" ]]; then
            volume_device=$(echo "$container_volumes" | grep -oE 'disk[0-9]+s[0-9]+' | head -n 1)
        fi
    fi
    
    # Method 6: Search all APFS volumes
    if [[ -z "$volume_device" ]]; then
        print_info "全 APFS ボリュームから検索中..."
        volume_device=$(diskutil apfs list 2>/dev/null | grep -B 5 "${APP_VOLUME_NAME}" | grep "APFS Volume Disk" | head -n 1 | grep -oE 'disk[0-9]+s[0-9]+')
    fi
    
    if [[ -z "$volume_device" ]]; then
        print_error "ボリュームデバイスが見つかりません"
        echo ""
        print_info "デバッグ情報:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "検索したボリューム名: ${APP_VOLUME_NAME}"
        echo "対象コンテナ: ${SELECTED_DISK}"
        echo ""
        print_info "diskutil list の出力:"
        diskutil list 2>/dev/null | grep -i "${APP_VOLUME_NAME}" || echo "  (見つかりませんでした)"
        echo ""
        print_info "コンテナのボリューム一覧:"
        diskutil list "${SELECTED_DISK}" 2>/dev/null || echo "  (コンテナ情報の取得に失敗)"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        return 1
    fi
    
    volume_device="/dev/${volume_device}"
    print_info "ボリュームデバイス: ${volume_device}"
    
    # Check if volume is already mounted elsewhere
    local current_mount=$(mount | grep "$volume_device" | awk '{print $3}')
    if [[ -n "$current_mount" ]]; then
        if [[ "$current_mount" == "$app_container" ]]; then
            print_success "ボリュームは既に正しい場所にマウントされています"
            echo ""
            return 0
        else
            print_warning "ボリュームが他の場所にマウントされています: ${current_mount}"
            print_info "既存のマウントをアンマウント中..."
            sudo umount "$current_mount" 2>/dev/null || {
                print_error "アンマウントに失敗しました"
                return 1
            }
        fi
    fi
    
    # Check if internal container exists
    local internal_exists=false
    if [[ -d "$app_container" ]] && [[ ! $(mount | grep " on ${app_container} ") ]]; then
        internal_exists=true
    fi
    
    # Check if external volume has data
    local external_has_data=false
    local temp_mount=$(mktemp -d)
    if sudo mount -t apfs -o nobrowse "$volume_device" "$temp_mount" 2>/dev/null; then
        if [[ -n "$(ls -A "$temp_mount" 2>/dev/null)" ]]; then
            external_has_data=true
        fi
        sudo umount "$temp_mount" 2>/dev/null || true
    fi
    rmdir "$temp_mount" 2>/dev/null || true
    
    # Handle data conflict
    if $internal_exists && $external_has_data; then
        print_warning "内部ストレージと外部ストレージの両方にデータが存在します"
        
        # In batch mode, prefer internal data by default
        if [[ "$BATCH_MODE" == true ]]; then
            print_info "内部ストレージのデータを自動選択して外部にコピーします..."
            local data_choice=1
        else
            echo ""
            echo "どちらのデータを使用しますか？"
            echo "  1) 内部ストレージのデータを使用（外部を上書き）"
            echo "  2) 外部ストレージのデータを使用（内部を削除）"
            echo ""
            echo -n "選択してください (1/2): "
            read data_choice
        fi
        
        case $data_choice in
            1)
                print_info "内部ストレージのデータを外部にコピーします..."
                
                # Mount external volume temporarily
                local temp_mount=$(mktemp -d)
                if sudo mount -t apfs -o nobrowse "$volume_device" "$temp_mount"; then
                    # Clear external data
                    sudo rm -rf "$temp_mount"/* 2>/dev/null || true
                    
                    # Copy internal data to external
                    if sudo cp -a "$app_container"/* "$temp_mount"/ 2>/dev/null; then
                        print_success "データのコピーが完了しました"
                    else
                        print_warning "データのコピーに失敗しました（空のコンテナの可能性）"
                    fi
                    
                    sudo umount "$temp_mount"
                    rmdir "$temp_mount" 2>/dev/null || true
                else
                    rmdir "$temp_mount" 2>/dev/null || true
                fi
                
                # Remove internal container
                print_info "内部ストレージのコンテナを削除中..."
                sudo rm -rf "$app_container"
                ;;
            2)
                print_info "内部ストレージのコンテナを削除します..."
                sudo rm -rf "$app_container"
                print_success "内部ストレージのデータを削除しました"
                ;;
            *)
                print_error "無効な選択です"
                return 1
                ;;
        esac
        
        # IMPORTANT: Unmount the volume if it's still mounted from data check
        local current_temp_mount=$(diskutil info "$volume_device" 2>/dev/null | grep "Mount Point:" | sed 's/.*: *//')
        if [[ -n "$current_temp_mount" ]] && [[ "$current_temp_mount" != "Not applicable (no file system)" ]]; then
            print_info "一時マウントをアンマウント中: ${current_temp_mount}"
            sudo umount "$current_temp_mount" 2>/dev/null || sudo diskutil unmount force "$volume_device" 2>/dev/null || true
            sleep 1  # Wait for unmount to complete
        fi
    elif $internal_exists; then
        # Only internal data exists
        print_info "内部ストレージのデータを外部にコピーします..."
        
        local temp_mount=$(mktemp -d)
        if sudo mount -t apfs -o nobrowse "$volume_device" "$temp_mount"; then
            if sudo cp -a "$app_container"/* "$temp_mount"/ 2>/dev/null; then
                print_success "データのコピーが完了しました"
            else
                print_warning "データのコピーに失敗しました（空のコンテナの可能性）"
            fi
            sudo umount "$temp_mount"
            rmdir "$temp_mount" 2>/dev/null || true
        else
            rmdir "$temp_mount" 2>/dev/null || true
        fi
        
        # Remove internal container
        sudo rm -rf "$app_container"
        
        # IMPORTANT: Unmount the volume if it's still mounted
        local current_temp_mount=$(diskutil info "$volume_device" 2>/dev/null | grep "Mount Point:" | sed 's/.*: *//')
        if [[ -n "$current_temp_mount" ]] && [[ "$current_temp_mount" != "Not applicable (no file system)" ]]; then
            print_info "一時マウントをアンマウント中: ${current_temp_mount}"
            sudo umount "$current_temp_mount" 2>/dev/null || sudo diskutil unmount force "$volume_device" 2>/dev/null || true
            sleep 1  # Wait for unmount to complete
        fi
    fi
    
    # Mount external volume to container path
    print_info "外部ボリュームをマウント中..."
    
    # Final pre-mount check: ensure volume is not mounted anywhere
    local pre_mount_check=$(diskutil info "$volume_device" 2>/dev/null | grep "Mount Point:" | sed 's/.*: *//')
    if [[ -n "$pre_mount_check" ]] && [[ "$pre_mount_check" != "Not applicable (no file system)" ]]; then
        print_warning "ボリュームがまだマウントされています: ${pre_mount_check}"
        print_info "強制アンマウント中..."
        sudo umount -f "$pre_mount_check" 2>/dev/null || sudo diskutil unmount force "$volume_device" 2>/dev/null || true
        sleep 1
    fi
    
    # Ensure parent directory exists
    sudo mkdir -p "$(dirname "$app_container")" 2>/dev/null || true
    
    # Final check: ensure container path doesn't exist or is empty
    if [[ -e "$app_container" ]]; then
        if [[ -d "$app_container" ]]; then
            print_warning "コンテナディレクトリが残っています: ${app_container}"
            print_info "削除してから再マウントします..."
            sudo rm -rf "$app_container" 2>/dev/null || {
                print_error "コンテナディレクトリの削除に失敗しました"
                return 1
            }
        else
            print_error "コンテナパスがディレクトリではありません: ${app_container}"
            return 1
        fi
    fi
    
    # Create mount point
    sudo mkdir -p "$app_container" 2>/dev/null || {
        print_error "マウントポイントの作成に失敗しました"
        return 1
    }
    
    # Attempt mount with nobrowse option (hide from Finder/Desktop) and detailed error reporting
    print_info "マウントを実行中: ${volume_device} → ${app_container}"
    if sudo mount -t apfs -o nobrowse "$volume_device" "$app_container" 2>&1 | tee /tmp/mount_error.log; then
        print_success "ボリュームを正常にマウントしました"
        print_info "マウント先: ${app_container}"
        
        # Verify mount
        if mount | grep -q " on ${app_container} "; then
            print_success "マウント確認: OK"
            sudo chown -R $(id -u):$(id -g) "$app_container" 2>/dev/null || true
        else
            print_error "マウントコマンドは成功しましたが、実際にはマウントされていません"
            return 1
        fi
    else
        print_error "ボリュームのマウントに失敗しました"
        echo ""
        print_info "エラー詳細:"
        cat /tmp/mount_error.log 2>/dev/null || echo "(エラー情報なし)"
        echo ""
        print_info "デバッグ情報:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "ボリュームデバイス: $volume_device"
        echo "マウント先: $app_container"
        echo ""
        echo "ディスク情報:"
        diskutil info "$volume_device" 2>/dev/null | grep -E "(Volume Name|File System|Owners|Bootable|Encrypted)" || echo "(情報取得失敗)"
        echo ""
        echo "現在のマウント状態:"
        mount | grep -i "$(basename ${volume_device})" || echo "(マウントなし)"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        return 1
    fi
    
    echo ""
    return 0
}

#######################################################
# 11. Register Mapping Data
#######################################################

register_mapping() {
    print_header "11. マッピングデータの登録"
    
    # Format: VolumeName	BundleID	DisplayName(Japanese/English)
    local mapping_entry="${APP_VOLUME_NAME}	${APP_BUNDLE_ID}	${APP_NAME}"
    
    # Check for duplicate (by volume name and bundle ID)
    if grep -q "^${APP_VOLUME_NAME}[[:space:]]${APP_BUNDLE_ID}[[:space:]]" "$MAPPING_FILE" 2>/dev/null; then
        print_warning "マッピングは既に登録されています"
        # Update the display name in case it changed
        sed -i.bak "s|^${APP_VOLUME_NAME}[[:space:]]${APP_BUNDLE_ID}[[:space:]].*|${mapping_entry}|" "$MAPPING_FILE" 2>/dev/null
        print_info "表示名を更新しました: ${APP_NAME}"
    else
        echo "$mapping_entry" >> "$MAPPING_FILE"
        print_success "マッピングデータを登録しました"
        print_info "ボリューム: ${APP_VOLUME_NAME}"
        print_info "Bundle ID: ${APP_BUNDLE_ID}"
        print_info "表示名: ${APP_NAME}"
    fi
    
    echo ""
    return 0
}

#######################################################
# 12. Install IPA to PlayCover
#######################################################

install_ipa_to_playcover() {
    local ipa_file=$1
    print_header "12. PlayCover への IPA インストール"
    
    # Check if app is already installed - correct path
    local playcover_apps="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/Applications"
    
    print_info "既存アプリを検索中..."
    
    if [[ -d "$playcover_apps" ]]; then
        # Find app by Bundle ID
        local existing_app_path=""
        local existing_app_version=""
        local existing_app_name=""
        
        # Search for app with matching Bundle ID
        while IFS= read -r app_path; do
            if [[ -f "${app_path}/Info.plist" ]]; then
                local bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "${app_path}/Info.plist" 2>/dev/null)
                
                if [[ "$bundle_id" == "$APP_BUNDLE_ID" ]]; then
                    existing_app_path="$app_path"
                    existing_app_version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${app_path}/Info.plist" 2>/dev/null)
                    if [[ -z "$existing_app_version" ]]; then
                        existing_app_version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "${app_path}/Info.plist" 2>/dev/null)
                    fi
                    existing_app_name=$(/usr/libexec/PlistBuddy -c "Print :CFBundleDisplayName" "${app_path}/Info.plist" 2>/dev/null)
                    if [[ -z "$existing_app_name" ]]; then
                        existing_app_name=$(/usr/libexec/PlistBuddy -c "Print :CFBundleName" "${app_path}/Info.plist" 2>/dev/null)
                    fi
                    print_success "一致するアプリを発見しました"
                    break
                fi
            fi
        done < <(find "$playcover_apps" -maxdepth 1 -type d -name "*.app" 2>/dev/null)
        
        if [[ -n "$existing_app_path" ]]; then
            print_warning "アプリは既にインストールされています"
            
            # In batch mode, auto-update without prompting
            if [[ "$BATCH_MODE" == true ]]; then
                print_info "既存のアプリを自動で上書きします"
            else
                echo ""
                echo "  ${YELLOW}インストール済み:${NC}"
                echo "    アプリ名: ${existing_app_name}"
                if [[ -n "$existing_app_version" ]]; then
                    echo "    バージョン: ${existing_app_version}"
                fi
                echo ""
                echo "  ${GREEN}インストール予定:${NC}"
                echo "    アプリ名: ${APP_NAME}"
                if [[ -n "$APP_VERSION" ]]; then
                    echo "    バージョン: ${APP_VERSION}"
                fi
                echo ""
                echo -n "上書き（アップデート）しますか？ (Y/n): "
                read update_choice
                
                if [[ "$update_choice" =~ ^[Nn] ]]; then
                    print_info "インストールをスキップしました"
                    return 1
                fi
            fi
            
            print_info "既存のアプリを上書きします"
        else
            print_info "既存アプリは見つかりませんでした（新規インストール）"
        fi
    else
        print_info "PlayChain ディレクトリが見つかりません（新規インストール）"
    fi
    
    # Use PlayCover CLI or open with PlayCover
    print_info "PlayCover でインストールを開始します..."
    
    # Open IPA with PlayCover
    if open -a PlayCover "$ipa_file"; then
        print_success "PlayCover でインストールを開始しました"
        if [[ "$BATCH_MODE" != true ]]; then
            print_info "PlayCover のウィンドウでインストールを確認してください"
        fi
    else
        print_error "PlayCover の起動に失敗しました"
        return 1
    fi
    
    echo ""
    return 0
}

#######################################################
# Process Single IPA
#######################################################

process_single_ipa() {
    local ipa_file=$1
    local ipa_index=$2
    
    # Show batch progress
    if [[ "$BATCH_MODE" == true ]]; then
        print_batch_progress "$ipa_index" "$TOTAL_IPAS" "$(basename "$ipa_file")"
    fi
    
    # Extract IPA info
    if ! extract_ipa_info "$ipa_file"; then
        print_error "IPA 情報の取得に失敗しました: $(basename "$ipa_file")"
        INSTALL_FAILED+=("$(basename "$ipa_file") - 情報取得失敗")
        return 1
    fi
    
    # Select installation disk (only show header for first IPA in batch mode)
    if ! select_installation_disk; then
        print_error "インストール先ディスクの選択に失敗しました"
        INSTALL_FAILED+=("${APP_NAME} - ディスク選択失敗")
        return 1
    fi
    
    # Create app volume
    if ! create_app_volume; then
        print_error "ボリューム作成に失敗しました: ${APP_NAME}"
        INSTALL_FAILED+=("${APP_NAME} - ボリューム作成失敗")
        return 1
    fi
    
    # Mount app volume
    if ! mount_app_volume; then
        print_error "ボリュームマウントに失敗しました: ${APP_NAME}"
        INSTALL_FAILED+=("${APP_NAME} - マウント失敗")
        return 1
    fi
    
    # Register mapping
    if ! register_mapping; then
        print_error "マッピング登録に失敗しました: ${APP_NAME}"
        INSTALL_FAILED+=("${APP_NAME} - マッピング登録失敗")
        return 1
    fi
    
    # Install IPA to PlayCover
    if ! install_ipa_to_playcover "$ipa_file"; then
        print_error "PlayCover へのインストール起動に失敗しました: ${APP_NAME}"
        INSTALL_FAILED+=("${APP_NAME} - インストール失敗")
        return 1
    fi
    
    # Success
    INSTALL_SUCCESS+=("${APP_NAME}")
    
    # Add delay between batch installations to avoid conflicts
    if [[ "$BATCH_MODE" == true ]] && [[ $ipa_index -lt $TOTAL_IPAS ]]; then
        print_info "次の IPA 処理まで 3 秒待機します..."
        sleep 3
    fi
    
    return 0
}

#######################################################
# 13. Completion Summary
#######################################################

show_batch_summary() {
    echo ""
    echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "${CYAN}  一括インストール完了${NC}"
    echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    local success_count=${#INSTALL_SUCCESS[@]}
    local failed_count=${#INSTALL_FAILED[@]}
    
    echo "  ${GREEN}処理完了:${NC} ${success_count}/${TOTAL_IPAS}"
    echo "  ${RED}処理失敗:${NC} ${failed_count}/${TOTAL_IPAS}"
    echo ""
    
    if [[ $success_count -gt 0 ]]; then
        echo "${GREEN}✓ 成功したアプリ:${NC}"
        for app in "${INSTALL_SUCCESS[@]}"; do
            echo "  - ${app}"
        done
        echo ""
    fi
    
    if [[ $failed_count -gt 0 ]]; then
        echo "${RED}✗ 失敗したアプリ:${NC}"
        for app in "${INSTALL_FAILED[@]}"; do
            echo "  - ${app}"
        done
        echo ""
    fi
    
    if [[ $failed_count -eq 0 ]]; then
        print_success "すべてのアプリのセットアップが完了しました"
    else
        print_warning "一部のアプリのセットアップに失敗しました"
    fi
    
    echo ""
    print_info "PlayCover のウィンドウで各アプリのインストールを確認してください"
}

complete_installation() {
    if [[ "$BATCH_MODE" == true ]]; then
        show_batch_summary
        
        local failed_count=${#INSTALL_FAILED[@]}
        if [[ $failed_count -eq 0 ]]; then
            exit_with_cleanup 0 "一括インストール完了"
        else
            exit_with_cleanup 1 "一部のアプリのインストールに失敗しました"
        fi
    else
        print_header "インストール完了"
        
        print_success "すべての処理が正常に完了しました"
        echo ""
        print_info "アプリ情報:"
        echo "  アプリ名: ${APP_NAME}"
        if [[ -n "$APP_VERSION" ]]; then
            echo "  バージョン: ${APP_VERSION}"
        fi
        echo "  Bundle ID: ${APP_BUNDLE_ID}"
        echo "  ボリューム名: ${APP_VOLUME_NAME}"
        echo "  マウント先: ${HOME}/Library/Containers/${APP_BUNDLE_ID}"
        echo ""
        
        exit_with_cleanup 0 "インストール完了"
    fi
}

#######################################################
# Main Execution
#######################################################

show_title() {
    clear
    
    echo "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                                                           ║"
    echo "║      ${GREEN}PlayCover IPA インストール（一括対応）${CYAN}          ║"
    echo "║                                                           ║"
    echo "║              ${BLUE}macOS Tahoe 26.0.1 対応版${CYAN}                    ║"
    echo "║              ${MAGENTA}Version 2.0.0 - Batch Mode${CYAN}                   ║"
    echo "║                                                           ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo "${NC}"
    echo ""
}

main() {
    show_title
    
    # Pre-flight checks
    check_playcover_app
    check_playcover_mapping
    check_full_disk_access
    authenticate_sudo
    check_playcover_volume_mount
    
    # Select IPA files (single or multiple)
    select_ipa_files
    
    # Process each IPA
    CURRENT_IPA_INDEX=0
    for ipa_file in "${SELECTED_IPAS[@]}"; do
        ((CURRENT_IPA_INDEX++))
        
        # Process single IPA (errors are captured in INSTALL_FAILED array)
        process_single_ipa "$ipa_file" "$CURRENT_IPA_INDEX" || {
            print_warning "IPA 処理でエラーが発生しましたが、次のファイルを続行します"
            echo ""
        }
    done
    
    # Show completion summary
    complete_installation
}

# Trap Ctrl+C
trap 'exit_with_cleanup 130 "ユーザーによる中断"' INT

# Execute main
main
