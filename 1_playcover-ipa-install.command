#!/bin/zsh

#######################################################
# PlayCover IPA Installation Script
# macOS Tahoe 26.0.1 Compatible
#######################################################

set -e

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Constants
readonly PLAYCOVER_BUNDLE_ID="io.playcover.PlayCover"
readonly PLAYCOVER_CONTAINER="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}"
readonly PLAYCOVER_VOLUME_NAME="PlayCover"
readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly MAPPING_FILE="${SCRIPT_DIR}/playcover-map.txt"
readonly INITIAL_SETUP_SCRIPT="${SCRIPT_DIR}/0_playcover-initial-setup.command"

# Global variables
SELECTED_IPA=""
APP_NAME=""
APP_BUNDLE_ID=""
APP_VOLUME_NAME=""
SELECTED_DISK=""
PLAYCOVER_VOLUME_DEVICE=""
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

exit_with_cleanup() {
    local exit_code=$1
    local message=$2
    
    echo ""
    if [[ $exit_code -eq 0 ]]; then
        print_success "$message"
        echo ""
        print_info "5秒後にターミナルを閉じます..."
        sleep 5
        osascript -e 'tell application "Terminal" to close first window' 2>/dev/null || true
    else
        print_error "$message"
        echo ""
        print_info "5秒後にターミナルを閉じます..."
        sleep 5
        osascript -e 'tell application "Terminal" to close first window' 2>/dev/null || true
    fi
    exit $exit_code
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
    
    # Mount to container path
    print_info "PlayCover ボリュームをマウント中..."
    if sudo mount -t apfs "$PLAYCOVER_VOLUME_DEVICE" "$PLAYCOVER_CONTAINER"; then
        print_success "ボリュームを正常にマウントしました"
        sudo chown -R $(id -u):$(id -g) "$PLAYCOVER_CONTAINER" 2>/dev/null || true
    else
        print_error "ボリュームのマウントに失敗しました"
        exit_with_cleanup 1 "ボリュームマウントエラー"
    fi
}

#######################################################
# 06. IPA Selection
#######################################################

select_ipa_file() {
    print_header "06. インストールする IPA ファイルの選択"
    
    # Use AppleScript to select IPA file
    # Try multiple type identifiers for IPA files
    local selected=$(osascript <<'EOF' 2>/dev/null
try
    tell application "System Events"
        activate
        -- Try with multiple type identifiers
        set theFile to choose file with prompt "インストールする IPA ファイルを選択してください:" of type {"ipa", "public.archive", "public.data"}
        return POSIX path of theFile
    end tell
on error
    -- Fallback: allow all files
    tell application "System Events"
        activate
        set theFile to choose file with prompt "インストールする IPA ファイルを選択してください (.ipa):"
        set filePath to POSIX path of theFile
        if filePath does not end with ".ipa" then
            error "選択されたファイルは IPA ファイルではありません"
        end if
        return filePath
    end tell
end try
EOF
)
    
    if [[ -z "$selected" ]] || [[ ! -f "$selected" ]]; then
        print_error "IPA ファイルが選択されませんでした"
        exit_with_cleanup 1 "IPA ファイル未選択"
    fi
    
    # Verify file extension
    if [[ ! "$selected" =~ \.ipa$ ]]; then
        print_error "選択されたファイルは IPA ファイルではありません"
        print_error "ファイル: ${selected}"
        exit_with_cleanup 1 "無効なファイル形式"
    fi
    
    SELECTED_IPA="$selected"
    print_success "IPA ファイルを選択しました"
    print_info "ファイル: ${SELECTED_IPA}"
    
    echo ""
}

#######################################################
# 07. Extract IPA Information
#######################################################

