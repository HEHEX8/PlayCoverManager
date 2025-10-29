#!/bin/zsh
#######################################################
# PlayCover Manager
# macOS Sequoia 15.1+ Compatible
# Version: 5.1.0
#######################################################

#######################################################
# Version Information
#######################################################
# 
# v5.1.0 - Quick Launcher & Bug Fixes
# 
# 【開発履歴】
# Phase 1: 基本構造とコアモジュール ✅
# Phase 2: 全モジュール実装（8モジュール + main.sh） ✅
# Phase 3: 包括的検証（11段階すべてクリア） ✅
# Phase 4: 自動テストスイート（61テスト、100%パス率） ✅
# Phase 5: 関数共通化（重複パターンの統一・コード最適化） ✅
# Phase 6: 容量チェック・一時ディレクトリ管理の統一 ✅
# Phase 7: diskutil/volume/print/logging完全最適化 ✅
# Phase 8: volume操作の高レベル統一 ✅
#
# 【統計情報】
# - 総行数: 5,455行（-15行）
# - 関数数: 107関数（変更なし）
# - モジュール: 8モジュール + main.sh
# - テスト: 18テスト全パス（test-phase8.sh）
#
# 【Phase 8の改善内容】
# - get_volume_device_or_fail の活用: 1回 → 4回（4倍に拡大）
# - mount_app_volume: 11行 → 2行（ボリューム存在確認 + デバイス取得統一）
# - delete_app_volume: 9行 → 4行（早期リターン最適化）
# - eject_disk: 9行 → 4行（ネストしたif文を簡潔に）
# - 02_volume.sh: 504行 → 493行（11行削減）
#
# 【既存版との関係】
# - 安定版（v4.43.0）: 0_PlayCover-ManagementTool.command
# - モジュール版（v5.0.0-alpha5）: このファイル
# - 本番利用は安定版を推奨
#

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Execute main.sh (which loads all modules and runs the application)
exec "${SCRIPT_DIR}/main.sh"
