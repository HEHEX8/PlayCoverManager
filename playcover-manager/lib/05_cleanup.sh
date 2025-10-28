#!/bin/zsh
#
# PlayCover Volume Manager - Module 05: Nuclear Cleanup
# ════════════════════════════════════════════════════════════════════
#
# This module provides complete system reset functionality:
# - Scan and preview all deletion targets
# - Unmount all mapped volumes
# - Delete all APFS volumes
# - Uninstall PlayCover app (both Homebrew and manual)
# - Delete all mapped containers (internal storage)
# - Delete mapping file
# - Two-step confirmation ("yes" + "DELETE ALL")
#
# ⚠️  WARNING: This is a DESTRUCTIVE operation with NO UNDO!
#
# Hidden Access: This function is accessed via special keys:
#   - X, x, RESET, reset in main menu
#
# Version: 5.0.0-alpha1
# Part of: Modular Architecture Refactoring

#######################################################
# Main Nuclear Cleanup Function
#######################################################

nuclear_cleanup() {
    clear
    print_separator "=" "$RED"
    echo ""
    echo "${RED}🔥 超強力クリーンアップ（完全リセット）🔥${NC}"
    echo ""
    print_separator "=" "$RED"
    echo ""
    
    #######################################################
    # Phase 1: Scan and collect deletion targets
    #######################################################
    
    echo "${CYAN}【フェーズ 1/2】削除対象をスキャンしています...${NC}"
    echo ""
    
    # Read mapping file and collect targets
    local mapped_volumes=()
    local mapped_containers=()
    
    if [[ -f "$MAPPING_FILE" ]]; then
        while IFS=$'\t' read -r volume_name bundle_id display_name; do
            [[ -z "$volume_name" ]] || [[ -z "$bundle_id" ]] && continue
            
            # Check if volume exists
            if volume_exists "$volume_name"; then
                local device=$(get_volume_device "$volume_name")
                if [[ -n "$device" ]]; then
                    mapped_volumes+=("${display_name:-$volume_name}|${volume_name}|${device}|${bundle_id}")
                fi
            fi
            
            # Check if container exists
            local container_path="${HOME}/Library/Containers/${bundle_id}"
            if [[ -d "$container_path" ]]; then
                mapped_containers+=("${display_name:-$bundle_id}|${container_path}")
            fi
        done < "$MAPPING_FILE"
    fi
    
    # Check PlayCover app
    local playcover_app_exists=false
    local playcover_homebrew=false
    if "$BREW_PATH" list --cask playcover-community &>/dev/null 2>&1; then
        playcover_app_exists=true
        playcover_homebrew=true
    elif [[ -d "/Applications/PlayCover.app" ]]; then
        playcover_app_exists=true
        playcover_homebrew=false
    fi
    
    # Check mapping file
    local mapping_exists=false
    if [[ -f "$MAPPING_FILE" ]]; then
        mapping_exists=true
    fi
    
    #######################################################
    # Display deletion preview
    #######################################################
    
    clear
    print_separator "=" "$RED"
    echo ""
    echo "${RED}🔥 削除対象の確認 🔥${NC}"
    echo ""
    print_separator "=" "$RED"
    echo ""
    
    local total_items=0
    
    # 1. Volumes to unmount and delete
    if [[ ${#mapped_volumes} -gt 0 ]]; then
        echo "${CYAN}【1】マップ登録ボリューム: ${#mapped_volumes}個${NC}"
        echo "     ${ORANGE}→ アンマウント後、削除されます${NC}"
        for vol_info in "${(@)mapped_volumes}"; do
            local display=$(echo "$vol_info" | /usr/bin/cut -d'|' -f1)
            local vol_name=$(echo "$vol_info" | /usr/bin/cut -d'|' -f2)
            local device=$(echo "$vol_info" | /usr/bin/cut -d'|' -f3)
            echo "  ${RED}💥${NC}  ${display}"
            echo "      ${ORANGE}${vol_name}${NC} (${device})"
            ((total_items++))
        done
        echo ""
    else
        echo "${CYAN}【1】マップ登録ボリューム: なし${NC}"
        echo ""
    fi
    
    # 2. PlayCover app
    echo "${CYAN}【2】PlayCoverアプリ${NC}"
    if [[ "$playcover_app_exists" == true ]]; then
        if [[ "$playcover_homebrew" == true ]]; then
            echo "  ${RED}🗑${NC}  PlayCover (Homebrew Cask)"
            echo "      ${ORANGE}brew uninstall --cask playcover-community${NC}"
        else
            echo "  ${RED}🗑${NC}  /Applications/PlayCover.app（手動インストール版）"
        fi
        ((total_items++))
    else
        echo "  ${GREEN}✅${NC}  インストールされていません"
    fi
    echo ""
    
    # 3. Mapped containers
    if [[ ${#mapped_containers} -gt 0 ]]; then
        echo "${CYAN}【3】マップ登録コンテナ（内蔵）: ${#mapped_containers}個${NC}"
        for container_info in "${(@)mapped_containers}"; do
            local display=$(echo "$container_info" | /usr/bin/cut -d'|' -f1)
            local container_path=$(echo "$container_info" | /usr/bin/cut -d'|' -f2)
            echo "  ${RED}🗑${NC}  ${display}"
            echo "      ${container_path}"
            ((total_items++))
        done
        echo ""
    else
        echo "${CYAN}【3】マップ登録コンテナ（内蔵）: なし${NC}"
        echo ""
    fi
    
    # 4. Mapping file
    echo "${CYAN}【4】マッピングファイル${NC}"
    if [[ "$mapping_exists" == true ]]; then
        echo "  ${RED}🗑${NC}  playcover-map.txt"
        ((total_items++))
    else
        echo "  ${GREEN}✅${NC}  存在しません（削除不要）"
    fi
    echo ""
    
    print_separator "─" "$YELLOW"
    echo ""
    echo "${ORANGE}合計削除項目: ${total_items}個${NC}"
    echo ""
    echo "${RED}⚠️  この操作は取り消せません！${NC}"
    echo ""
    echo "${CYAN}ℹ️  ゲームデータはアカウントに紐付いているため、再インストール後に復元できます${NC}"
    echo ""
    print_separator "─" "$YELLOW"
    echo ""
    
    # If nothing to delete
    if [[ $total_items -eq 0 ]]; then
        print_info "削除対象が見つかりません"
        wait_for_enter
        return
    fi
    
    #######################################################
    # Phase 2: Confirmation
    #######################################################
    
    # First confirmation
    if ! prompt_confirmation "上記の項目をすべて削除しますか？" "yes/no"; then
        print_info "$MSG_CANCELED"
        wait_for_enter
        return
    fi
    
    echo ""
    echo "${RED}⚠️  最終確認: 'DELETE ALL' と正確に入力してください:${NC} "
    read final_confirm
    
    if [[ "$final_confirm" != "DELETE ALL" ]]; then
        print_info "$MSG_CANCELED"
        wait_for_enter
        return
    fi
    
    echo ""
    print_separator "─" "$YELLOW"
    echo ""
    echo "${CYAN}【フェーズ 2/2】クリーンアップを実行します...${NC}"
    echo ""
    
    # Authenticate sudo
    authenticate_sudo
    
    #######################################################
    # Step 1: Unmount all mapped volumes
    #######################################################
    
    echo "${CYAN}【ステップ 1/5】マップ登録ボリュームをアンマウント${NC}"
    echo ""
    
    local unmount_count=0
    if [[ ${#mapped_volumes} -gt 0 ]]; then
        # Quit all running apps first
        for vol_info in "${(@)mapped_volumes}"; do
            local bundle_id=$(echo "$vol_info" | /usr/bin/cut -d'|' -f4)
            if [[ "$bundle_id" != "$PLAYCOVER_BUNDLE_ID" ]]; then
                quit_app_if_running "$bundle_id" 2>/dev/null || true
            fi
        done
        
        # Unmount volumes
        for vol_info in "${(@)mapped_volumes}"; do
            local display=$(echo "$vol_info" | /usr/bin/cut -d'|' -f1)
            local device=$(echo "$vol_info" | /usr/bin/cut -d'|' -f3)
            
            echo "  アンマウント中: ${display} (${device})"
            if unmount_volume "$device" "silent" "force"; then
                ((unmount_count++))
                print_success "  ✅ 完了"
            else
                print_warning "  失敗（既にアンマウント済み）"
            fi
        done
    else
        print_info "  アンマウント対象なし"
    fi
    
    print_success "ボリュームアンマウント完了: ${unmount_count}個"
    echo ""
    /bin/sleep 1
    
    #######################################################
    # Step 2: Delete all mapped volumes
    #######################################################
    
    echo "${CYAN}【ステップ 2/5】マップ登録ボリュームを削除${NC}"
    echo ""
    
    local volume_count=0
    if [[ ${#mapped_volumes} -gt 0 ]]; then
        for vol_info in "${(@)mapped_volumes}"; do
            local display=$(echo "$vol_info" | /usr/bin/cut -d'|' -f1)
            local vol_name=$(echo "$vol_info" | /usr/bin/cut -d'|' -f2)
            local device=$(echo "$vol_info" | /usr/bin/cut -d'|' -f3)
            
            echo "  削除中: ${display} (${device})"
            
            if /usr/bin/sudo /usr/sbin/diskutil apfs deleteVolume "$device" >/dev/null 2>&1; then
                print_success "  ✅ 削除完了"
                ((volume_count++))
            else
                print_warning "  削除失敗（マウント済みまたは保護されています）"
            fi
        done
    else
        print_info "  削除対象なし"
    fi
    
    print_success "APFSボリューム削除完了: ${volume_count}個"
    echo ""
    /bin/sleep 1
    
    #######################################################
    # Step 3: Uninstall PlayCover app
    #######################################################
    
    echo "${CYAN}【ステップ 3/5】PlayCoverアプリをアンインストール${NC}"
    echo ""
    
    if [[ "$playcover_app_exists" == true ]]; then
        if [[ "$playcover_homebrew" == true ]]; then
            echo "  アンインストール中: PlayCover (Homebrew Cask)"
            if "$BREW_PATH" uninstall --cask playcover-community >/dev/null 2>&1; then
                print_success "  ✅ Homebrewからアンインストール完了"
            else
                print_warning "  Homebrewアンインストール失敗"
            fi
        else
            echo "  削除中: /Applications/PlayCover.app（手動インストール版）"
        fi
        
        # Clean up manual installation remnants
        if [[ -d "/Applications/PlayCover.app" ]]; then
            if /usr/bin/sudo /bin/rm -rf "/Applications/PlayCover.app" 2>/dev/null; then
                print_success "  ✅ 削除完了"
            else
                print_warning "  削除失敗"
            fi
        fi
    else
        print_info "  アンインストール対象なし"
    fi
    
    echo ""
    /bin/sleep 1
    
    #######################################################
    # Step 4: Delete all mapped containers
    #######################################################
    
    echo "${CYAN}【ステップ 4/5】マップ登録コンテナ（内蔵）を削除${NC}"
    echo ""
    
    local container_count=0
    if [[ ${#mapped_containers} -gt 0 ]]; then
        for container_info in "${(@)mapped_containers}"; do
            local display=$(echo "$container_info" | /usr/bin/cut -d'|' -f1)
            local container_path=$(echo "$container_info" | /usr/bin/cut -d'|' -f2)
            
            echo "  削除中: ${display}"
            if /usr/bin/sudo /bin/rm -rf "$container_path" 2>/dev/null; then
                print_success "  ✅ 削除完了"
                ((container_count++))
            else
                print_warning "  削除失敗"
            fi
        done
    else
        print_info "  削除対象なし"
    fi
    
    print_success "コンテナ削除完了: ${container_count}個"
    echo ""
    /bin/sleep 1
    
    #######################################################
    # Step 5: Delete mapping file
    #######################################################
    
    echo "${CYAN}【ステップ 5/5】マッピングファイルを削除${NC}"
    echo ""
    
    if [[ "$mapping_exists" == true ]]; then
        echo "  削除中: playcover-map.txt"
        if /bin/rm -f "$MAPPING_FILE" 2>/dev/null; then
            print_success "  ✅ 削除完了"
        else
            print_warning "  ⚠️ 削除失敗"
        fi
        
        # Delete lock file if exists
        if [[ -d "$MAPPING_LOCK_FILE" ]]; then
            /bin/rmdir "$MAPPING_LOCK_FILE" 2>/dev/null || true
        fi
    else
        print_info "  削除対象なし"
    fi
    
    echo ""
    /bin/sleep 1
    
    #######################################################
    # Final summary
    #######################################################
    
    echo ""
    print_separator "=" "$GREEN"
    echo ""
    echo "${GREEN}✅ クリーンアップ完了${NC}"
    echo ""
    print_separator "=" "$GREEN"
    echo ""
    
    echo "${ORANGE}⚠️  重要: 再セットアップが必要です${NC}"
    echo ""
    echo "${CYAN}次のステップ:${NC}"
    echo ""
    echo "  ${LIGHT_GREEN}1.${NC} このツールを再起動"
    echo "      ${SKY_BLUE}→ 0_PlayCover-ManagementTool.command${NC}"
    echo ""
    echo "  ${LIGHT_GREEN}2.${NC} メニューから初期セットアップを実行"
    echo "      ${SKY_BLUE}→ [1] 初期セットアップ${NC}"
    echo ""
    echo "  ${LIGHT_GREEN}3.${NC} IPAインストールを実行"
    echo "      ${SKY_BLUE}→ [2] IPAインストール${NC}"
    echo ""
    echo "${ORANGE}📝 注意事項:${NC}"
    echo ""
    echo "  • ${RED}すべてのPlayCoverデータが削除されました${NC}"
    echo "  • ${RED}外部ボリュームも削除されました${NC}"
    echo "  • ${GREEN}ゲームデータはアカウントに紐付いているため復元できます${NC}"
    echo "  • 再インストール後、アカウントでログインしてください"
    echo ""
    print_separator "─" "$BLUE"
    echo ""
    echo "${CYAN}3秒後にターミナルを閉じます...${NC}"
    echo ""
    
    /bin/sleep 3
    exit_with_cleanup 0 "クリーンアップ完了"
}
