# Changelog

All notable changes to PlayCover Manager will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [5.0.0-alpha2] - 2025-01-29

### Fixed

#### ストレージ種別表示の完全統一
- **問題**: メインメニュー、アプリ管理、ボリューム情報、ストレージ切替で表示が食い違う
- **修正内容**: 
  - 全ての表示ロジックを `get_mount_point()` ベースに統一
  - 実際のマウント状況を直接確認する方式に変更
  - `get_storage_type()` の grep パターン依存を削減
- **影響範囲**: 
  - `lib/07_ui.sh`: 統計情報、アプリ一覧の判定ロジック
  - `lib/03_storage.sh`: ストレージ切替メニューの判定ロジック
- **結果**: 全ての画面で一貫したストレージ種別表示

#### 初期セットアップのUX改善
- **問題**: Enter押下が多すぎる（8回必要）、無効な入力で終了
- **修正内容**:
  - 不要な Enter 待機を削除（情報表示後は自動継続）
  - ディスク選択で無効な入力時に再試行ループを実装
  - より詳細なエラーメッセージを表示
- **影響範囲**: `lib/06_setup.sh`
- **結果**: スムーズなセットアップ体験

### Technical Details

#### 判定ロジックの統一
```bash
# 統一後のロジック（全画面共通）
local actual_mount=$(get_mount_point "$volume_name")
if [[ -n "$actual_mount" ]] && [[ "$actual_mount" == "$target_path" ]]; then
    # 正しい位置にマウント = 外部ストレージ
else
    # 未マウント or 位置異常
fi
```

#### 修正ファイル
- `lib/03_storage.sh`: ストレージ切替メニュー
- `lib/06_setup.sh`: 初期セットアップフロー
- `lib/07_ui.sh`: メインメニュー、アプリ管理

## [5.0.0-alpha1] - 2025-01-28

### Added
- モジュール化されたアーキテクチャ
- 完全な日本語UI
- DMGインストーラー対応
- 外部ストレージ管理機能
- ストレージ切替機能（内蔵⇄外部）
- バッチ操作（一括マウント/アンマウント）
- クリーンアップ機能

### Changed
- Bash から Zsh に移行
- モノリシックから8モジュール構成に分割
- カラースキーム最適化（RGB 28,28,28 背景対応）

### Technical
- Apple Silicon 専用
- macOS Sequoia 15.1+ 対応
- APFS ボリューム管理
- PlayCover 3.0+ 対応
