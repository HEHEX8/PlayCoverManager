#!/bin/zsh
#
# PlayCover Volume Manager - メインエントリーポイント
# ファイル: main.sh
# 説明: モジュールを読み込み、メイン実行ループを開始
# バージョン: 5.2.0
#

#######################################################
# Single Instance Check
#######################################################

# Use a more reliable lock file approach
LOCK_DIR="${TMPDIR:-/tmp}"
LOCK_FILE="${LOCK_DIR}/playcover-manager-running.lock"

# Function to check if the lock is stale
is_lock_stale() {
    local lock_file=$1
    if [[ ! -f "$lock_file" ]]; then
        return 0  # No lock file = not stale
    fi
    
    local lock_pid=$(cat "$lock_file" 2>/dev/null)
    if [[ -z "$lock_pid" ]]; then
        return 0  # Empty lock = stale
    fi
    
    # Check if process exists
    if ps -p "$lock_pid" >/dev/null 2>&1; then
        return 1  # Process exists = not stale
    else
        return 0  # Process doesn't exist = stale
    fi
}

# Check for existing instance
if [[ -f "$LOCK_FILE" ]]; then
    if is_lock_stale "$LOCK_FILE"; then
        # Stale lock, remove it
        rm -f "$LOCK_FILE"
    else
        # Another instance is running
        echo "PlayCover Manager は既に実行中です"
        echo "既存のウィンドウを使用してください。"
        
        # Try to activate existing window
        osascript <<'EOF' 2>/dev/null
tell application "Terminal"
    activate
    repeat with w in windows
        if (name of w) contains "PlayCover" then
            set index of w to 1
            exit repeat
        end if
    end repeat
end tell
EOF
        exit 0
    fi
fi

# Create lock file with current PID
echo $$ > "$LOCK_FILE"

# Clean up lock on exit
cleanup_lock() {
    rm -f "$LOCK_FILE"
}

trap cleanup_lock EXIT INT TERM QUIT

#######################################################
# Load Modules
#######################################################

# スクリプトディレクトリを取得（絶対パス）
SCRIPT_DIR="${0:A:h}"

# Detect execution environment (for reference only)
# .command files run in Terminal with clean process tree
# .app bundle runs with parent process being launchd/Finder
# Note: Auto-close now works for both .command and .app versions
if [[ "$0" == *.command ]]; then
    export RUNNING_FROM_COMMAND=true
else
    export RUNNING_FROM_COMMAND=false
fi

# 全てのモジュールを順番に読み込み
source "${SCRIPT_DIR}/lib/00_core.sh"
source "${SCRIPT_DIR}/lib/01_mapping.sh"
source "${SCRIPT_DIR}/lib/02_volume.sh"
source "${SCRIPT_DIR}/lib/03_storage.sh"
source "${SCRIPT_DIR}/lib/04_app.sh"
source "${SCRIPT_DIR}/lib/05_cleanup.sh"
source "${SCRIPT_DIR}/lib/06_setup.sh"
source "${SCRIPT_DIR}/lib/07_ui.sh"

#######################################################
# メイン実行関数
#######################################################