extract_ipa_info() {
    print_header "07. IPA 情報の取得"
    
    # Create temporary directory for extraction
    local temp_dir=$(mktemp -d)
    
    print_info "IPA ファイルを解析中..."
    
    # Extract IPA (it's just a zip file)
    if ! unzip -q "$SELECTED_IPA" -d "$temp_dir" 2>/dev/null; then
        print_error "IPA ファイルの解凍に失敗しました"
        rm -rf "$temp_dir"
        exit_with_cleanup 1 "IPA 解凍エラー"
    fi
    
    # Find Info.plist
    local info_plist=$(find "$temp_dir" -name "Info.plist" -path "*/Payload/*.app/Info.plist" | head -n 1)
    
    if [[ -z "$info_plist" ]]; then
        print_error "Info.plist が見つかりません"
        rm -rf "$temp_dir"
        exit_with_cleanup 1 "Info.plist 不在"
    fi
    
    # Extract Bundle Identifier
    APP_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$info_plist" 2>/dev/null)
    
    if [[ -z "$APP_BUNDLE_ID" ]]; then
        print_error "Bundle Identifier の取得に失敗しました"
        rm -rf "$temp_dir"
        exit_with_cleanup 1 "Bundle ID 取得エラー"
    fi
    
    # Extract App Name (CFBundleDisplayName or CFBundleName)
    APP_NAME=$(/usr/libexec/PlistBuddy -c "Print :CFBundleDisplayName" "$info_plist" 2>/dev/null)
    
    if [[ -z "$APP_NAME" ]]; then
        APP_NAME=$(/usr/libexec/PlistBuddy -c "Print :CFBundleName" "$info_plist" 2>/dev/null)
    fi
    
    if [[ -z "$APP_NAME" ]]; then
        print_error "アプリ名の取得に失敗しました"
        rm -rf "$temp_dir"
        exit_with_cleanup 1 "アプリ名取得エラー"
    fi
    
    # Clean up app name (remove spaces and symbols, keep only alphanumeric)
    APP_VOLUME_NAME=$(echo "$APP_NAME" | iconv -f UTF-8 -t ASCII//TRANSLIT 2>/dev/null | sed 's/[^a-zA-Z0-9]//g' || echo "$APP_NAME" | sed 's/[^a-zA-Z0-9]//g')
    
    # Cleanup
    rm -rf "$temp_dir"
    
    print_success "IPA 情報を取得しました"
    print_info "アプリ名: ${APP_NAME}"
    print_info "Bundle ID: ${APP_BUNDLE_ID}"
    print_info "ボリューム名: ${APP_VOLUME_NAME}"
    
    echo ""
}

#######################################################
# 08. Select Installation Destination
#######################################################

select_installation_disk() {
    print_header "08. インストール先ディスクの選択"
    
    # Find disk where PlayCover volume is located
    local playcover_disk=""
    
    if [[ -n "$PLAYCOVER_VOLUME_DEVICE" ]]; then
        # Extract disk number from volume device (e.g., /dev/disk5s1 -> disk5)
        playcover_disk=$(echo "$PLAYCOVER_VOLUME_DEVICE" | sed -E 's|/dev/(disk[0-9]+).*|\1|')
        
        print_info "PlayCover ボリュームが存在するディスク: ${playcover_disk}"
        print_info "PlayCover ボリュームデバイス: ${PLAYCOVER_VOLUME_DEVICE}"
        
        # Find APFS container for this disk
        local container=$(find_apfs_container "${playcover_disk}")
        
        if [[ -n "$container" ]]; then
            SELECTED_DISK="$container"
            print_success "インストール先を自動選択しました: ${SELECTED_DISK}"
        else
            print_error "APFS コンテナの検出に失敗しました"
            print_info "デバッグ: diskutil list の出力を確認中..."
            diskutil list | grep -A 5 "$playcover_disk"
            echo ""
            print_info "デバッグ: diskutil info の出力を確認中..."
            diskutil info "$PLAYCOVER_VOLUME_DEVICE" | grep -E "(Container|Type|APFS)"
            exit_with_cleanup 1 "APFS コンテナ検出エラー"
        fi
    else
        print_error "PlayCover ボリュームのデバイス情報が見つかりません"
        exit_with_cleanup 1 "デバイス情報不在"
    fi
    
    echo ""
}

find_apfs_container() {
    local physical_disk=$1
    local container=""
    
    # Extract disk number (e.g., /dev/disk5 -> 5, disk5 -> 5)
    local disk_num=$(echo "$physical_disk" | sed -E 's|.*/disk([0-9]+).*|\1|')
    
    # Method 1: Check if the disk itself is already a container (synthesized)
    local disk_type=$(diskutil info "$physical_disk" 2>/dev/null | grep "Type (Bundle)")
    if [[ "$disk_type" =~ "apfs" ]]; then
        # This is already an APFS container
        container=$(echo "$physical_disk" | sed -E 's|/dev/||' | sed -E 's|s[0-9]+$||')
        echo "$container"
        return 0
    fi
    
    # Method 2: Look for synthesized disk with same base number
    while IFS= read -r line; do
        if [[ "$line" =~ /dev/(disk${disk_num})[[:space:]] ]]; then
            local found_disk=$(echo "$line" | grep -oE 'disk[0-9]+' | head -n 1)
            local disk_info=$(diskutil info "/dev/$found_disk" 2>/dev/null)
            if echo "$disk_info" | grep -q "synthesized"; then
                container="$found_disk"
                break
            fi
        fi
    done < <(diskutil list)
    
    # Method 3: Use diskutil apfs list to find container
    if [[ -z "$container" ]]; then
        while IFS= read -r line; do
            if [[ "$line" =~ "APFS Container" ]]; then
                local found_container=$(echo "$line" | grep -oE 'disk[0-9]+')
                if [[ -n "$found_container" ]]; then
                    local container_info=$(diskutil info "$found_container" 2>/dev/null)
                    # Check if this container is on the same physical disk
                    if echo "$container_info" | grep -q "disk${disk_num}"; then
                        container="$found_container"
                        break
                    fi
                fi
            fi
        done < <(diskutil apfs list)
    fi
    
    echo "$container"
}

#######################################################
# 09. Create App Volume
#######################################################

create_app_volume() {
    print_header "09. アプリボリュームの作成"
    
    # Check if volume already exists
    if diskutil list | grep -q "${APP_VOLUME_NAME}"; then
        print_warning "ボリューム「${APP_VOLUME_NAME}」は既に存在します"
        print_info "既存のボリュームを使用します"
    else
        print_info "ボリューム「${APP_VOLUME_NAME}」を作成中..."
        
        if sudo diskutil apfs addVolume "$SELECTED_DISK" APFS "${APP_VOLUME_NAME}" -nomount > /tmp/apfs_create_app.log 2>&1; then
            print_success "ボリュームを作成しました"
        else
            print_error "ボリュームの作成に失敗しました"
            cat /tmp/apfs_create_app.log
            exit_with_cleanup 1 "ボリューム作成エラー"
        fi
    fi
    
    echo ""
}

#######################################################
# 10. Mount App Volume with Data Handling
#######################################################

mount_app_volume() {
    print_header "10. アプリボリュームのマウント"
    
    local app_container="${HOME}/Library/Containers/${APP_BUNDLE_ID}"
    local volume_device=$(diskutil list | grep -E "${APP_VOLUME_NAME}.*APFS" | head -n 1 | awk '{print $NF}')
    
    if [[ -z "$volume_device" ]]; then
        print_error "ボリュームデバイスが見つかりません"
        exit_with_cleanup 1 "ボリュームデバイス不在"
    fi
    
    volume_device="/dev/${volume_device}"
    print_info "ボリュームデバイス: ${volume_device}"
    
    # Check if internal container exists
    local internal_exists=false
    if [[ -d "$app_container" ]] && [[ ! $(mount | grep " on ${app_container} ") ]]; then
        internal_exists=true
    fi
    
    # Check if external volume has data
    local external_has_data=false
    local temp_mount=$(mktemp -d)
    if sudo mount -t apfs "$volume_device" "$temp_mount" 2>/dev/null; then
        if [[ -n "$(ls -A "$temp_mount" 2>/dev/null)" ]]; then
            external_has_data=true
        fi
        sudo umount "$temp_mount" 2>/dev/null || true
    fi
    rmdir "$temp_mount" 2>/dev/null || true
    
    # Handle data conflict
    if $internal_exists && $external_has_data; then
        print_warning "内部ストレージと外部ストレージの両方にデータが存在します"
        echo ""
        echo "どちらのデータを使用しますか？"
        echo "  1) 内部ストレージのデータを使用（外部を上書き）"
        echo "  2) 外部ストレージのデータを使用（内部を削除）"
        echo ""
        echo -n "選択してください (1/2): "
        read data_choice
        
        case $data_choice in
            1)
                print_info "内部ストレージのデータを外部にコピーします..."
                
                # Mount external volume temporarily
                local temp_mount=$(mktemp -d)
                if sudo mount -t apfs "$volume_device" "$temp_mount"; then
                    # Clear external data
                    sudo rm -rf "$temp_mount"/* 2>/dev/null || true
                    
                    # Copy internal data to external
                    if sudo cp -a "$app_container"/* "$temp_mount"/ 2>/dev/null; then
                        print_success "データのコピーが完了しました"
                    else
                        print_warning "データのコピーに失敗しました（空のコンテナの可能性）"
                    fi
                    
                    sudo umount "$temp_mount"
                fi
                rmdir "$temp_mount" 2>/dev/null || true
                
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
                exit_with_cleanup 1 "無効な選択"
                ;;
        esac
    elif $internal_exists; then
        # Only internal data exists
        print_info "内部ストレージのデータを外部にコピーします..."
        
        local temp_mount=$(mktemp -d)
        if sudo mount -t apfs "$volume_device" "$temp_mount"; then
            if sudo cp -a "$app_container"/* "$temp_mount"/ 2>/dev/null; then
                print_success "データのコピーが完了しました"
            else
                print_warning "データのコピーに失敗しました（空のコンテナの可能性）"
            fi
            sudo umount "$temp_mount"
        fi
        rmdir "$temp_mount" 2>/dev/null || true
        
        # Remove internal container
        sudo rm -rf "$app_container"
    fi
    
    # Mount external volume to container path
    print_info "外部ボリュームをマウント中..."
    
    # Ensure parent directory exists
    sudo mkdir -p "$(dirname "$app_container")" 2>/dev/null || true
    
    if sudo mount -t apfs "$volume_device" "$app_container"; then
        print_success "ボリュームを正常にマウントしました"
        print_info "マウント先: ${app_container}"
        sudo chown -R $(id -u):$(id -g) "$app_container" 2>/dev/null || true
    else
        print_error "ボリュームのマウントに失敗しました"
        exit_with_cleanup 1 "ボリュームマウントエラー"
    fi
    
    echo ""
}

#######################################################
# 11. Register Mapping Data
#######################################################

register_mapping() {
    print_header "11. マッピングデータの登録"
    
    local mapping_entry="${APP_VOLUME_NAME}	${APP_BUNDLE_ID}"
    
    # Check for duplicate
    if grep -q "^${APP_VOLUME_NAME}[[:space:]]${APP_BUNDLE_ID}$" "$MAPPING_FILE" 2>/dev/null; then
        print_warning "マッピングは既に登録されています"
    else
        echo "$mapping_entry" >> "$MAPPING_FILE"
        print_success "マッピングデータを登録しました"
        print_info "データ: ${mapping_entry}"
    fi
    
    echo ""
}

#######################################################
# 12. Install IPA to PlayCover
#######################################################

install_ipa_to_playcover() {
    print_header "12. PlayCover への IPA インストール"
    
    # Check if app is already installed
    local playcover_apps="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/Data/Library/Application Support/io.playcover.PlayCover/PlayChain"
    
    if [[ -d "$playcover_apps" ]]; then
        local existing_app=$(find "$playcover_apps" -type d -name "*.app" -exec /usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "{}/Info.plist" \; 2>/dev/null | grep -l "$APP_BUNDLE_ID" | head -n 1)
        
        if [[ -n "$existing_app" ]]; then
            print_warning "アプリは既にインストールされています"
            echo ""
            echo -n "上書き（アップデート）しますか？ (Y/n): "
            read update_choice
            
            if [[ "$update_choice" =~ ^[Nn] ]]; then
                print_info "インストールをスキップしました"
                exit_with_cleanup 0 "インストールスキップ"
            fi
        fi
    fi
    
    # Use PlayCover CLI or open with PlayCover
    print_info "PlayCover でインストールを開始します..."
    
    # Open IPA with PlayCover
    if open -a PlayCover "$SELECTED_IPA"; then
        print_success "PlayCover でインストールを開始しました"
        print_info "PlayCover のウィンドウでインストールを確認してください"
    else
        print_error "PlayCover の起動に失敗しました"
        exit_with_cleanup 1 "PlayCover 起動エラー"
    fi
    
    echo ""
}

#######################################################
# 13. Completion
#######################################################

complete_installation() {
    print_header "インストール完了"
    
    print_success "すべての処理が正常に完了しました"
    echo ""
    print_info "アプリ情報:"
    echo "  アプリ名: ${APP_NAME}"
    echo "  Bundle ID: ${APP_BUNDLE_ID}"
    echo "  ボリューム名: ${APP_VOLUME_NAME}"
    echo "  マウント先: ${HOME}/Library/Containers/${APP_BUNDLE_ID}"
    echo ""
    
    exit_with_cleanup 0 "インストール完了"
}

#######################################################
# Main Execution
#######################################################

main() {
    echo ""
    print_header "PlayCover IPA インストールスクリプト"
    echo ""
    
    check_playcover_app
    check_playcover_mapping
    check_full_disk_access
    authenticate_sudo
    check_playcover_volume_mount
    select_ipa_file
    extract_ipa_info
    select_installation_disk
    create_app_volume
    mount_app_volume
    register_mapping
    install_ipa_to_playcover
    complete_installation
}

# Trap Ctrl+C
trap 'exit_with_cleanup 130 "ユーザーによる中断"' INT

# Execute main
main
