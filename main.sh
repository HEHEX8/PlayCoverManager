#!/bin/zsh
#
# PlayCover Volume Manager - メインエントリーポイント
# ファイル: main.sh
# 説明: モジュールを読み込み、メイン実行ループを開始
# バージョン: 5.0.1
#

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
    
    # Ensure data directory exists (before any file operations)
    ensure_data_directory
    
    # PlayCover環境が準備できているか確認
    if ! is_playcover_environment_ready; then
        run_initial_setup
        
        # Re-check after setup
        if ! is_playcover_environment_ready; then
            echo ""
            print_error "初期セットアップが完了しましたが、環境が正しく構成されていません"
            print_info "PlayCoverが正しくインストールされているか確認してください"
            echo ""
            wait_for_enter
            exit 1
        fi
    fi
    

    # Clean up duplicate entries in mapping file
    deduplicate_mappings
    
    # Check and mount PlayCover volume if needed (before checking launchable apps)
    if volume_exists "$PLAYCOVER_VOLUME_NAME"; then
        local playcover_mount=$(get_mount_point "$PLAYCOVER_VOLUME_NAME")
        if [[ -z "$playcover_mount" ]] || [[ "$playcover_mount" != "$PLAYCOVER_CONTAINER" ]]; then
            # Show message before mounting (sudo will prompt for password)
            echo ""
            print_info "PlayCoverボリュームをマウントしています..."
            echo ""
            mount_app_volume "$PLAYCOVER_VOLUME_NAME" "$PLAYCOVER_CONTAINER" "$PLAYCOVER_BUNDLE_ID"
        fi
    fi
    
    # Show quick launcher if launchable apps exist
    local -a launchable_apps=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && launchable_apps+=("$line")
    done < <(get_launchable_apps)
    
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
            0)
                clear
                # Close Terminal window using AppleScript
                osascript -e 'tell application "Terminal" to close first window' & exit 0
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
    print_info "終了します"
    /bin/sleep 1
    
    # Close all PlayCover-related Terminal windows
    /usr/bin/osascript -e 'tell application "Terminal" to close (every window whose name contains "playcover")' 2>/dev/null &
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
