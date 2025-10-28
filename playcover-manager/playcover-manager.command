#!/bin/zsh
#######################################################
# PlayCover Manager (Modular Version)
# macOS Sequoia 15.1+ Compatible
# Version: 5.0.0-alpha3 (Modular Architecture)
#######################################################

#######################################################
# Version Information
#######################################################
# 
# v5.0.0-alpha3 - Phase 6完了: 容量チェック・一時ディレクトリ管理の統一
# 
# 【開発履歴】
# Phase 1: 基本構造とコアモジュール ✅
# Phase 2: 全モジュール実装（8モジュール + main.sh） ✅
# Phase 3: 包括的検証（11段階すべてクリア） ✅
# Phase 4: 自動テストスイート（61テスト、100%パス率） ✅
# Phase 5: 関数共通化（重複パターンの統一・コード最適化） ✅
# Phase 6: 容量チェック・一時ディレクトリ管理の統一 ✅
#
# 【統計情報】
# - 総行数: 5,253行
# - 関数数: 94関数（+3関数）
# - モジュール: 8モジュール + main.sh
# - テスト: 13テスト全パス（test-phase6.sh）
#
# 【Phase 6の改善内容】
# - get_available_space(): 容量チェックの統一（5箇所で使用）
# - get_directory_size(): ディレクトリサイズ取得の統一（5箇所で使用）
# - create_temp_dir(): 一時ディレクトリ作成の統一（3箇所で使用）
#
# 【既存版との関係】
# - 安定版（v4.43.0）: 0_PlayCover-ManagementTool.command
# - モジュール版（v5.0.0-alpha3）: このファイル
# - 本番利用は安定版を推奨
#

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Execute main.sh (which loads all modules and runs the application)
exec "${SCRIPT_DIR}/main.sh"
