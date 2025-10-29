#!/bin/zsh
#
# PlayCover Volume Manager - UI Module
# File: lib/07_ui.sh
# Description: Main menu, quick status, individual volume control, batch operations
# Version: 5.0.1
#

#######################################################
# Quick Status Display
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
        
        # Check actual mount status using get_mount_point (same logic as volume info)
        local actual_mount=$(get_mount_point "$volume_name")
        
        if [[ -n "$actual_mount" ]] && [[ "$actual_mount" == "$target_path" ]]; then
            # Volume is mounted at correct location = external storage
            ((external_count++))
        else
            # Volume not mounted - check if internal storage has data
            local storage_mode=$(get_storage_mode "$target_path" "$volume_name")
            case "$storage_mode" in
                "internal_intentional"|"internal_contaminated")
                    ((internal_count++))
                    ;;
                *)
                    ((unmounted_count++))
                    ;;
            esac
        fi
    done <<< "$mappings_content"
    
    if [[ $total_count -gt 0 ]]; then
        echo "${CYAN}コンテナ情報${NC}"
        
        # Build status line dynamically (only show non-zero items)
        local status_parts=()
        
        if [[ $external_count -gt 0 ]]; then
            status_parts+=("${SKY_BLUE}🔌 外部マウント: ${external_count}件${NC}")
        fi
        
        if [[ $internal_count -gt 0 ]]; then
            status_parts+=("${ORANGE}🏠 内部マウント: ${internal_count}件${NC}")
        fi
        
        if [[ $unmounted_count -gt 0 ]]; then
            status_parts+=("${RED}❌ データ無し: ${unmounted_count}件${NC}")
        fi
        
        # Join status parts with separator
        local first=true
        for part in "${(@)status_parts}"; do
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
    fi
}

#######################################################
# Main Menu Display
#######################################################

show_menu() {
    clear
    
    echo ""
    echo "${GREEN}PlayCover 統合管理ツール${NC}  ${SKY_BLUE}Version 5.0.1${NC}"
    echo ""
    
    show_quick_status
    
    echo "${CYAN}メインメニュー${NC}"
    echo ""
    echo "  ${LIGHT_GREEN}1.${NC} アプリ管理"
    echo "  ${LIGHT_GREEN}2.${NC} ボリューム操作"
    echo "  ${LIGHT_GREEN}3.${NC} ストレージ切り替え（内蔵⇄外部）"
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
    
    echo "  ${LIGHT_GREEN}4.${NC} ${eject_label}"
    echo "  ${LIGHT_GREEN}0.${NC} 終了"
    echo ""
    echo -n "${CYAN}選択 (0-4):${NC} "
}

#######################################################
# Installed Apps Display
#######################################################

