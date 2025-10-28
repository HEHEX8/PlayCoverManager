#!/bin/zsh
#######################################################
# PlayCover Manager (Modular Version)
# macOS Sequoia 15.1+ Compatible
# Version: 5.0.0-alpha1 (Modular Architecture)
#######################################################

#######################################################
# Version Information
#######################################################
# 
# v5.0.0-alpha1 - Modular Architecture
# - 旧版（0_PlayCover-ManagementTool.command）を段階的にモジュール化
# - 7つのモジュールに分割（core, mapping, volume, storage, app, cleanup, setup, ui）
# - 保守性・テスト性・拡張性の向上
# - 段階的移行中：現在はスケルトン状態
#
# 【既存版との関係】
# - 既存版（v4.43.0）は引き続き利用可能
# - モジュール化版は並行開発中
# - 完成後に既存版をアーカイブ
#

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load modules in order
source "${SCRIPT_DIR}/lib/00_core.sh"
source "${SCRIPT_DIR}/lib/01_mapping.sh"
source "${SCRIPT_DIR}/lib/02_volume.sh"
source "${SCRIPT_DIR}/lib/03_storage.sh"
source "${SCRIPT_DIR}/lib/04_app.sh"
source "${SCRIPT_DIR}/lib/05_cleanup.sh"
source "${SCRIPT_DIR}/lib/06_setup.sh"
source "${SCRIPT_DIR}/lib/07_ui.sh"

#######################################################
# Main Execution
#######################################################

main() {
    # Clear screen
    clear
    
    print_header "PlayCover Manager (Modular Version)"
    print_warning "🚧 開発中: モジュール化版 v5.0.0-alpha1"
    echo ""
    print_info "この版は開発中です。本番利用には既存版を使用してください："
    print_info "  ${SCRIPT_DIR}/../0_PlayCover-ManagementTool.command"
    echo ""
    print_info "モジュール構成:"
    echo "  ✅ 00_core.sh      - コア機能（完成）"
    echo "  🚧 01_mapping.sh   - マッピング管理（未実装）"
    echo "  🚧 02_volume.sh    - ボリューム操作（未実装）"
    echo "  🚧 03_storage.sh   - ストレージ管理（未実装）"
    echo "  🚧 04_app.sh       - アプリ管理（未実装）"
    echo "  🚧 05_cleanup.sh   - クリーンアップ（未実装）"
    echo "  🚧 06_setup.sh     - 初期セットアップ（未実装）"
    echo "  🚧 07_ui.sh        - UIとメニュー（未実装）"
    echo ""
    
    print_separator
    echo ""
    
    # Test core functions
    print_success "コアモジュールが正常に読み込まれました"
    print_info "基本的な色とprint関数が動作しています"
    print_warning "残りのモジュールは段階的に実装予定"
    print_error "エラー表示のテスト"
    print_highlight "ハイライト表示のテスト"
    
    echo ""
    print_separator
    echo ""
    
    # Show module status
    print_bold "【実装状況】"
    echo ""
    echo "フェーズ1: 基本構造の作成 ✅"
    echo "  - ディレクトリ構造作成"
    echo "  - コアモジュール完成"
    echo "  - スケルトンモジュール作成"
    echo "  - メインエントリーポイント作成"
    echo ""
    echo "フェーズ2: 段階的移行 🚧"
    echo "  - 各モジュールに関数を移行（未着手）"
    echo "  - テストしながら進める"
    echo "  - 旧版と新版を並行維持"
    echo ""
    echo "フェーズ3: 完全移行 ⏳"
    echo "  - 全機能移行完了後、旧版をアーカイブ"
    echo ""
    
    print_separator
    echo ""
    
    wait_for_enter
}

# Trap Ctrl+C
trap 'echo ""; print_info "終了します"; exit 0' INT

# Execute main
main

# Explicit exit
exit 0
