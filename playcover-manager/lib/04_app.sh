#!/bin/zsh
#
# PlayCover Volume Manager - Module 04: App Management
# ════════════════════════════════════════════════════════════════════
#
# This module provides IPA installation and app management:
# - IPA file selection (single/batch)
# - App information extraction from Info.plist
# - PlayCover volume mounting
# - App volume creation and mounting
# - IPA installation to PlayCover with progress tracking
# - Installation status monitoring
# - Batch installation support
#
# Installation Detection Strategy (v5.0.1):
#   - Wait for settings file 2nd update → Complete immediately
#   - Both new and overwrite installs use same detection
#   - Robust crash detection and recovery
#
# Version: 5.0.0-alpha1
# Part of: Modular Architecture Refactoring

#######################################################
# Global Variables for Installation
#######################################################

# Arrays for selected IPAs and results
declare -a SELECTED_IPAS=()
declare -a INSTALL_SUCCESS=()
declare -a INSTALL_FAILED=()

# Installation state
TOTAL_IPAS=0
CURRENT_IPA_INDEX=0
BATCH_MODE=false

# Current app information
APP_BUNDLE_ID=""
APP_NAME=""
APP_NAME_EN=""
APP_VERSION=""
APP_VOLUME_NAME=""

# PlayCover volume device
PLAYCOVER_VOLUME_DEVICE=""

# Selected disk for volume creation
SELECTED_DISK=""

#######################################################
# PlayCover Volume Management
#######################################################

check_playcover_volume_mount() {
    if [[ ! -d "$PLAYCOVER_CONTAINER" ]]; then
        /usr/bin/sudo /bin/mkdir -p "$PLAYCOVER_CONTAINER"
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
        if ! unmount_volume "$PLAYCOVER_VOLUME_DEVICE" "silent" "force"; then
            print_error "ボリュームのアンマウントに失敗しました"
            exit_with_cleanup 1 "ボリュームアンマウントエラー"
        fi
    fi
    
    if /usr/bin/sudo /sbin/mount -t apfs -o nobrowse "$PLAYCOVER_VOLUME_DEVICE" "$PLAYCOVER_CONTAINER"; then
        /usr/bin/sudo /usr/sbin/chown -R $(id -u):$(id -g) "$PLAYCOVER_CONTAINER" 2>/dev/null || true
        
        # Create necessary directory structure if it doesn't exist
        local playcover_apps="${PLAYCOVER_CONTAINER}/Applications"
        local playcover_settings="${PLAYCOVER_CONTAINER}/App Settings"
        local playcover_entitlements="${PLAYCOVER_CONTAINER}/Entitlements"
        local playcover_keymapping="${PLAYCOVER_CONTAINER}/Keymapping"
        
        if [[ ! -d "$playcover_apps" ]]; then
            /bin/mkdir -p "$playcover_apps" 2>/dev/null || true
        fi
        if [[ ! -d "$playcover_settings" ]]; then
            /bin/mkdir -p "$playcover_settings" 2>/dev/null || true
        fi
        if [[ ! -d "$playcover_entitlements" ]]; then
            /bin/mkdir -p "$playcover_entitlements" 2>/dev/null || true
        fi
        if [[ ! -d "$playcover_keymapping" ]]; then
            /bin/mkdir -p "$playcover_keymapping" 2>/dev/null || true
        fi
    else
        print_error "$MSG_MOUNT_FAILED"
        exit_with_cleanup 1 "ボリュームマウントエラー"
    fi
}

#######################################################
# IPA File Selection
#######################################################

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
    
    TOTAL_IPAS=${#SELECTED_IPAS}
    
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
        # zsh 1-based indexing
        print_success "$(basename "${SELECTED_IPAS[1]}")"
    fi
    
    echo ""
}

#######################################################
# App Information Extraction
#######################################################

extract_ipa_info() {
    local ipa_file=$1
    
    local temp_dir=$(mktemp -d)
    
    local plist_path=$(unzip -l "$ipa_file" 2>/dev/null | /usr/bin/grep -E "Payload/.*\.app/Info\.plist" | head -n 1 | /usr/bin/awk '{print $NF}')
    
    if [[ -z "$plist_path" ]]; then
        print_error "IPA 内に Info.plist が見つかりません"
        /bin/rm -rf "$temp_dir"
        return 1
    fi
    
    if ! /usr/bin/unzip -q "$ipa_file" "$plist_path" -d "$temp_dir" 2>/dev/null; then
        print_error "Info.plist の解凍に失敗しました"
        /bin/rm -rf "$temp_dir"
        return 1
    fi
    
    local info_plist="${temp_dir}/${plist_path}"
    
    if [[ -z "$info_plist" ]]; then
        print_error "Info.plist が見つかりません"
        /bin/rm -rf "$temp_dir"
        return 1
    fi
    
    APP_BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$info_plist" 2>/dev/null)
    
    if [[ -z "$APP_BUNDLE_ID" ]]; then
        print_error "Bundle Identifier の取得に失敗しました"
        /bin/rm -rf "$temp_dir"
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
        /bin/rm -rf "$temp_dir"
        return 1
    fi
    
    local app_name_ja=""
    local strings_path=$(unzip -l "$ipa_file" 2>/dev/null | /usr/bin/grep -E "Payload/.*\.app/ja\.lproj/InfoPlist\.strings" | head -n 1 | /usr/bin/awk '{print $NF}')
    if [[ -n "$strings_path" ]]; then
        /usr/bin/unzip -q "$ipa_file" "$strings_path" -d "$temp_dir" 2>/dev/null || true
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
    
    /bin/rm -rf "$temp_dir"
    
    print_info "${APP_NAME} (${APP_VERSION})"
    echo ""
    return 0
}

#######################################################
# Volume Creation and Mounting
#######################################################

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
        existing_volume=$(get_volume_device "${APP_VOLUME_NAME}")
    fi
    
    if [[ -n "$existing_volume" ]]; then
        return 0
    fi
    
    if /usr/bin/sudo /usr/sbin/diskutil apfs addVolume "$SELECTED_DISK" APFS "${APP_VOLUME_NAME}" -nomount > /tmp/apfs_create_app.log 2>&1; then
        /bin/sleep 1
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
        print_error "$MSG_MOUNT_FAILED"
        return 1
    fi
}

#######################################################
# IPA Installation to PlayCover
#######################################################

# Main installation function with progress tracking
# This is a complex 300+ line function that handles:
# - Existing app detection and overwrite confirmation
# - PlayCover launching and IPA opening
# - Installation progress monitoring (settings file update count)
# - Crash detection and recovery
# - Batch mode support
#
# TODO: Complete implementation (lines 1358-1662 from original)
install_ipa_to_playcover() {
    local ipa_file=$1
    
    print_info "IPA インストール機能は実装中です"
    print_info "ファイル: $(basename "$ipa_file")"
    echo ""
    
    # TODO: Complete implementation with:
    # - Existing app check and overwrite prompt
    # - PlayCover launch and monitoring
    # - Installation progress tracking
    # - Crash detection and recovery
    # - Mapping update after success
    
    return 1  # Placeholder
}