show_installed_apps() {
    local playcover_apps="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/Applications"
    local display_only="${1:-true}"  # Default to display mode
    
    # Check if mapping file exists
    if [[ ! -f "$MAPPING_FILE" ]]; then
        if [[ "$display_only" == "true" ]]; then
            echo "${ORANGE}インストール済みアプリ:${NC} ${SKY_BLUE}0個${NC}"
        fi
        return
    fi
    
    local mappings_content=$(read_mappings)
    
    if [[ -z "$mappings_content" ]]; then
        if [[ "$display_only" == "true" ]]; then
            echo "${ORANGE}インストール済みアプリ:${NC} ${SKY_BLUE}0個${NC}"
        fi
        return
    fi
    
    # Check if PlayCover Applications directory exists
    # Create it if PlayCover container is mounted but directory doesn't exist
    if [[ ! -d "$playcover_apps" ]]; then
        local playcover_container="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}"
        if [[ -d "$playcover_container" ]]; then
            # Container exists (mounted), create Applications directory
            /bin/mkdir -p "$playcover_apps" 2>/dev/null || true
        fi
        
        # Check again after creation attempt
        if [[ ! -d "$playcover_apps" ]]; then
            if [[ "$display_only" == "true" ]]; then
                echo "${ORANGE}インストール済みアプリ:${NC} ${RED}PlayCoverコンテナが見つかりません${NC}"
            fi
            return
        fi
    fi
    
    if [[ "$display_only" == "true" ]]; then
        echo "${ORANGE}インストール済みアプリ${NC}"
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
            
            # Check actual mount status using get_mount_point (same as volume info display)
            local actual_mount=$(get_mount_point "$volume_name")
            local storage_icon=""
            
            if [[ -n "$actual_mount" ]] && [[ "$actual_mount" == "$container_path" ]]; then
                # Volume is mounted at correct location = external storage
                storage_icon="🔌 外部"
            elif [[ -n "$actual_mount" ]]; then
                # Volume is mounted but at wrong location
                storage_icon="⚠️  位置異常"
            else
                # Volume not mounted - check if internal storage has data
                local storage_mode=$(get_storage_mode "$container_path" "$volume_name")
                case "$storage_mode" in
                    "internal_intentional"|"internal_contaminated")
                        storage_icon="🏠 内部"
                        ;;
                    "internal_intentional_empty"|"none")
                        storage_icon="⚠️  データ無し"
                        container_size="0B"
                        ;;
                    *)
                        storage_icon="？ 不明"
                        ;;
                esac
            fi
            
            if [[ "$display_only" == "true" ]]; then
                printf " ${BOLD}%s${NC} ${LIGHT_GRAY}|${NC} ${BOLD}${WHITE}%s${NC} ${GRAY}(v%s)${NC} ${LIGHT_GRAY}%s${NC}\n" "$storage_icon" "$container_size" "$app_version" "$display_name"
            else
                echo "  ${BOLD}${CYAN}${index}.${NC} ${BOLD}${WHITE}${display_name}${NC} ${GRAY}(v${app_version})${NC}"
                echo "      ${GRAY}Bundle ID:${NC} ${LIGHT_GRAY}${bundle_id}${NC}"
                echo "      ${GRAY}ボリューム:${NC} ${LIGHT_GRAY}${volume_name}${NC}"
                echo "      ${GRAY}使用容量:${NC} ${BOLD}${storage_icon}${NC} ${BOLD}${WHITE}${container_size}${NC}"
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
                # Check what exactly is missing for detailed error message
                local volume_exists_check=$(volume_exists "$volume_name" 2>/dev/null && echo "yes" || echo "no")
                local container_exists_check=$([[ -d "${HOME}/Library/Containers/${bundle_id}" ]] && echo "yes" || echo "no")
                
                local missing_reason=""
                if [[ "$volume_exists_check" == "no" ]] && [[ "$container_exists_check" == "no" ]]; then
                    missing_reason="${RED}(ボリュームとアプリ本体が見つかりません - マッピングデータが古い可能性)${NC}"
                elif [[ "$volume_exists_check" == "no" ]]; then
                    missing_reason="${RED}(ボリュームが見つかりません)${NC}"
                else
                    missing_reason="${RED}(アプリ本体.appが見つかりません)${NC}"
                fi
                
                echo "  ${BOLD}${RED}❌${NC} ${STRIKETHROUGH}${GRAY}${display_name}${NC} ${BOLD}${missing_reason}"
            fi
            ((missing_count++))
        fi
    done <<< "$mappings_content"
    
    if [[ "$display_only" == "true" ]]; then
        print_separator
        echo ""
        echo "${CYAN}操作を選択してください${NC}"
    fi
    
    # Return installed count for uninstall workflow
    if [[ "$display_only" == "false" ]]; then
        return $installed_count
    fi
}

