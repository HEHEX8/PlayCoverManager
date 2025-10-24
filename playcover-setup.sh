#!/bin/zsh

#######################################################
# PlayCover External Storage Setup Script
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
readonly VOLUME_NAME="PlayCover"
readonly MAPPING_FILE="${HOME}/playcover-map.txt"

# Global variables
SELECTED_DISK=""
NEED_XCODE_TOOLS=false
NEED_HOMEBREW=false
NEED_PLAYCOVER=false
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
# 01. Architecture Check
#######################################################

check_architecture() {
    print_header "01. アーキテクチャの確認"
    
    local arch=$(uname -m)
    
    if [[ "$arch" == "arm64" ]]; then
        print_success "Apple Silicon Mac を検出しました (${arch})"
        return 0
    else
        print_error "このスクリプトはApple Silicon Mac専用です"
        print_error "検出されたアーキテクチャ: ${arch}"
        exit_with_cleanup 1 "互換性のないアーキテクチャ"
    fi
    
    echo ""
}

#######################################################
# 02. Full Disk Access Check
#######################################################

check_full_disk_access() {
    print_header "02. フルディスクアクセスの確認"
    
    # Test access to a protected directory
    if /bin/ls "${HOME}/Library/Mail" >/dev/null 2>&1; then
        print_success "フルディスクアクセス権限が付与されています"
    else
        print_error "フルディスクアクセス権限が必要です"
        echo ""
        print_info "以下の手順で権限を付与してください:"
        echo "  1. システム設定 > プライバシーとセキュリティ > フルディスクアクセス"
        echo "  2. ターミナル.app を追加"
        echo "  3. スクリプトを再実行"
        exit_with_cleanup 1 "フルディスクアクセス権限がありません"
    fi
    
    echo ""
}

#######################################################
# 03. Xcode Command Line Tools Check
#######################################################