main() {
    # ターミナルセッション情報を隠すため画面をクリア
    clear
    
    # Show startup sequence
    echo ""
    echo "${GREEN}PlayCover 統合管理ツール${NC}  ${SKY_BLUE}Version 5.2.0${NC}"
    echo ""
    echo "起動中..."
    echo ""
    
    # Step 1: データディレクトリ確認
    printf "  ${DIM_GRAY}1/6${NC} データディレクトリ確認"
    ensure_data_directory
    printf "\033[40G✅\n"
    
    # Step 2: PlayCover アプリ確認
    printf "  ${DIM_GRAY}2/6${NC} PlayCover アプリ確認"
    if [[ ! -d "/Applications/PlayCover.app" ]]; then
        printf "\033[40G⚠️\n"
        run_initial_setup
        
        # Re-check after setup
        if [[ ! -d "/Applications/PlayCover.app" ]]; then
            echo ""
            print_error "PlayCoverがインストールされていません"
            print_info "PlayCoverを /Applications にインストールしてください"
            echo ""
            wait_for_enter
            exit 1
        fi
    else
        printf "\033[40G✅\n"
    fi
    
    # Step 3: PlayCover ボリューム確認（キャッシュ版使用）
    printf "  ${DIM_GRAY}3/5${NC} PlayCover ボリューム確認"
    if ! volume_exists_cached "${PLAYCOVER_VOLUME_NAME}"; then
        printf "\033[40G⚠️\n"
        run_initial_setup
        
        # Re-check after setup
        if ! volume_exists_cached "${PLAYCOVER_VOLUME_NAME}"; then
            echo ""
            print_error "PlayCoverボリュームが作成されていません"
            print_info "セットアップを完了してください"
            echo ""
            wait_for_enter
            exit 1
        fi
        
    else
        printf "\033[40G✅\n"
    fi
    
    # Step 4: マッピングファイル確認・整理
    printf "  ${DIM_GRAY}4/5${NC} マッピングファイル確認"
    if [[ ! -f "$MAPPING_FILE" ]] || [[ ! -s "$MAPPING_FILE" ]] || ! /usr/bin/grep -q $'\t' "$MAPPING_FILE" 2>/dev/null; then
        printf "\033[40G⚠️\n"
        run_initial_setup
        
        # Re-check after setup
        if [[ ! -f "$MAPPING_FILE" ]] || [[ ! -s "$MAPPING_FILE" ]] || ! /usr/bin/grep -q $'\t' "$MAPPING_FILE" 2>/dev/null; then
            echo ""
            print_error "マッピングファイルが正しく構成されていません"
            print_info "セットアップを完了してください"
            echo ""
            wait_for_enter
            exit 1
        fi
    else
        printf "\033[40G✅\n"
    fi
    
    # マッピングファイルの重複を整理
    deduplicate_mappings
    
    # Step 5: マウント確認（キャッシュ版使用で高速化）
    printf "  ${DIM_GRAY}5/5${NC} PlayCover マウント確認"
    
    if volume_exists_cached "$PLAYCOVER_VOLUME_NAME"; then
        local playcover_mount=$(validate_and_get_mount_point_cached "$PLAYCOVER_VOLUME_NAME")
        if [[ -z "$playcover_mount" ]] || [[ "$playcover_mount" != "$PLAYCOVER_CONTAINER" ]]; then
            printf "\033[40G🔄\n"
            echo ""
            mount_app_volume "$PLAYCOVER_VOLUME_NAME" "$PLAYCOVER_CONTAINER" "$PLAYCOVER_BUNDLE_ID"
            echo ""
        else
            printf "\033[40G✅\n"
        fi
    else
        printf "\033[40G✅\n"
    fi
    
    echo ""
    echo "${GREEN}起動完了${NC}"
    echo ""
    
    # Preload all volume cache once before main menu loop
    # This eliminates cache loading delay when entering submenus
    preload_all_volume_cache
    
    # Preload storage free space caches (for all mode displays)
    get_storage_free_space_cached "$HOME" >/dev/null  # Internal storage
    get_external_drive_free_space_cached >/dev/null   # External storage
    
    # Preload launchable apps cache (no need to show scanning message)
    local -a launchable_apps=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && launchable_apps+=("$line")
    done < <(get_launchable_apps_cached)
    
    if [[ ${#launchable_apps} -gt 0 ]]; then
        # Quick launcher mode: show app list first
        show_quick_launcher
        # If returned (user pressed 'm' or launch failed), continue to main menu below
    fi
    
    while true; do
        # Update drive name cache only on first menu display (after quick launcher)
        if [[ "$DRIVE_NAME_CACHE_UPDATED" == "false" ]]; then
            cache_external_drive_name
            DRIVE_NAME_CACHE_UPDATED=true
        fi
        
        show_menu
        read choice
        
        case "$choice" in
            "")
                # Empty Enter - refresh cache and redisplay menu
                refresh_all_volume_caches
                ;;
            1)
                app_management_menu
                ;;
            2)
                individual_volume_control
                ;;
            3)
                switch_storage_location
                ;;
            4)
                show_quick_launcher
                ;;
            5)
                eject_disk
                ;;
            6)
                system_maintenance_menu
                ;;
            [qQ])
                clear
                echo ""
                print_info "終了しました"
                echo ""
                print_info "ウィンドウを自動的に閉じます..."
                /bin/sleep 0.5
                
                # Auto-close Terminal window for both .command and .app versions
                # Use window title-based approach for reliability
                osascript <<'CLOSE_WINDOW' >/dev/null 2>&1 &
tell application "Terminal"
    set windowClosed to false
    repeat with w in windows
        if (name of w) contains "PlayCover Manager" or (name of w) contains "playcover-manager" then
            close w
            set windowClosed to true
            exit repeat
        end if
    end repeat
    
    -- Fallback: if no window found by title, try closing frontmost window
    if not windowClosed then
        try
            close front window
        end try
    end if
end tell
CLOSE_WINDOW
                /bin/sleep 0.3
                
                exit 0
                ;;
            X|x|RESET|reset)
                echo ""
                print_warning "隠しオプション: 超強力クリーンアップ"
                /bin/sleep 1
                nuclear_cleanup
                ;;
            *)
                echo ""
                print_error "$MSG_INVALID_SELECTION"
                /bin/sleep 2
                ;;
        esac
    done
}

#######################################################
# Signal Handlers
#######################################################

# Graceful exit function
graceful_exit() {
    echo ""
    print_info "終了しました"
    echo ""
    print_info "ウィンドウを自動的に閉じます..."
    /bin/sleep 0.5
    
    # Auto-close Terminal window for both .command and .app versions
    # Use window title-based approach for reliability
    osascript <<'CLOSE_WINDOW' >/dev/null 2>&1 &
tell application "Terminal"
    set windowClosed to false
    repeat with w in windows
        if (name of w) contains "PlayCover Manager" or (name of w) contains "playcover-manager" then
            close w
            set windowClosed to true
            exit repeat
        end if
    end repeat
    
    -- Fallback: if no window found by title, try closing frontmost window
    if not windowClosed then
        try
            close front window
        end try
    end if
end tell
CLOSE_WINDOW
    /bin/sleep 0.3
    
    exit 0
}

# Handle Ctrl+C - show message and exit gracefully
trap 'graceful_exit' INT

#######################################################
# Execute Main
#######################################################

main

# Explicit exit
exit 0
