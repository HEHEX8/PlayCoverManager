#!/bin/zsh
#######################################################
# PlayCover Manager (Modular Version)
# macOS Sequoia 15.1+ Compatible
# Version: 5.0.0-alpha4 (Modular Architecture)
#######################################################

#######################################################
# Version Information
#######################################################
# 
# v5.0.0-alpha4 - Phase 7完了: diskutil/volume/print/logging完全最適化
# 
# 【開発履歴】
# Phase 1: 基本構造とコアモジュール ✅
# Phase 2: 全モジュール実装（8モジュール + main.sh） ✅
# Phase 3: 包括的検証（11段階すべてクリア） ✅
# Phase 4: 自動テストスイート（61テスト、100%パス率） ✅
# Phase 5: 関数共通化（重複パターンの統一・コード最適化） ✅
# Phase 6: 容量チェック・一時ディレクトリ管理の統一 ✅
# Phase 7: diskutil/volume/print/logging完全最適化 ✅
#
# 【統計情報】
# - 総行数: 5,470行（+217行）
# - 関数数: 107関数（+13関数）
# - モジュール: 8モジュール + main.sh
# - テスト: 17テスト全パス（test-phase7.sh）
#
# 【Phase 7の改善内容】
# - diskutilラッパー関数: 4関数（mount point, device node, disk name, location）
# - 高レベルvolume操作: 2関数（get_volume_device_or_fail, ensure_volume_mounted）
# - print関数改良: 5関数（_lnバージョンで自動改行対応）
# - ログ出力関数: 2関数（print_debug, print_verbose）
# - diskutilパース処理の削減: 17箇所 → 2箇所（88%削減）
#
# 【既存版との関係】
# - 安定版（v4.43.0）: 0_PlayCover-ManagementTool.command
# - モジュール版（v5.0.0-alpha4）: このファイル
# - 本番利用は安定版を推奨
#

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Execute main.sh (which loads all modules and runs the application)
exec "${SCRIPT_DIR}/main.sh"
