#!/bin/zsh
#
# PlayCover Volume Manager - Module 06: Initial Setup
# ════════════════════════════════════════════════════════════════════
#
# This module provides initial system setup:
# - Architecture check (Apple Silicon required)
# - Xcode Command Line Tools check and installation
# - Homebrew check and installation
# - PlayCover installation via Homebrew
# - External disk selection
# - APFS container detection
# - PlayCover volume creation
# - Initial mapping creation
#
# Setup Flow:
#   1. Check architecture (arm64 required)
#   2. Check/install Xcode tools
#   3. Check/install Homebrew
#   4. Check/install PlayCover
#   5. Select external disk
#   6. Find APFS container
#   7. Create PlayCover volume
#   8. Create initial mapping
#
# Version: 5.0.0-alpha1
# Part of: Modular Architecture Refactoring

#######################################################
# Global Variables for Setup
#######################################################

NEED_XCODE_TOOLS=false
NEED_HOMEBREW=false
NEED_PLAYCOVER=false
SELECTED_EXTERNAL_DISK=""
SELECTED_CONTAINER=""

#######################################################
# Architecture Check
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

#######################################################
# Xcode Command Line Tools Check
#######################################################

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

install_xcode_tools() {
    print_header "Xcode Command Line Tools のインストール"
    
    print_info "インストールダイアログが表示されます..."
    echo ""
    
    xcode-select --install 2>/dev/null || true
    
    echo ""
    print_warning "インストールダイアログで「インストール」をクリックしてください"
    print_info "インストールが完了するまで待機します..."
    echo ""
    
    # Wait for installation to complete
    while ! xcode-select -p >/dev/null 2>&1; do
        echo -n "."
        /bin/sleep 5
    done
    
    echo ""
    echo ""
    print_success "Xcode Command Line Tools のインストールが完了しました"
    echo ""
}

#######################################################
# Homebrew Check and Installation
#######################################################

check_homebrew() {
    print_header "Homebrew の確認"
    
    if command -v brew >/dev/null 2>&1; then
        local brew_version=$("$BREW_PATH" --version | head -n 1)
        print_success "Homebrew が存在します"
        print_info "${brew_version}"
        NEED_HOMEBREW=false
    else
        print_warning "Homebrew が見つかりません"
        NEED_HOMEBREW=true
    fi
    
    echo ""
}

install_homebrew() {
    print_header "Homebrew のインストール"
    
    print_info "Homebrew の公式インストールスクリプトを実行します..."
    echo ""
    
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH for Apple Silicon
    if [[ $(uname -m) == "arm64" ]]; then
        echo ""
        print_info "Homebrew のパス設定を追加中..."
        
        local shell_rc="${HOME}/.zshrc"
        if [[ ! -f "$shell_rc" ]]; then
            touch "$shell_rc"
        fi
        
        if ! grep -q 'eval "$(/opt/homebrew/bin/brew shellenv)"' "$shell_rc"; then
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$shell_rc"
            print_success "パス設定を追加しました"
        fi
        
        # Reload Homebrew path for current session
        eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
    
    echo ""
    print_success "Homebrew のインストールが完了しました"
    echo ""
}

#######################################################
# PlayCover Check and Installation
#######################################################

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

install_playcover() {
    print_header "PlayCover のインストール"
    
    print_info "Homebrew Cask で PlayCover をインストールします..."
    echo ""
    
    if "$BREW_PATH" install --cask playcover-community; then
        echo ""
        print_success "PlayCover のインストールが完了しました"
    else
        echo ""
        print_error "PlayCover のインストールに失敗しました"
        print_info "手動でインストールしてください: https://playcover.io"
        wait_for_enter
        exit 1
    fi
    
    echo ""
}