#######################################################
# App Management Menu
#######################################################

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
                    print_warning "PlayCoverボリュームが未マウントですが、内蔵ストレージにデータがあります"
                    echo ""
                    echo "${ORANGE}対処方法:${NC}"
                    echo "  1. 内蔵データを外部に移行してマウント（推奨）"
                    echo "  2. 内蔵データを削除してクリーンな状態でマウント"
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
                            print_info "$MSG_CANCELED"
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
        echo "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo "${BOLD}${CYAN}  📱 アプリ管理${NC}"
        echo "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        show_installed_apps
        echo ""
        print_separator
        echo ""
        echo "${BOLD}${UNDERLINE}操作を選択してください${NC}"
        echo "  ${BOLD}${GREEN}1.${NC} アプリをインストール"
        echo "  ${BOLD}${RED}2.${NC} アプリをアンインストール"
        echo "  ${BOLD}${LIGHT_GRAY}0.${NC} メインメニューに戻る"
        echo ""
        echo -n "${BOLD}${YELLOW}選択: ${NC}"
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
                print_error "$MSG_INVALID_SELECTION"
                wait_for_enter
                ;;
        esac
    done
}

#######################################################
# Individual Volume Control
#######################################################

individual_volume_control() {
    clear
    print_header "ボリューム情報"
    
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
    if [[ ${#mappings_array} -eq 0 ]]; then
        show_error_and_return "ボリューム情報" "$MSG_NO_REGISTERED_VOLUMES"
        return
    fi
    
    echo "登録ボリューム"
    echo ""
    
    # Cache diskutil output once for performance
    local diskutil_cache=$(/usr/sbin/diskutil list 2>/dev/null)
    local mount_cache=$(/sbin/mount 2>/dev/null)
    
    # Check if any app is running (affects PlayCover lock status)
    local any_app_running=false
    for ((j=1; j<=${#mappings_array}; j++)); do
        IFS='|' read -r _ check_bundle_id _ <<< "${mappings_array[$j]}"
        if [[ "$check_bundle_id" != "$PLAYCOVER_BUNDLE_ID" ]]; then
            if is_app_running "$check_bundle_id"; then
                any_app_running=true
                break
            fi
        fi
    done
    
    # Build selectable array (excluding locked volumes)
    local -a selectable_array=()
    local -a selectable_indices=()
    
    # Display volumes with detailed status (single column)
    local display_index=1
    for ((i=1; i<=${#mappings_array}; i++)); do
        IFS='|' read -r volume_name bundle_id display_name <<< "${mappings_array[$i]}"
        
        local target_path="${HOME}/Library/Containers/${bundle_id}"
        local status_line=""
        local extra_info=""
        local is_locked=false
        
        # Check if app is running (locked)
        local lock_reason=""
        if [[ "$bundle_id" == "$PLAYCOVER_BUNDLE_ID" ]]; then
            # PlayCover volume is locked if PlayCover is running OR any app is running
            if is_playcover_running; then
                is_locked=true
                lock_reason="app_running"  # PlayCover自体が動作中
            elif [[ "$any_app_running" == "true" ]]; then
                is_locked=true
                lock_reason="app_storage"  # 配下のアプリが動作中（アプリ本体.appを保管中）
            fi
        else
            if is_app_running "$bundle_id"; then
                is_locked=true
                lock_reason="app_running"  # アプリ自体が動作中
            fi
        fi
        
        # Check if volume exists (using cached diskutil output)
        if ! volume_exists "$volume_name" "$diskutil_cache"; then
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
                # Volume is not mounted - check storage mode
                local storage_mode=$(get_storage_mode "$target_path" "$volume_name")
                
                case "$storage_mode" in
                    "none")
                        status_line="⚪️ 未マウント"
                        ;;
                    "internal_intentional")
                        # Intentionally switched to internal storage with data
                        status_line="⚪️ 未マウント"
                        extra_info="internal_intentional"
                        ;;
                    "internal_intentional_empty")
                        # Intentionally switched to internal storage but empty
                        status_line="⚪️ 未マウント"
                        extra_info="internal_intentional_empty"
                        ;;
                    "internal_contaminated")
                        # Unintended internal data contamination
                        status_line="⚪️ 未マウント"
                        extra_info="internal_contaminated"
                        ;;
                    *)
                        status_line="⚪️ 未マウント"
                        ;;
                esac
            fi
        fi
        
        # Display with lock status or number
        if $is_locked; then
            # Locked: show with lock icon, no number
            if [[ "$lock_reason" == "app_running" ]]; then
                echo "  ${BOLD}🔒 ${GOLD}ロック中${NC} ${BOLD}${WHITE}${display_name}${NC} ${GRAY}| 🏃 アプリ動作中${NC}"
            elif [[ "$lock_reason" == "app_storage" ]]; then
                echo "  ${BOLD}🔒 ${GOLD}ロック中${NC} ${BOLD}${WHITE}${display_name}${NC} ${GRAY}| 🚬 下記アプリの終了待機中${NC}"
            fi
            echo "      ${GRAY}${status_line}${NC}"
            echo ""
        elif [[ "$extra_info" == "internal_intentional" ]] || [[ "$extra_info" == "internal_intentional_empty" ]]; then
            # Intentional internal storage mode (with or without data): show as locked
            echo "  ${BOLD}🔒 ${GOLD}ロック中${NC} ${BOLD}${WHITE}${display_name}${NC} ${GRAY}| 🏠 内蔵ストレージモード${NC}"
            echo "      ${GRAY}${status_line}${NC}"
            echo ""
        elif [[ "$extra_info" == "internal_contaminated" ]]; then
            # Contaminated: show as warning (selectable)
            selectable_array+=("${mappings_array[$i]}")
            selectable_indices+=("$i")
            
            echo "  ${BOLD}${YELLOW}${display_index}.${NC} ${BOLD}${WHITE}${display_name}${NC} ${BOLD}${ORANGE}⚠️  内蔵データ検出${NC}"
            echo "      ${GRAY}${status_line} ${ORANGE}| マウント時に処理方法を確認します${NC}"
            echo ""
            ((display_index++))
        else
            # Not locked: add to selectable array and show with number
            selectable_array+=("${mappings_array[$i]}")
            selectable_indices+=("$i")
            
            echo "  ${BOLD}${CYAN}${display_index}.${NC} ${BOLD}${WHITE}${display_name}${NC}"
            echo "      ${GRAY}${status_line}${NC}"
            echo ""
            ((display_index++))
        fi
    done
    
    print_separator
    echo ""
    echo "${BOLD}${UNDERLINE}操作を選択してください:${NC}"
    echo "  ${BOLD}${CYAN}[番号]${NC} : 個別マウント/アンマウント"
    echo "  ${BOLD}${GREEN}[m]${NC}    : 全ボリュームをマウント"
    echo "  ${BOLD}${YELLOW}[u]${NC}    : 全ボリュームをアンマウント"
    echo "  ${BOLD}${LIGHT_GRAY}[0]${NC}    : 戻る"
    echo ""
    echo -n "選択: "
    read choice
    
    if [[ "$choice" == "0" ]]; then
        return
    fi
    
    # Batch operations (sudo will be requested inside the function)
    if [[ "$choice" == "m" ]] || [[ "$choice" == "M" ]]; then
        batch_mount_all
        individual_volume_control
        return
    fi
    
    if [[ "$choice" == "u" ]] || [[ "$choice" == "U" ]]; then
        batch_unmount_all
        individual_volume_control
        return
    fi
    
    # Check if no selectable volumes
    if [[ ${#selectable_array} -eq 0 ]]; then
        print_warning "選択可能なボリュームがありません（全てロック中）"
        wait_for_enter
        individual_volume_control
        return
    fi
    
    if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ $choice -lt 1 ]] || [[ $choice -gt ${#selectable_array} ]]; then
        print_error "$MSG_INVALID_SELECTION"
        /bin/sleep 2
        individual_volume_control
        return
    fi
    
    # zsh arrays are 1-indexed, so choice can be used directly
    local selected_mapping="${selectable_array[$choice]}"
    IFS='|' read -r volume_name bundle_id display_name <<< "$selected_mapping"
    
    local target_path="${HOME}/Library/Containers/${bundle_id}"
    local current_mount=$(get_mount_point "$volume_name")
    
    # Quick switch without confirmation
    if [[ -n "$current_mount" ]]; then
        # Volume is mounted somewhere
        if ! check_volume_exists_or_error "$volume_name" "${display_name} の操作" "individual_volume_control"; then
            return
        fi
        
        # Check if mounted at correct location
        if [[ "$current_mount" == "$target_path" ]]; then
            # Correctly mounted -> Unmount
            
            # Re-check if app is running (race condition prevention)
            local app_is_running=false
            if [[ "$bundle_id" == "$PLAYCOVER_BUNDLE_ID" ]]; then
                # Special check for PlayCover itself
                is_playcover_running && app_is_running=true
            else
                # Normal app check
                is_app_running "$bundle_id" && app_is_running=true
            fi
            
            if [[ "$app_is_running" == true ]]; then
                clear
                print_header "${display_name} の操作"
                echo ""
                print_error "アンマウント失敗: アプリが実行中です"
                echo ""
                print_info "アプリを終了してから再度お試しください"
                wait_for_enter
                individual_volume_control
                return
            fi
            
            local device=$(get_volume_device "$volume_name")
            if unmount_volume "$device" "silent"; then
                # Success - silently return to menu
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
            # Mounted at wrong location -> Remount to correct location
            
            # Re-check if app is running (race condition prevention)
            local app_is_running=false
            if [[ "$bundle_id" == "$PLAYCOVER_BUNDLE_ID" ]]; then
                # Special check for PlayCover itself
                is_playcover_running && app_is_running=true
            else
                # Normal app check
                is_app_running "$bundle_id" && app_is_running=true
            fi
            
            if [[ "$app_is_running" == true ]]; then
                clear
                print_header "${display_name} の操作"
                echo ""
                print_error "再マウント失敗: アプリが実行中です"
                echo ""
                print_info "アプリを終了してから再度お試しください"
                wait_for_enter
                individual_volume_control
                return
            fi
            
            local device=$(get_volume_device "$volume_name")
            
            # Unmount from wrong location
            if ! unmount_volume "$device" "silent"; then
                clear
                print_header "${display_name} の操作"
                echo ""
                print_error "アンマウント失敗: ファイルが使用中の可能性があります"
                wait_for_enter
                individual_volume_control
                return
            fi
            
            # Mount to correct location
            # Create mount point if not exists
            /usr/bin/sudo /bin/mkdir -p "$target_path" 2>/dev/null
            
            if mount_volume "/dev/$device" "$target_path" "nobrowse" "silent"; then
                # Success - silently return to menu
                individual_volume_control
                return
            else
                clear
                print_header "${display_name} の操作"
                echo ""
                print_error "再マウント失敗"
                wait_for_enter
                individual_volume_control
                return
            fi
        fi
    else
        # Currently unmounted -> Mount
        if ! check_volume_exists_or_error "$volume_name" "${display_name} の操作" "individual_volume_control"; then
            return
        fi
        
        # Check storage mode before mounting (includes external volume mount check)
        local storage_mode=$(get_storage_mode "$target_path" "$volume_name")
        
        if [[ "$storage_mode" == "internal_intentional" ]] || [[ "$storage_mode" == "internal_intentional_empty" ]]; then
            # Intentional internal storage (with or without data) - refuse to mount
            clear
            print_header "${display_name} の操作"
            echo ""
            print_error "$MSG_INTENTIONAL_INTERNAL_MODE"
            print_info "$MSG_SWITCH_VIA_STORAGE_MENU"
            echo ""
            wait_for_enter "Enterキーで続行..."
            individual_volume_control
            return
        elif [[ "$storage_mode" == "internal_contaminated" ]]; then
            # Contaminated data - ask user for cleanup method
            clear
            print_header "${display_name} の操作"
            echo ""
            print_warning "$MSG_UNINTENDED_INTERNAL_DATA"
            echo ""
            
            # Show data sizes for informed decision
            local internal_size=$(get_container_size "$target_path")
            echo "  ${CYAN}内蔵データサイズ:${NC} ${BOLD}${internal_size}${NC}"
            echo ""
            
            echo "${BOLD}${YELLOW}処理方法を選択してください:${NC}"
            echo "  ${BOLD}${GREEN}1.${NC} 外部ボリュームを優先（内蔵データは削除）${BOLD}${GREEN}[推奨・デフォルト]${NC}"
            echo "  ${BOLD}${CYAN}2.${NC} 内蔵データを外部ボリュームにマージ（内蔵データを保持）"
            echo "  ${BOLD}${BLUE}3.${NC} キャンセル（マウントしない）"
            echo ""
            echo -n "${BOLD}${YELLOW}選択 (1-3) [デフォルト: 1]:${NC} "
            read cleanup_choice
            
            # Default to option 1 if empty
            cleanup_choice=${cleanup_choice:-1}
            
            case "$cleanup_choice" in
                1)
                    print_info "外部ボリュームを優先します（内蔵データを削除）"
                    print_info "$MSG_CLEANUP_INTERNAL_STORAGE"
                    /usr/bin/sudo /bin/rm -rf "$target_path"
                    echo ""
                    # Continue to mount below
                    ;;
                2)
                    print_info "内蔵データを外部ボリュームにマージします"
                    echo ""
                    
                    # Mount external volume to temporary location
                    local temp_mount=$(create_temp_dir) || {
                        show_error_and_return "${display_name} の操作" "一時ディレクトリの作成に失敗しました" "individual_volume_control"
                        return
                    }
                    
                    local device=$(get_volume_device "$volume_name")
                    if [[ -z "$device" ]]; then
                        cleanup_temp_dir "$temp_mount" true
                        show_error_and_return "${display_name} の操作" "ボリュームデバイスの取得に失敗しました" "individual_volume_control"
                        return
                    fi
                    
                    print_info "外部ボリュームを一時マウント中..."
                    if ! /usr/bin/sudo /sbin/mount -t apfs -o nobrowse "/dev/$device" "$temp_mount" 2>/dev/null; then
                        cleanup_temp_dir "$temp_mount" true
                        show_error_and_return "${display_name} の操作" "外部ボリュームのマウントに失敗しました" "individual_volume_control"
                        return
                    fi
                    
                    # Copy internal data to external volume (merge)
                    print_info "内蔵データを外部ボリュームにマージ中..."
                    if /usr/bin/sudo /usr/bin/rsync -a --info=progress2 "$target_path/" "$temp_mount/"; then
                        print_success "マージ完了"
                        
                        # Unmount temporary mount
                        unmount_volume "/dev/$device" "silent"
                        cleanup_temp_dir "$temp_mount" true
                        
                        # Remove internal data
                        print_info "内蔵データをクリーンアップ中..."
                        /usr/bin/sudo /bin/rm -rf "$target_path"
                        echo ""
                    else
                        print_error "マージに失敗しました"
                        unmount_volume "/dev/$device" "silent"
                        cleanup_temp_dir "$temp_mount" true
                        wait_for_enter
                        individual_volume_control
                        return
                    fi
                    # Continue to mount below
                    ;;
                *)
                    show_error_and_return "${display_name} の操作" "$MSG_CANCELED" "individual_volume_control"
                    return
                    ;;
            esac
        fi
        
        # Ensure PlayCover volume is mounted first (dependency requirement)
        if [[ "$bundle_id" != "$PLAYCOVER_BUNDLE_ID" ]]; then
            if ! ensure_playcover_main_volume >/dev/null 2>&1; then
                show_error_and_return "${display_name} の操作" "PlayCover ボリューム（依存先）のマウントに失敗しました" "individual_volume_control"
                return
            fi
        fi
        
        # Get device path for mounting
        local device=$(get_volume_device "$volume_name")
        if [[ -z "$device" ]]; then
            show_error_and_return "${display_name} の操作" "ボリュームデバイスの取得に失敗しました" "individual_volume_control"
            return
        fi
        
        # Create mount point if not exists
        /usr/bin/sudo /bin/mkdir -p "$target_path" 2>/dev/null
        
        # Try to mount using mount_volume function with device path and nobrowse option
        if mount_volume "/dev/$device" "$target_path" "nobrowse" "silent"; then
            # Success - silently return to menu
            individual_volume_control
            return
        else
            # Failed - show error
            show_error_and_return "${display_name} の操作" "マウントに失敗しました" "individual_volume_control"
            return
        fi
    fi
}

#######################################################
# Mapping Info Display
#######################################################

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

#######################################################
# Quick Launcher UI
#######################################################

# Show quick launcher menu (app selection and launch)
# Returns: 0 to continue to main menu, exits on quit
show_quick_launcher() {
    while true; do
        clear
        print_header "🚀 PlayCover Quick Launcher"
        
        # Get launchable apps
        local -a apps_info=()
        while IFS= read -r line; do
            [[ -n "$line" ]] && apps_info+=("$line")
        done < <(get_launchable_apps)
        
        if [[ ${#apps_info[@]} -eq 0 ]]; then
            print_warning "起動可能なアプリがありません"
            echo ""
            print_info "管理メニューからIPAをインストールしてください"
            echo ""
            prompt_continue
            return 0  # Go to main menu
        fi
        
        # Get most recent app (only the latest one)
        local most_recent_bundle_id=""
        local recent_line=$(get_recent_apps 2>/dev/null | head -1)
        if [[ -n "$recent_line" ]]; then
            IFS='|' read -r timestamp bundle_id app_name <<< "$recent_line"
            most_recent_bundle_id="$bundle_id"
        fi
        
        # Sort apps: most recent first (if exists), then others
        local -a sorted_apps_info=()
        local most_recent_info=""
        
        # Find and add the most recent app first
        if [[ -n "$most_recent_bundle_id" ]]; then
            for app_info in "${apps_info[@]}"; do
                IFS='|' read -r app_name bundle_id app_path <<< "$app_info"
                if [[ "$bundle_id" == "$most_recent_bundle_id" ]]; then
                    sorted_apps_info+=("$app_info")
                    most_recent_info="$app_info"
                    break
                fi
            done
        fi
        
        # Add remaining apps
        for app_info in "${apps_info[@]}"; do
            if [[ "$app_info" != "$most_recent_info" ]]; then
                sorted_apps_info+=("$app_info")
            fi
        done
        
        # Display app list
        local index=1
        local -a app_names=()
        local -a bundle_ids=()
        local -a app_paths=()
        local recent_count=0
        
        for app_info in "${sorted_apps_info[@]}"; do
            IFS='|' read -r app_name bundle_id app_path <<< "$app_info"
            app_names+=("$app_name")
            bundle_ids+=("$bundle_id")
            app_paths+=("$app_path")
            
            # Check if this is the most recent app (only first one gets the star)
            local recent_mark=""
            if [[ $index -eq 1 ]] && [[ -n "$most_recent_bundle_id" ]] && [[ "$bundle_id" == "$most_recent_bundle_id" ]]; then
                recent_mark=" ⭐"
                recent_count=1
            fi
            
            # Get storage state
            local container_path=$(get_container_path "$bundle_id")
            local volume_name=$(get_volume_name_from_bundle_id "$bundle_id")
            local storage_mode=$(get_storage_mode "$container_path" "$volume_name")
            
            # Check sudo necessity
            local sudo_mark=""
            if needs_sudo_for_launch "$bundle_id" "$storage_mode"; then
                sudo_mark=" 🔐"
            fi
            
            # Status icons and messages
            local location_icon status_icon status_msg
            case "$storage_mode" in
                "external")
                    location_icon="🔌"
                    status_icon="●"
                    status_msg="Ready"
                    ;;
                "external_wrong_location")
                    location_icon="🔌"
                    status_icon="🔄"
                    status_msg="要再マウント"
                    ;;
                "internal_intentional"|"internal_contaminated")
                    location_icon="🏠"
                    status_icon="●"
                    status_msg="Ready"
                    ;;
                "internal_intentional_empty")
                    location_icon="🏠"
                    status_icon="📭"
                    status_msg="初期状態"
                    ;;
                "none")
                    if is_app_registered_as_external "$bundle_id"; then
                        location_icon="🔌"
                        status_icon="📦"
                        status_msg="未マウント"
                    else
                        location_icon="⚠️"
                        status_icon="❓"
                        status_msg="状態不明"
                    fi
                    ;;
            esac
            
            printf "  %d. %-25s [%s] %s %-12s%s%s\n" \
                "$index" "$app_name" "$location_icon" "$status_icon" "$status_msg" "$recent_mark" "$sudo_mark"
            ((index++))
        done
        
        echo ""
        if [[ $recent_count -gt 0 ]]; then
            echo "  ⭐ 最近使用（Enterで起動）    🔐 管理者権限が必要"
            echo ""
        fi
        print_separator
        if [[ $recent_count -gt 0 ]]; then
            echo "  [Enter] : ⭐付きアプリを起動"
        fi
        echo "  [1-${#sorted_apps_info[@]}] : アプリを起動"
        echo "  [p]   : PlayCoverを起動（設定変更用）"
        echo "  [m]   : 管理メニュー"
        echo "  [0]   : 終了"
        print_separator
        echo ""
        
        # User input
        read "choice?選択: "
        
        case "$choice" in
            "")
                # Empty input (Enter key) - launch most recent app if exists
                if [[ $recent_count -gt 0 ]] && [[ ${#app_names[@]} -gt 0 ]]; then
                    # Most recent app is always at index 0
                    local selected_name="${app_names[0]}"
                    local selected_bundle_id="${bundle_ids[0]}"
                    local selected_path="${app_paths[0]}"
                    
                    echo ""
                    local container_path=$(get_container_path "$selected_bundle_id")
                    local volume_name=$(get_volume_name_from_bundle_id "$selected_bundle_id")
                    local storage_mode=$(get_storage_mode "$container_path" "$volume_name")
                    
                    if launch_app "$selected_path" "$selected_name" "$selected_bundle_id" "$storage_mode"; then
                        # Success - return to quick launcher
                        echo ""
                        sleep 1
                        continue
                    else
                        # Failure - go to main menu
                        echo ""
                        print_warning "起動に失敗しました"
                        print_info "管理メニューで状態を確認してください"
                        echo ""
                        prompt_continue
                        return 0
                    fi
                else
                    # No recent app or invalid state
                    print_error "無効な選択です"
                    sleep 1
                    continue
                fi
                ;;
            0)
                exit 0
                ;;
            [pP])
                echo ""
                open_playcover_settings
                echo ""
                prompt_continue
                continue  # Redisplay quick launcher
                ;;
            [mM])
                return 0  # Go to main menu
                ;;
            [1-9]|[1-9][0-9])
                if [[ $choice -ge 1 ]] && [[ $choice -le ${#sorted_apps_info[@]} ]]; then
                    local selected_index=$((choice - 1))
                    local selected_name="${app_names[$selected_index]}"
                    local selected_bundle_id="${bundle_ids[$selected_index]}"
                    local selected_path="${app_paths[$selected_index]}"
                    
                    echo ""
                    local container_path=$(get_container_path "$selected_bundle_id")
                    local volume_name=$(get_volume_name_from_bundle_id "$selected_bundle_id")
                    local storage_mode=$(get_storage_mode "$container_path" "$volume_name")
                    
                    if launch_app "$selected_path" "$selected_name" "$selected_bundle_id" "$storage_mode"; then
                        # Success - return to quick launcher
                        echo ""
                        sleep 1
                        continue
                    else
                        # Failure - go to main menu for troubleshooting
                        echo ""
                        print_warning "起動に失敗しました"
                        print_info "管理メニューで状態を確認してください"
                        echo ""
                        prompt_continue
                        return 0  # Go to main menu
                    fi
                else
                    print_error "無効な選択です"
                    sleep 1
                    continue
                fi
                ;;
            *)
                print_error "無効な選択です"
                sleep 1
                continue
                ;;
        esac
    done
}

