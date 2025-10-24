#!/bin/zsh

#######################################################
# PlayCover Volume Manager Script
# macOS Tahoe 26.0.1 Compatible
#######################################################

set -e

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
    diskutil info "${volume_name}" 2>/dev/null | grep "Device Node:" | awk '{print $NF}'
}

# Get current mount point of volume
get_mount_point() {
    local volume_name=$1
    local mount_point=$(diskutil info "${volume_name}" 2>/dev/null | grep "Mount Point:" | sed 's/.*: *//')
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
    
    # Remove existing directory if it exists and is not a mount point
    if [[ -d "$target_path" ]] && ! mount | grep -q " on ${target_path} "; then
        print_info "既存のディレクトリを削除中: ${target_path}"
        sudo rm -rf "$target_path"
    fi
    
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
# Main Operations
#######################################################

# Mount all volumes
mount_all_volumes() {
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
        exit_with_cleanup 0 "処理完了"
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
        
        if mount_volume "$volume_name" "$bundle_id" "$display_name"; then
            ((mounted_count++))
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
        echo -n "これらのマッピングを削除しますか？ (y/N): "
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
    
    exit_with_cleanup 0 "処理完了"
}

# Unmount all volumes
unmount_all_volumes() {
    print_header "全ボリュームのアンマウント"
    
    authenticate_sudo
    
    local mappings=($(read_mappings))
    
    if [[ ${#mappings[@]} -eq 0 ]]; then
        print_warning "登録されているアプリボリュームがありません"
        echo ""
        
        # Still try to unmount PlayCover main volume
        if volume_exists "$PLAYCOVER_VOLUME_NAME"; then
            unmount_volume "$PLAYCOVER_VOLUME_NAME" "PlayCover メインボリューム"
        fi
        
        exit_with_cleanup 0 "処理完了"
    fi
    
    local unmounted_count=0
    local failed_count=0
    
    # Unmount app volumes first
    for mapping in "${mappings[@]}"; do
        IFS='|' read -r volume_name bundle_id display_name <<< "$mapping"
        
        if unmount_volume "$volume_name" "$display_name"; then
            ((unmounted_count++))
        else
            ((failed_count++))
        fi
        echo ""
    done
    
    # Unmount PlayCover main volume last
    print_info "PlayCover メインボリュームをアンマウント中..."
    if volume_exists "$PLAYCOVER_VOLUME_NAME"; then
        if unmount_volume "$PLAYCOVER_VOLUME_NAME" "PlayCover メインボリューム"; then
            ((unmounted_count++))
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
    
    exit_with_cleanup 0 "処理完了"
}

# Individual volume control
individual_volume_control() {
    print_header "個別ボリューム操作"
    
    local mappings=($(read_mappings))
    
    if [[ ${#mappings[@]} -eq 0 ]]; then
        print_warning "登録されているアプリボリュームがありません"
        exit_with_cleanup 0 "処理完了"
    fi
    
    # Display volume list
    echo "登録されているボリューム:"
    echo ""
    
    local index=1
    for mapping in "${mappings[@]}"; do
        IFS='|' read -r volume_name bundle_id display_name <<< "$mapping"
        
        local status="❌"
        local mount_info=""
        
        if volume_exists "$volume_name"; then
            local current_mount=$(get_mount_point "$volume_name")
            local target_path="${HOME}/Library/Containers/${bundle_id}"
            
            if [[ -n "$current_mount" ]]; then
                if [[ "$current_mount" == "$target_path" ]]; then
                    status="✅"
                    mount_info="(正常にマウント済み)"
                else
                    status="⚠️ "
                    mount_info="(別の場所: ${current_mount})"
                fi
            else
                status="⭕"
                mount_info="(アンマウント済み)"
            fi
        else
            status="❌"
            mount_info="(ボリュームが見つかりません)"
        fi
        
        echo "  ${index}. ${status} ${display_name}"
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
        echo -n "このマッピングを削除しますか？ (y/N): "
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
                mount_volume "$volume_name" "$bundle_id" "$display_name"
                ;;
            *)
                print_info "キャンセルしました"
                ;;
        esac
    else
        echo "現在: アンマウント済み"
        echo ""
        echo -n "マウントしますか？ (Y/n): "
        read mount_choice
        
        if [[ ! "$mount_choice" =~ ^[Nn] ]]; then
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
        exit_with_cleanup 0 "処理完了"
    fi
    
    echo ""
    print_header "ディスクの検出"
    
    # Find the disk that contains the PlayCover volume
    local playcover_device=$(get_volume_device "$PLAYCOVER_VOLUME_NAME")
    if [[ -z "$playcover_device" ]]; then
        print_error "PlayCover ボリュームのデバイスが見つかりません"
        exit_with_cleanup 1 "デバイス検出失敗"
    fi
    
    # Extract disk identifier (e.g., /dev/disk5s1 -> disk5)
    local disk_id=$(echo "$playcover_device" | sed -E 's|/dev/(disk[0-9]+).*|\1|')
    
    # Get disk information
    local disk_name=$(diskutil info "/dev/$disk_id" | grep "Device / Media Name:" | sed 's/.*: *//')
    local disk_size=$(diskutil info "/dev/$disk_id" | grep "Disk Size:" | sed 's/.*: *//' | awk '{print $1, $2}')
    
    print_info "検出されたディスク:"
    echo "  名前: ${disk_name}"
    echo "  サイズ: ${disk_size}"
    echo "  デバイス: /dev/${disk_id}"
    echo ""
    
    print_warning "このディスクを取り外すと、すべてのボリュームがアンマウントされます"
    echo ""
    echo -n "ディスクを取り外しますか？ (y/N): "
    read eject_choice
    
    if [[ ! "$eject_choice" =~ ^[Yy] ]]; then
        print_info "キャンセルしました"
        exit_with_cleanup 0 "キャンセル"
    fi
    
    print_info "ディスクを取り外し中..."
    if sudo diskutil eject "/dev/$disk_id"; then
        print_success "ディスクを安全に取り外しました"
        print_info "物理的にデバイスを取り外すことができます"
    else
        print_error "ディスクの取り外しに失敗しました"
        exit_with_cleanup 1 "取り外し失敗"
    fi
    
    exit_with_cleanup 0 "処理完了"
}

# Show status
show_status() {
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

#######################################################
# Main Menu
#######################################################

show_menu() {
    clear
    
    echo "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                                                           ║"
    echo "║            ${GREEN}PlayCover ボリューム管理${CYAN}                     ║"
    echo "║                                                           ║"
    echo "║              ${BLUE}macOS Tahoe 26.0.1 対応版${CYAN}                    ║"
    echo "║                                                           ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo "${NC}"
    echo ""
    
    echo "${BLUE}━━━━━━━━━━━━━━ メニュー ━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  ${GREEN}1.${NC} 全ボリュームをマウント"
    echo "  ${YELLOW}2.${NC} 全ボリュームをアンマウント"
    echo "  ${CYAN}3.${NC} 個別ボリューム操作"
    echo "  ${BLUE}4.${NC} ボリューム状態確認"
    echo "  ${RED}5.${NC} ディスク全体を取り外し"
    echo "  ${NC}6.${NC} 終了"
    echo ""
    echo -n "${CYAN}選択 (1-6):${NC} "
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
                print_info "終了します"
                exit 0
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
trap 'echo ""; print_info "終了します"; exit 0' INT

# Run main
main