#######################################################
# External Disk Selection
#######################################################

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
            for seen in "${(@)seen_disks}"; do
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
    
    if [[ ${#external_disks} -eq 0 ]]; then
        print_error "外部ストレージが見つかりません"
        print_info "外部ストレージを接続してから再実行してください"
        wait_for_enter
        exit 1
    fi
    
    for info in "${(@)disk_info}"; do
        echo "$info"
    done
    
    echo ""
    echo -n "選択してください (1-${#external_disks}): "
    read disk_choice
    
    if [[ ! "$disk_choice" =~ ^[0-9]+$ ]] || [[ $disk_choice -lt 1 ]] || [[ $disk_choice -gt ${#external_disks} ]]; then
        print_error "無効な選択です"
        wait_for_enter
        exit 1
    fi
    
    SELECTED_EXTERNAL_DISK="${external_disks[$disk_choice]}"
    
    echo ""
    print_success "選択されたディスク: ${SELECTED_EXTERNAL_DISK}"
    echo ""
}

#######################################################
# APFS Container Detection
#######################################################

find_apfs_container_setup() {
    print_header "APFS コンテナの検出"
    
    print_info "APFS コンテナを検索中..."
    echo ""
    
    local disk_id=$(echo "$SELECTED_EXTERNAL_DISK" | sed -E 's|/dev/(disk[0-9]+).*|\1|')
    
    # Check if disk itself is APFS container
    local disk_info=$(diskutil info "$SELECTED_EXTERNAL_DISK" 2>/dev/null)
    if echo "$disk_info" | grep -q "APFS Container Scheme"; then
        SELECTED_CONTAINER="$disk_id"
        print_success "APFS コンテナを検出しました: $SELECTED_CONTAINER"
        echo ""
        return 0
    fi
    
    # Check for APFS volumes on this disk
    local apfs_volumes=$(diskutil list | grep "APFS Volume" | grep "$disk_id")
    if [[ -n "$apfs_volumes" ]]; then
        # Extract container reference from volume
        local first_volume=$(echo "$apfs_volumes" | head -1 | awk '{print $NF}')
        local volume_info=$(diskutil info "/dev/$first_volume" 2>/dev/null)
        SELECTED_CONTAINER=$(echo "$volume_info" | grep "APFS Container:" | awk '{print $NF}')
        
        if [[ -n "$SELECTED_CONTAINER" ]]; then
            print_success "APFS コンテナを検出しました: $SELECTED_CONTAINER"
            echo ""
            return 0
        fi
    fi
    
    print_error "APFS コンテナが見つかりません"
    print_info "選択されたディスクに APFS コンテナが必要です"
    wait_for_enter
    exit 1
}

#######################################################
# PlayCover Volume Creation
#######################################################

create_playcover_volume_setup() {
    print_header "PlayCover ボリュームの作成"
    
    # Check if PlayCover volume already exists
    if volume_exists "$PLAYCOVER_VOLUME_NAME"; then
        print_info "PlayCover ボリュームは既に存在します"
        local existing_device=$(get_volume_device "$PLAYCOVER_VOLUME_NAME")
        print_info "デバイス: $existing_device"
        echo ""
        
        echo -n "既存のボリュームを使用しますか？ (Y/n): "
        read use_existing
        
        if [[ "$use_existing" =~ ^[Nn]$ ]]; then
            print_error "セットアップを中断しました"
            wait_for_enter
            exit 1
        fi
        
        echo ""
        return 0
    fi
    
    print_info "APFS ボリュームを作成中..."
    echo ""
    
    authenticate_sudo
    
    if /usr/bin/sudo /usr/sbin/diskutil apfs addVolume "$SELECTED_CONTAINER" APFS "$PLAYCOVER_VOLUME_NAME" -nomount > /tmp/apfs_create.log 2>&1; then
        print_success "PlayCover ボリュームを作成しました"
        echo ""
    else
        print_error "ボリュームの作成に失敗しました"
        echo ""
        print_info "エラーログ:"
        /bin/cat /tmp/apfs_create.log
        wait_for_enter
        exit 1
    fi
}

#######################################################
# Initial Mapping Creation
#######################################################

create_initial_mapping() {
    print_header "初期マッピングの作成"
    
    print_info "マッピングファイルを作成中..."
    
    # Create mapping file if not exists
    if [[ ! -f "$MAPPING_FILE" ]]; then
        /bin/mkdir -p "$(dirname "$MAPPING_FILE")"
        touch "$MAPPING_FILE"
    fi
    
    # Add PlayCover volume mapping
    add_mapping "$PLAYCOVER_VOLUME_NAME" "$PLAYCOVER_BUNDLE_ID" "PlayCover"
    
    echo ""
    print_success "初期セットアップが完了しました"
    echo ""
}

#######################################################
# Main Setup Flow
#######################################################

run_initial_setup() {
    clear
    print_separator "=" "$CYAN"
    echo ""
    echo "${BOLD}${CYAN}PlayCover Volume Manager - 初期セットアップ${NC}"
    echo ""
    print_separator "=" "$CYAN"
    echo ""
    
    # Step 1: Architecture check
    check_architecture
    wait_for_enter "Enterキーで続行..."
    
    # Step 2: Xcode tools check
    check_xcode_tools
    if [[ $NEED_XCODE_TOOLS == true ]]; then
        echo -n "Xcode Command Line Tools をインストールしますか？ (Y/n): "
        read install_choice
        if [[ ! "$install_choice" =~ ^[Nn]$ ]]; then
            install_xcode_tools
        else
            print_error "Xcode Command Line Tools は必須です"
            wait_for_enter
            exit 1
        fi
    fi
    wait_for_enter "Enterキーで続行..."
    
    # Step 3: Homebrew check
    check_homebrew
    if [[ $NEED_HOMEBREW == true ]]; then
        echo -n "Homebrew をインストールしますか？ (Y/n): "
        read install_choice
        if [[ ! "$install_choice" =~ ^[Nn]$ ]]; then
            install_homebrew
        else
            print_error "Homebrew は必須です"
            wait_for_enter
            exit 1
        fi
    fi
    wait_for_enter "Enterキーで続行..."
    
    # Step 4: PlayCover check
    check_playcover_installation
    if [[ $NEED_PLAYCOVER == true ]]; then
        echo -n "PlayCover をインストールしますか？ (Y/n): "
        read install_choice
        if [[ ! "$install_choice" =~ ^[Nn]$ ]]; then
            install_playcover
        else
            print_error "PlayCover は必須です"
            wait_for_enter
            exit 1
        fi
    fi
    wait_for_enter "Enterキーで続行..."
    
    # Step 5: External disk selection
    select_external_disk
    wait_for_enter "Enterキーで続行..."
    
    # Step 6: APFS container detection
    find_apfs_container_setup
    wait_for_enter "Enterキーで続行..."
    
    # Step 7: PlayCover volume creation
    create_playcover_volume_setup
    wait_for_enter "Enterキーで続行..."
    
    # Step 8: Initial mapping
    create_initial_mapping
    
    # Summary
    clear
    print_separator "=" "$GREEN"
    echo ""
    echo "${BOLD}${GREEN}✅ 初期セットアップ完了${NC}"
    echo ""
    print_separator "=" "$GREEN"
    echo ""
    
    echo "${CYAN}次のステップ:${NC}"
    echo ""
    echo "  ${LIGHT_GREEN}1.${NC} メインメニューに戻る"
    echo "  ${LIGHT_GREEN}2.${NC} オプション2で IPA ファイルをインストール"
    echo "  ${LIGHT_GREEN}3.${NC} PlayCover でゲームを起動"
    echo ""
    
    wait_for_enter "Enterキーでメニューに戻る..."
}
