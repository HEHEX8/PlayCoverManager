#!/bin/zsh
#
# PlayCover Volume Manager - Main Entry Point
# File: main.sh
# Description: Load modules and start main execution loop
# Version: 5.0.0-alpha1
#

# Get script directory (absolute path)
SCRIPT_DIR="${0:A:h}"

# Load all modules in order
source "${SCRIPT_DIR}/lib/00_core.sh"
source "${SCRIPT_DIR}/lib/01_mapping.sh"
source "${SCRIPT_DIR}/lib/02_volume.sh"
source "${SCRIPT_DIR}/lib/03_storage.sh"
source "${SCRIPT_DIR}/lib/04_app.sh"
source "${SCRIPT_DIR}/lib/05_cleanup.sh"
source "${SCRIPT_DIR}/lib/06_setup.sh"
source "${SCRIPT_DIR}/lib/07_ui.sh"

#######################################################
# Main Execution Function
#######################################################

main() {
    # Clear screen to hide terminal session info
    clear
    
    # Check if PlayCover environment is ready
    if ! is_playcover_environment_ready; then
        run_initial_setup
        
        # Re-check after setup with debug mode
        if ! is_playcover_environment_ready "true"; then
            echo ""
            print_error "初期セットアップが完了しましたが、環境が正しく構成されていません"
            echo ""
            echo "${ORANGE}デバッグ情報（上記を確認してください）${NC}"
            wait_for_enter
            exit 1
        fi
    fi
    
    check_mapping_file
    
    # Clean up duplicate entries in mapping file
    deduplicate_mappings
    
    while true; do
        show_menu
        read choice
        
        case "$choice" in
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
                eject_disk
                ;;
            0)
                echo ""
                print_info "終了します"
                /bin/sleep 1
                /usr/bin/osascript -e 'tell application "Terminal" to close (every window whose name contains "playcover")' & exit 0
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
# Signal Handler (Ctrl+C)
#######################################################

trap 'echo ""; print_info "終了します"; /bin/sleep 1; /usr/bin/osascript -e '"'"'tell application "Terminal" to close (every window whose name contains "playcover")'"'"' & exit 0' INT

#######################################################
# Execute Main
#######################################################

main

# Explicit exit
exit 0
