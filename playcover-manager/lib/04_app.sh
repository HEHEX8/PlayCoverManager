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

check_playcover_volume_mount_install() {
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
    
    local temp_dir=$(create_temp_dir) || return 1
    
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

create_app_volume_install() {
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

mount_app_volume_install() {
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
            if ! prompt_confirmation "上書きしますか？" "Y/n"; then
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
                    /bin/sleep 2
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
                        /bin/sleep 2
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
                    /bin/sleep 2
                    
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
        
        /bin/sleep $check_interval
        elapsed=$((elapsed + check_interval))
        
        # Show progress indicator with detailed status (v5.0.1 - Unified)
        if [[ $settings_update_count -ge 2 ]]; then
            echo -n "✅"  # Complete (shouldn't reach here)
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
# Install Workflow
#######################################################

# Complete IPA installation workflow
# Handles multiple IPAs, batch mode, volume creation, and installation
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
    check_playcover_volume_mount_install
    
    select_ipa_files || return
    
    CURRENT_IPA_INDEX=0
    for ipa_file in "${(@)SELECTED_IPAS}"; do
        ((CURRENT_IPA_INDEX++))
        
        if [[ $BATCH_MODE == true ]]; then
            print_batch_progress "$CURRENT_IPA_INDEX" "$TOTAL_IPAS" "$(basename "$ipa_file")"
        fi
        
        extract_ipa_info "$ipa_file" || continue
        select_installation_disk || continue
        create_app_volume_install || continue
        mount_app_volume_install || continue
        install_ipa_to_playcover "$ipa_file" || continue
    done
    
    echo ""
    print_success "全ての処理が完了しました"
    
    if [[ ${#INSTALL_SUCCESS} -gt 0 ]]; then
        echo ""
        print_success "インストール成功: ${#INSTALL_SUCCESS} 個"
        for app in "${(@)INSTALL_SUCCESS}"; do
            echo "  ✅ $app"
        done
    fi
    
    if [[ ${#INSTALL_FAILED} -gt 0 ]]; then
        echo ""
        print_error "インストール失敗: ${#INSTALL_FAILED} 個"
        for app in "${(@)INSTALL_FAILED}"; do
            echo "  ✗ $app"
        done
    fi
    
    echo ""
    echo -n "Enterキーでメニューに戻る..."
    read
}

#######################################################
# Uninstall Workflow
#######################################################

# Interactive app uninstallation workflow
# Allows individual or batch uninstallation
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
    echo "${ORANGE}▼ アンインストール方法を選択${NC}"
    echo ""
    echo "  ${GREEN}個別削除${NC}: 1-${total_apps} の番号を入力"
    echo "  ${RED}一括削除${NC}: ${RED}ALL${NC} を入力（すべてのアプリを一度に削除）"
    echo "  ${CYAN}キャンセル${NC}: 0 を入力"
    echo ""
    echo -n "${ORANGE}選択:${NC} "
    read app_choice
    
    # Check for batch uninstall
    if [[ "$app_choice" == "ALL" ]] || [[ "$app_choice" == "all" ]]; then
        # Call batch uninstall function
        uninstall_all_apps
        return
    fi
    
    # Validate input for individual uninstall
    if [[ ! "$app_choice" =~ ^[0-9]+$ ]] || [[ $app_choice -lt 0 ]] || [[ $app_choice -gt $total_apps ]]; then
        print_error "$MSG_INVALID_SELECTION"
        wait_for_enter
        continue
    fi
    
    if [[ $app_choice -eq 0 ]]; then
        return
    fi
    
    # Get selected app info (zsh arrays are 1-indexed)
    local selected_app="${apps_list[$app_choice]}"
    local selected_volume="${volumes_list[$app_choice]}"
    local selected_bundle="${bundles_list[$app_choice]}"
    
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
    if ! prompt_confirmation "本当にアンインストールしますか？" "yes/NO"; then
        print_info "$MSG_CANCELED"
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
        if ! /bin/rm -rf "$app_path" 2>/dev/null; then
            handle_error_and_return "アプリの削除に失敗しました"
        fi
    fi
    
    # Step 2-5: Remove settings, entitlements, keymapping, containers (silent)
    local app_settings="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/App Settings/${selected_bundle}.plist"
    /bin/rm -f "$app_settings" 2>/dev/null
    
    local entitlements_file="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/Entitlements/${selected_bundle}.plist"
    /bin/rm -f "$entitlements_file" 2>/dev/null
    
    local keymapping_file="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/Keymapping/${selected_bundle}.plist"
    /bin/rm -f "$keymapping_file" 2>/dev/null
    
    local containers_dir="${HOME}/Library/Containers/${selected_bundle}"
    /bin/rm -rf "$containers_dir" 2>/dev/null
    
    # Step 7: Unmount volume if mounted (silent)
    local volume_mount_point="${PLAYCOVER_CONTAINER}/${selected_volume}"
    if /sbin/mount | grep -q "$volume_mount_point"; then
        unmount_volume "$volume_mount_point" "silent"
    fi
    
    # Step 8: Delete APFS volume
    local volume_device=$(get_volume_device "$selected_volume")
    
    if [[ -n "$volume_device" ]]; then
        if ! /usr/bin/sudo /usr/sbin/diskutil apfs deleteVolume "$volume_device" >/dev/null 2>&1; then
            print_error "ボリュームの削除に失敗しました"
            echo ""
            echo "手動で削除してください: /usr/bin/sudo /usr/sbin/diskutil apfs deleteVolume $volume_device"
            wait_for_enter
            return
        fi
    fi
    
    # Step 9: Remove from mapping file (silent)
    if ! remove_mapping "$selected_bundle"; then
        handle_error_and_return "マッピング情報の削除に失敗しました"
    fi
    
    # Step 10: If PlayCover volume, remove PlayCover.app and exit
    if [[ "$selected_volume" == "PlayCover" ]]; then
        echo ""
        local playcover_app="/Applications/PlayCover.app"
        if [[ -d "$playcover_app" ]]; then
            /bin/rm -rf "$playcover_app" 2>/dev/null
        fi
        
        print_success "PlayCover を完全にアンインストールしました"
        echo ""
        print_warning "PlayCoverが削除された為、このスクリプトは使用できません。"
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

# Batch uninstall all apps (called from uninstall_workflow)
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
    
    echo "${ORANGE}合計: ${total_apps} 個のアプリ${NC}"
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
    if ! prompt_confirmation "本当にすべてのアプリをアンインストールしますか？" "yes/NO"; then
        print_info "$MSG_CANCELED"
        wait_for_enter
        return
    fi
    
    # Start batch uninstallation
    echo ""
    
    local success_count=0
    local fail_count=0
    
    # Cache diskutil list for performance (single call for all apps)
    local diskutil_cache=$(/usr/sbin/diskutil list 2>/dev/null)
    
    # Loop through all apps (1-indexed zsh arrays)
    for ((i=1; i<=${#apps_list}; i++)); do
        local app_name="${apps_list[$i]}"
        local volume_name="${volumes_list[$i]}"
        local bundle_id="${bundles_list[$i]}"
        
        # Step 1: Remove app from PlayCover
        local playcover_apps="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/Applications"
        local app_path="${playcover_apps}/${bundle_id}.app"
        
        if [[ -d "$app_path" ]]; then
            /bin/rm -rf "$app_path" 2>/dev/null
        fi
        
        # Step 2-5: Remove settings, entitlements, keymapping, containers
        local app_settings="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/App Settings/${bundle_id}.plist"
        [[ -f "$app_settings" ]] && /bin/rm -f "$app_settings" 2>/dev/null
        
        local entitlements_file="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/Entitlements/${bundle_id}.plist"
        [[ -f "$entitlements_file" ]] && /bin/rm -f "$entitlements_file" 2>/dev/null
        
        local keymapping_file="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/Keymapping/${bundle_id}.plist"
        [[ -f "$keymapping_file" ]] && /bin/rm -f "$keymapping_file" 2>/dev/null
        
        local containers_dir="${HOME}/Library/Containers/${bundle_id}"
        [[ -d "$containers_dir" ]] && /bin/rm -rf "$containers_dir" 2>/dev/null
        
        # Step 6: Unmount and delete APFS volume
        local volume_mount_point="${PLAYCOVER_CONTAINER}/${volume_name}"
        if /sbin/mount | grep -q "$volume_mount_point"; then
            unmount_volume "$volume_mount_point" "silent"
        fi
        
        # Find and delete volume (use cached diskutil output)
        local volume_device=$(get_volume_device "$volume_name" "$diskutil_cache")
        if [[ -n "$volume_device" ]]; then
            if /usr/bin/sudo /usr/sbin/diskutil apfs deleteVolume "$volume_device" >/dev/null 2>&1; then
                print_success "${app_name}"
                ((success_count++))
            else
                print_error "${app_name} (ボリューム削除失敗)"
                ((fail_count++))
            fi
        else
            print_success "${app_name}"
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
    /bin/rm -rf "$playcover_app" 2>/dev/null
    
    # Summary
    echo ""
    print_separator
    echo ""
    print_success "PlayCover と全アプリを完全削除しました (${success_count} 個)"
    if [[ $fail_count -gt 0 ]]; then
        echo "  ${RED}失敗: ${fail_count} 個${NC}"
    fi
    echo ""
    print_warning "PlayCoverが削除された為、このスクリプトは使用できません。"
    echo ""
    /bin/sleep 2
    /usr/bin/osascript -e 'tell application "Terminal" to close (every window whose name contains "playcover")' & exit 0
}
