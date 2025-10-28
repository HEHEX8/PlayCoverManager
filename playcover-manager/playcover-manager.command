#!/bin/zsh
#######################################################
# PlayCover Manager (Modular Version)
# macOS Sequoia 15.1+ Compatible
# Version: 5.0.0-alpha2 (Modular Architecture)
#######################################################

#######################################################
# Version Information
#######################################################
# 
# v5.0.0-alpha2 - Phase 5完了: 関数共通化
# 
# 【開発履歴】
# Phase 1: 基本構造とコアモジュール ✅
# Phase 2: 全モジュール実装（8モジュール + main.sh） ✅
# Phase 3: 包括的検証（11段階すべてクリア） ✅
# Phase 4: 自動テストスイート（61テスト、100%パス率） ✅
# Phase 5: 関数共通化（重複パターンの統一・コード最適化） ✅
#
# 【統計情報】
# - 総行数: 5,196行（Phase 4から約110行削減）
# - 関数数: 91関数
# - モジュール: 8モジュール + main.sh
# - テスト: 全テストパス
#
# 【Phase 5の改善内容】
# - handle_error_and_return(): エラーハンドリングの統一（3箇所で使用）
# - prompt_confirmation(): 確認プロンプトの拡張（18箇所で使用、4形式対応）
# - コード削減: 約110行
#
# 【既存版との関係】
# - 安定版（v4.43.0）: 0_PlayCover-ManagementTool.command
# - モジュール版（v5.0.0-alpha2）: このファイル
# - 本番利用は安定版を推奨
#

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Execute main.sh (which loads all modules and runs the application)
exec "${SCRIPT_DIR}/main.sh"
