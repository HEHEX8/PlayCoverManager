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
    printf "  ${DIM_GRAY}1/6${NC} データディレクトリ確認...     "
    ensure_data_directory
    echo "✅"
    
    # Step 2: PlayCover アプリ確認
    printf "  ${DIM_GRAY}2/6${NC} PlayCover アプリ確認...        "
    if [[ ! -d "/Applications/PlayCover.app" ]]; then
        echo "⚠️"
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
        echo "✅"
    fi
    
    # Step 3: ボリューム情報キャッシュ（以降のチェックを高速化）
    printf "  ${DIM_GRAY}3/6${NC} ボリューム情報キャッシュ...   "
    preload_all_volume_cache
    echo "✅"
    
    # Step 4: PlayCover ボリューム確認
    printf "  ${DIM_GRAY}4/6${NC} PlayCover ボリューム確認...   "
    if ! volume_exists "${PLAYCOVER_VOLUME_NAME}"; then
        echo "⚠️"
        run_initial_setup
        
        # Re-check after setup
        if ! volume_exists "${PLAYCOVER_VOLUME_NAME}"; then
            echo ""
            print_error "PlayCoverボリュームが作成されていません"
            print_info "セットアップを完了してください"
            echo ""
            wait_for_enter
            exit 1
        fi
        
        # Refresh cache after volume creation
        preload_all_volume_cache
    else
        echo "✅"
    fi
    
    # Step 5: マッピングファイル確認・整理
    printf "  ${DIM_GRAY}5/6${NC} マッピングファイル確認...     "
    if [[ ! -f "$MAPPING_FILE" ]] || [[ ! -s "$MAPPING_FILE" ]] || ! /usr/bin/grep -q $'\t' "$MAPPING_FILE" 2>/dev/null; then
        echo "⚠️"
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
        echo "✅"
    fi
    
    # マッピングファイルの重複を整理
    deduplicate_mappings
    
    # Step 6: デバイス名キャッシュとマウント確認
    printf "  ${DIM_GRAY}6/6${NC} PlayCover マウント確認...     "
    cache_external_drive_name  # Cache device name for menu display
    
    if volume_exists "$PLAYCOVER_VOLUME_NAME"; then
        local playcover_mount=$(get_mount_point "$PLAYCOVER_VOLUME_NAME")
        if [[ -z "$playcover_mount" ]] || [[ "$playcover_mount" != "$PLAYCOVER_CONTAINER" ]]; then
            echo "🔄"
            echo ""
            mount_app_volume "$PLAYCOVER_VOLUME_NAME" "$PLAYCOVER_CONTAINER" "$PLAYCOVER_BUNDLE_ID"
            echo ""
        else
            echo "✅"
        fi
    else
        echo "✅"
    fi
    
    echo ""
    echo "${GREEN}起動完了${NC}"
    echo ""
    
    # Show quick launcher if launchable apps exist
    printf "アプリケーションをスキャン中... "
    local -a launchable_apps=()
    local scan_start=$(date +%s)
    while IFS= read -r line; do
        [[ -n "$line" ]] && launchable_apps+=("$line")
    done < <(get_launchable_apps)
    local scan_end=$(date +%s)
    local scan_time=$((scan_end - scan_start))
    
    printf "\r%*s\r" 50 ""  # Clear scan message
    
    if [[ ${#launchable_apps[@]} -gt 0 ]]; then
        # Quick launcher mode: show app list first
        show_quick_launcher
        # If returned (user pressed 'm' or launch failed), continue to main menu below
    fi
    
    while true; do
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
                echo "${DIM_GRAY}このウィンドウを閉じるには: ${CYAN}⌘ + W${NC}"
                echo ""
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
    echo "${DIM_GRAY}このウィンドウを閉じるには: ${CYAN}⌘ + W${NC}"
    echo ""
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