check_xcode_tools() {
    print_header "03. Xcode Command Line Tools の確認"
    
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

#######################################################
# 04. Homebrew Check
#######################################################

check_homebrew() {
    print_header "04. Homebrew の確認"
    
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

#######################################################
# 05. PlayCover Check
#######################################################

check_playcover() {
    print_header "05. playcover-community の確認"
    
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

#######################################################
# 06. Sudo Authentication
#######################################################

authenticate_sudo() {
    print_header "06. スーパーユーザー権限の取得"
    
    print_info "管理者パスワードを入力してください"
    if sudo -v; then
        print_success "認証に成功しました"
        SUDO_AUTHENTICATED=true
        
        # Keep sudo alive in background
        (while true; do sudo -n true; sleep 50; done 2>/dev/null) &
        local sudo_pid=$!
        trap "kill $sudo_pid 2>/dev/null" EXIT
    else
        print_error "認証に失敗しました"
        exit_with_cleanup 1 "管理者権限の取得に失敗"
    fi
    
    echo ""
}

#######################################################
# 07. Disk Selection Prompt
#######################################################

select_destination_disk() {
    print_header "07. コンテナボリューム作成先の選択"
    
    # Get root volume's physical disk identifier
    local root_device=$(diskutil info / | grep "Device Node:" | awk '{print $3}')
    local internal_disk=$(echo "$root_device" | sed -E 's/disk([0-9]+).*/disk\1/')
    
    print_info "利用可能な外部ストレージを検索中..."
    echo ""
    
    # List all physical disks (disk0, disk1, disk2, etc. - not partitions)
    local -a external_disks
    local -a disk_info
    local -a seen_disks
    local index=1
    
    # Get unique physical disk identifiers from diskutil list
    while IFS= read -r line; do
        # Match lines like "/dev/disk0 (internal, physical):"
        if [[ "$line" =~ ^/dev/disk[0-9]+ ]]; then
            local disk_id=$(echo "$line" | sed -E 's|^/dev/(disk[0-9]+).*|\1|')
            local full_line="$line"
            
            # Skip if already processed (avoid duplicates)
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
            
            # Only process physical disks (skip synthesized volumes)
            if [[ ! "$full_line" =~ "physical" ]]; then
                continue
            fi
            
            # Check if this is internal storage
            if [[ "$disk_id" == "$internal_disk" ]]; then
                continue
            fi
            
            # Skip if marked as internal
            if [[ "$full_line" =~ "internal" ]]; then
                continue
            fi
            
            # Get disk information
            local device_name=$(diskutil info "/dev/$disk_id" | grep "Device / Media Name:" | sed 's/.*: *//')
            local total_size=$(diskutil info "/dev/$disk_id" | grep "Disk Size:" | sed 's/.*: *//' | awk '{print $1, $2}')
            
            # Skip if couldn't get device name or size
            if [[ -z "$device_name" ]] || [[ -z "$total_size" ]]; then
                continue
            fi
            
            # Check for removable/external property
            local is_removable=$(diskutil info "/dev/$disk_id" | grep "Removable Media:" | grep "Yes")
            local protocol=$(diskutil info "/dev/$disk_id" | grep "Protocol:" | sed 's/.*: *//')
            local location=$(diskutil info "/dev/$disk_id" | grep "Device Location:" | sed 's/.*: *//')
            
            # Include disk if:
            # 1. Marked as removable media, OR
            # 2. Protocol is USB/Thunderbolt/USB4, OR
            # 3. Location is External (excludes internal connections)
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
        exit_with_cleanup 1 "外部ストレージが見つかりません"
    fi
    
    # Display options
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
        exit_with_cleanup 1 "ディスク選択がキャンセルされました"
    fi
    
    echo ""
}

#######################################################
# 08. Installation Confirmation Prompt
#######################################################

confirm_installations() {
    print_header "08. 追加インストール項目の確認"
    
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
            exit_with_cleanup 0 "処理をキャンセルしました"
            ;;
        *)
            print_success "インストールを続行します"
            ;;
    esac
    
    echo ""
}

#######################################################
# 09. Create PlayCover Volume
#######################################################

create_playcover_volume() {
    print_header "09. PlayCover ボリュームの作成"
    
    # Check if volume already exists
    if diskutil info "${VOLUME_NAME}" >/dev/null 2>&1; then
        local existing_volume=$(diskutil info "${VOLUME_NAME}" | grep "Mount Point:" | sed 's/.*: *//')
        print_warning "「${VOLUME_NAME}」ボリュームが既に存在します"
        print_info "既存のボリュームを使用します: ${existing_volume}"
        echo ""
        return 0
    fi
    
    print_info "新しいAPFSボリュームを作成中..."
    
    # Create APFS volume on selected disk
    if sudo diskutil apfs addVolume "$SELECTED_DISK" APFS "${VOLUME_NAME}" -nomount 2>/dev/null; then
        print_success "ボリューム「${VOLUME_NAME}」を作成しました"
    else
        # Try with container identifier
        local container=$(diskutil list "$SELECTED_DISK" | grep "Container" | awk '{print $NF}' | head -n 1)
        if [[ -n "$container" ]]; then
            if sudo diskutil apfs addVolume "$container" APFS "${VOLUME_NAME}" -nomount; then
                print_success "ボリューム「${VOLUME_NAME}」を作成しました"
            else
                print_error "ボリュームの作成に失敗しました"
                exit_with_cleanup 1 "ボリューム作成エラー"
            fi
        else
            print_error "APFSコンテナが見つかりません"
            exit_with_cleanup 1 "ボリューム作成エラー"
        fi
    fi
    
    echo ""
}

#######################################################
# 10. Mount Volume to PlayCover Container
#######################################################

mount_volume_to_container() {
    print_header "10. ボリュームのマウント"
    
    # Get volume device
    local volume_device=$(diskutil info "${VOLUME_NAME}" | grep "Device Node:" | awk '{print $3}')
    
    if [[ -z "$volume_device" ]]; then
        print_error "ボリュームデバイスが見つかりません"
        exit_with_cleanup 1 "ボリュームマウントエラー"
    fi
    
    # Check if container directory exists and has data
    local has_internal_data=false
    local has_external_data=false
    
    if [[ -d "$PLAYCOVER_CONTAINER" ]]; then
        # Check for non-hidden files/directories (excluding .com.apple.* files)
        if [[ $(find "$PLAYCOVER_CONTAINER" -mindepth 1 -maxdepth 1 ! -name ".*" 2>/dev/null | wc -l) -gt 0 ]]; then
            has_internal_data=true
        fi
    fi
    
    # Mount volume temporarily to check contents
    local temp_mount="/tmp/playcover_temp_mount_$$"
    mkdir -p "$temp_mount"
    
    if sudo mount -t apfs "$volume_device" "$temp_mount" 2>/dev/null; then
        if [[ $(find "$temp_mount" -mindepth 1 -maxdepth 1 ! -name ".*" 2>/dev/null | wc -l) -gt 0 ]]; then
            has_external_data=true
        fi
        sudo umount "$temp_mount" 2>/dev/null
    fi
    
    rmdir "$temp_mount" 2>/dev/null
    
    # Handle data conflict
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
                
                # Mount volume temporarily
                mkdir -p "$temp_mount"
                sudo mount -t apfs "$volume_device" "$temp_mount"
                
                # Clear external data
                print_info "外部ストレージをクリア中..."
                sudo rm -rf "$temp_mount"/* "$temp_mount"/.[!.]* 2>/dev/null || true
                
                # Copy internal data to external
                print_info "データをコピー中..."
                sudo cp -R "$PLAYCOVER_CONTAINER"/* "$temp_mount"/ 2>/dev/null || true
                sudo cp -R "$PLAYCOVER_CONTAINER"/.[!.]* "$temp_mount"/ 2>/dev/null || true
                
                # Unmount
                sudo umount "$temp_mount"
                rmdir "$temp_mount"
                
                # Remove internal data
                print_info "内部ストレージをクリア中..."
                sudo rm -rf "$PLAYCOVER_CONTAINER"
                ;;
            2)
                print_info "外部ストレージのデータを使用します"
                
                # Remove internal data
                print_info "内部ストレージをクリア中..."
                sudo rm -rf "$PLAYCOVER_CONTAINER"
                ;;
            *)
                print_error "無効な選択です"
                exit_with_cleanup 1 "処理がキャンセルされました"
                ;;
        esac
    elif $has_internal_data; then
        print_info "内部ストレージのデータを外部に移行します"
        
        # Mount volume temporarily
        mkdir -p "$temp_mount"
        sudo mount -t apfs "$volume_device" "$temp_mount"
        
        # Copy data
        print_info "データをコピー中..."
        sudo cp -R "$PLAYCOVER_CONTAINER"/* "$temp_mount"/ 2>/dev/null || true
        sudo cp -R "$PLAYCOVER_CONTAINER"/.[!.]* "$temp_mount"/ 2>/dev/null || true
        
        # Unmount
        sudo umount "$temp_mount"
        rmdir "$temp_mount"
        
        # Remove internal data
        print_info "内部ストレージをクリア中..."
        sudo rm -rf "$PLAYCOVER_CONTAINER"
    else
        # No data conflict, just remove internal if exists
        if [[ -d "$PLAYCOVER_CONTAINER" ]]; then
            sudo rm -rf "$PLAYCOVER_CONTAINER"
        fi
    fi
    
    # Create mount point
    sudo mkdir -p "$PLAYCOVER_CONTAINER"
    
    # Mount volume
    print_info "ボリュームをマウント中..."
    if sudo mount -t apfs "$volume_device" "$PLAYCOVER_CONTAINER"; then
        print_success "ボリュームを正常にマウントしました"
        print_info "マウントポイント: ${PLAYCOVER_CONTAINER}"
        
        # Set proper permissions
        sudo chown -R $(id -u):$(id -g) "$PLAYCOVER_CONTAINER" 2>/dev/null || true
    else
        print_error "ボリュームのマウントに失敗しました"
        exit_with_cleanup 1 "ボリュームマウントエラー"
    fi
    
    echo ""
}

#######################################################
# 11. Install Required Software
#######################################################

install_xcode_tools() {
    print_info "Xcode Command Line Tools をインストール中..."
    
    # Trigger installation
    xcode-select --install 2>/dev/null || true
    
    print_warning "Xcode Command Line Tools のインストールダイアログが表示されます"
    print_info "インストールが完了するまでお待ちください..."
    
    # Wait for installation
    while ! xcode-select -p >/dev/null 2>&1; do
        sleep 5
    done
    
    print_success "Xcode Command Line Tools のインストールが完了しました"
}

install_homebrew() {
    print_info "Homebrew をインストール中..."
    
    # Install Homebrew
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add to PATH for Apple Silicon
    if [[ ! -f "${HOME}/.zprofile" ]] || ! grep -q "/opt/homebrew/bin/brew" "${HOME}/.zprofile"; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "${HOME}/.zprofile"
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
    
    print_success "Homebrew のインストールが完了しました"
}

install_playcover() {
    print_info "PlayCover をインストール中..."
    
    # Install via Homebrew Cask
    brew install --cask playcover-community
    
    print_success "PlayCover のインストールが完了しました"
}

perform_installations() {
    print_header "11. 追加ソフトウェアのインストール"
    
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

#######################################################
# 12. Create Mapping Data
#######################################################

create_mapping_data() {
    print_header "12. マッピングデータの作成"
    
    # Check if mapping file exists
    local mapping_exists=false
    if [[ -f "$MAPPING_FILE" ]]; then
        # Check if this mapping already exists
        if grep -q "^${VOLUME_NAME}	${PLAYCOVER_BUNDLE_ID}$" "$MAPPING_FILE" 2>/dev/null; then
            print_warning "マッピングデータが既に存在します"
            mapping_exists=true
        fi
    fi
    
    if ! $mapping_exists; then
        # Create or append to mapping file
        echo "${VOLUME_NAME}	${PLAYCOVER_BUNDLE_ID}" >> "$MAPPING_FILE"
        print_success "マッピングデータを作成しました"
        print_info "ファイル: ${MAPPING_FILE}"
        print_info "データ: ${VOLUME_NAME} → ${PLAYCOVER_BUNDLE_ID}"
    fi
    
    echo ""
}

#######################################################
# Main Execution
#######################################################

main() {
    clear
    
    echo "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                                                           ║"
    echo "║        PlayCover 外部ストレージ環境構築スクリプト         ║"
    echo "║                                                           ║"
    echo "║              macOS Tahoe 26.0.1 対応版                    ║"
    echo "║                                                           ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo "${NC}"
    echo ""
    
    # Execute setup steps
    check_architecture
    check_full_disk_access
    check_xcode_tools
    check_homebrew
    check_playcover
    authenticate_sudo
    select_destination_disk
    confirm_installations
    create_playcover_volume
    mount_volume_to_container
    perform_installations
    create_mapping_data
    
    # Final success message
    print_header "セットアップ完了"
    print_success "PlayCover の外部ストレージ環境構築が完了しました"
    echo ""
    print_info "設定内容:"
    echo "  ボリューム名: ${VOLUME_NAME}"
    echo "  マウント先: ${PLAYCOVER_CONTAINER}"
    echo "  マッピングファイル: ${MAPPING_FILE}"
    echo ""
    
    exit_with_cleanup 0 "すべての処理が正常に完了しました"
}

# Handle Ctrl+C
trap 'echo ""; exit_with_cleanup 0 "ユーザーによりキャンセルされました"' INT

# Run main function
main
