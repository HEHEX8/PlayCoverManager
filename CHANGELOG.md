# Changelog

All notable changes to PlayCover Manager will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [5.0.0] - 2025-01-29

### Fixed

#### ストレージ種別表示の完全統一（Critical Bug Fix）
- **問題**: メインメニュー、アプリ管理、ボリューム情報、ストレージ切替で表示が食い違う重大なバグ
- **症状**: 
  - ボリューム情報: 正しく「マウント済」と表示
  - アプリ管理: 誤って「内部」と表示
  - ストレージ切替: 誤って「データ無し」または「マウント位置異常」と表示
- **根本原因**: 
  - ボリューム情報は `get_mount_point()` で実際のマウント状況を確認
  - アプリ管理とストレージ切替は `get_storage_type()` でパスをチェック
  - `get_storage_type()` の `/sbin/mount` grep パターンが正しく動作しない環境があった
- **修正内容**: 
  - 全ての表示ロジックを `get_mount_point()` ベースに統一
  - 実際のマウント状況を直接確認する方式に変更
  - ボリューム情報と同じ判定ロジックを全画面で使用
- **影響範囲**: 
  - `lib/07_ui.sh`: 統計情報、アプリ一覧の判定ロジック（2箇所）
  - `lib/03_storage.sh`: ストレージ切替メニューの判定ロジック、パス正規化
- **結果**: 全ての画面で一貫したストレージ種別表示を実現

#### 初期セットアップのUX改善
- **問題**: Enter押下が多すぎる（8回必要）、無効な入力でスクリプトが終了
- **修正内容**:
  - 不要な Enter 待機を削除（情報表示後は自動継続）
  - ディスク選択で無効な入力時に再試行ループを実装
  - より詳細なエラーメッセージを表示（「1〜N の数字を入力してください」）
- **影響範囲**: `lib/06_setup.sh`
- **結果**: スムーズで直感的なセットアップ体験

### Technical Details

#### 判定ロジックの統一（全画面共通）
```bash
# 統一後のロジック
local actual_mount=$(get_mount_point "$volume_name")
if [[ -n "$actual_mount" ]] && [[ "$actual_mount" == "$target_path" ]]; then
    # 正しい位置にマウント = 外部ストレージ
    status="🔌 外部"
elif [[ -n "$actual_mount" ]]; then
    # 間違った位置にマウント
    status="⚠️  位置異常"
else
    # 未マウント = 内部ストレージをチェック
    storage_mode=$(get_storage_mode "$target_path" "$volume_name")
    # ...
fi
```

#### 修正コミット
- `5c0faaf`: 初期セットアップのUX改善とストレージ種別表示の統一（第1弾）
- `f5482c1`: ストレージ種別表示ロジックをボリューム情報と統一（第2弾）
- `2776123`: ストレージ切替の表示ロジックをボリューム情報と完全統一（第3弾）

#### 修正ファイル
- `lib/03_storage.sh`: ストレージ切替メニューの完全書き換え、パス正規化
- `lib/06_setup.sh`: 初期セットアップフロー、再試行ロジック
- `lib/07_ui.sh`: メインメニュー統計情報、アプリ管理一覧

### Upgrade Notes

alpha2 からの変更点:
- バグ修正のみでAPIや設定の変更なし
- 既存のマッピングファイルやボリュームはそのまま使用可能
- アップグレード後も通常通り動作

## [5.0.1] - 2025-01-29

### Added
- 初回リリース候補版
- モジュラーアーキテクチャへの完全リファクタリング完了

## [5.0.0] - 2025-01-28

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
