# PlayCover Manager

macOS用PlayCover統合管理ツール - モジュラーアーキテクチャ版

[![Platform](https://img.shields.io/badge/platform-macOS-lightgrey)](https://www.apple.com/macos/)
[![Language](https://img.shields.io/badge/language-Zsh-orange)](https://www.zsh.org/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

---

## 🚀 バージョン情報

### モジュラー版: v5.0.0-alpha4（Phase 7完了）
- **ディレクトリ**: `playcover-manager/`
- **状態**: ✅ Phase 7完了（diskutil/volume/print/logging完全最適化）
- **統計**: 5,470行、107関数、8モジュール + main.sh
- **テスト**: 17テスト全パス（test-phase7.sh）
- **言語**: 日本語のみ
- **最適化**: 
  - Phase 5: エラーハンドリング・確認プロンプトの共通化（約110行削減）
  - Phase 6: 容量チェック・一時ディレクトリ管理の統一（5箇所で使用）
  - Phase 7: diskutil/volume/print/logging統一（+13関数、15箇所最適化）

### 統合版: v4.43.0（安定版・推奨）
- **ファイル**: `0_PlayCover-ManagementTool.command`
- **状態**: ✅ 安定版・本番利用推奨
- **サイズ**: 約5,380行の統合スクリプト

**推奨**: 本番環境では安定版（v4.43.0）を使用してください。

---

## 📖 概要

PlayCover Managerは、macOS上でiOSゲームを動作させる「PlayCover」のボリューム・ストレージ管理を効率化するツールです。

### 🎮 主な機能

1. **APFSボリューム管理**
   - 外部ディスクへのゲーム専用ボリューム作成
   - マウント/アンマウント操作
   - nobrowse設定（Finderに表示させない）

2. **ストレージ切替**
   - 内蔵ストレージ ⇄ 外部ストレージの双方向切替
   - rsyncベースの差分同期・完全コピー
   - フラグファイルによる状態管理

3. **アプリ管理**
   - IPAファイルのインストール（単一・複数・バッチモード）
   - アプリのアンインストール（個別・一括）
   - 日本語アプリ名対応

4. **クリーンアップ機能**
   - 完全リセット（隠しオプション: X/x/RESET/reset）
   - すべてのボリューム・コンテナを削除
   - PlayCover本体のアンインストール

---

## 🏗️ モジュラーアーキテクチャ（v5.0.0-alpha1）

### Phase 7完了状態

✅ **Phase 1**: 基本構造とコアモジュール  
✅ **Phase 2**: 全モジュール実装（8モジュール + main.sh）  
✅ **Phase 3**: 包括的検証（11段階すべてクリア）  
✅ **Phase 4**: 自動テストスイート（61テスト、100%パス率）  
✅ **Phase 5**: 関数共通化（重複パターンの統一・コード最適化）  
✅ **Phase 6**: 容量チェック・一時ディレクトリ管理の統一  
✅ **Phase 7**: diskutil/volume/print/logging完全最適化

### モジュール構成

```
playcover-manager/
├── main.sh (101行)              # メインエントリーポイント
├── test-phase7.sh               # テストスイート（17テスト）
└── lib/
    ├── 00_core.sh (772行)      # コア機能（41関数）← Phase 7: +13関数
    ├── 01_mapping.sh (166行)   # マッピング管理（8関数）
    ├── 02_volume.sh (504行)    # ボリューム操作（14関数）
    ├── 03_storage.sh (1169行)  # ストレージ管理（14関数）
    ├── 04_app.sh (1090行)      # アプリ管理（11関数）
    ├── 05_cleanup.sh (402行)   # クリーンアップ（1関数）
    ├── 06_setup.sh (491行)     # 初期セットアップ（12関数）
    └── 07_ui.sh (775行)        # UIとメニュー（6関数）
```

### Phase 5の改善内容

**新規追加関数:**
- `handle_error_and_return()`: エラー表示 + 待機 + returnを1つに統一
- `prompt_confirmation()`: 確認プロンプトを拡張（4つの形式に対応）
  - `Y/n`: デフォルトYes
  - `y/N`: デフォルトNo
  - `yes/NO`: 危険操作（明示的に"yes"入力必須）
  - `yes/no`: 最危険操作（明示的に"yes"入力必須、デフォルトなし）

**コード削減:**
- エラーハンドリングパターン: 3箇所を統一（約40行削減）
- 確認プロンプトパターン: 10箇所を統一（約70行削減）
- **総削減量**: 約110行

### Phase 6の改善内容

**新規追加関数:**
- `get_available_space()`: ディスク空き容量を取得（5箇所で使用）
- `get_directory_size()`: ディレクトリサイズを取得（5箇所で使用）
- `create_temp_dir()`: 一時ディレクトリを安全に作成（3箇所で使用）

**コード統一:**
- 容量チェックパターン: `df -k | tail | awk` → `get_available_space()`
- ディレクトリサイズ: `du -sk | awk` → `get_directory_size()`
- 一時ディレクトリ作成: `mktemp -d` → `create_temp_dir()`

**テストスイート:**
- `test-phase6.sh`: 13テスト全パス
- 関数存在チェック、使用箇所確認、構文チェック

### Phase 7の改善内容

**新規追加関数（13関数）:**

1. **diskutil infoラッパー関数（4関数）**:
   - `get_volume_mount_point()`: マウントポイント取得
   - `get_volume_device_node()`: デバイスノード取得
   - `get_disk_name()`: ディスク名取得
   - `get_disk_location()`: ディスク位置（Internal/External）取得

2. **高レベルvolume操作（2関数）**:
   - `get_volume_device_or_fail()`: ボリューム存在確認 + デバイス取得を統合
   - `ensure_volume_mounted()`: ボリュームのマウント状態を保証

3. **print関数の改良（5関数）**:
   - `print_success_ln()`: 成功メッセージ + 自動改行
   - `print_error_ln()`: エラーメッセージ + 自動改行
   - `print_warning_ln()`: 警告メッセージ + 自動改行
   - `print_info_ln()`: 情報メッセージ + 自動改行
   - `print_highlight_ln()`: ハイライトメッセージ + 自動改行

4. **ログ出力関数（2関数）**:
   - `print_debug()`: DEBUG=1時のみ出力
   - `print_verbose()`: VERBOSE=1時のみ出力

**コード統一の成果:**
- diskutilパース処理: 17箇所 → 2箇所（88%削減）
- 新関数の使用回数: 20回（5モジュールで活用）
- 戦略的な置き換え: リスク評価により11箇所を厳選して最適化

**テストスイート:**
- `test-phase7.sh`: 17テスト全パス
- 13個の新関数すべて検証済み
- 使用箇所カウント、パターン削減、構文チェック

### テストスイート

```
tests/
├── run_all_tests.sh           # テスト実行スクリプト
├── test_lib.sh                # テストフレームワーク
├── test_functions_exist.sh    # 関数存在チェック
└── test_01_mapping.sh         # マッピング機能テスト
```

**テスト結果**: 61テスト、100%パス率  
- 関数存在チェック: 91関数すべて検証済み
- 重複関数チェック: 0件（クリーン）
- 未定義関数チェック: 0件（すべて定義済み）
- 未宣言変数チェック: 0件（すべて宣言済み）

---

## 🚀 使用方法

### 統合版（推奨）

```bash
# ダブルクリックで実行
0_PlayCover-ManagementTool.command
```

### モジュラー版（開発版）

```bash
# ダブルクリックで実行
playcover-manager/playcover-manager.command

# または直接実行
playcover-manager/main.sh
```

---

## 📂 プロジェクト構造

```
/home/user/webapp/
├── README.md                              # メインドキュメント
├── README-EN.md                           # English documentation
├── CHANGELOG.md                           # 変更履歴
├── CHANGELOG-EN.md                        # English changelog
├── 0_PlayCover-ManagementTool.command     # 安定版 v4.43.0
├── 0_PlayCover-ManagementTool-EN.command  # English version
├── playcover-debug-detector.command       # Debug utility
└── playcover-manager/                     # モジュラー版 v5.0.0-alpha1
    ├── lib/                               # 8 modules
    ├── tests/                             # Test suite
    ├── main.sh                            # Main entry point
    └── playcover-manager.command          # Wrapper script
```

---

## ⚠️ 注意事項

### 必須要件
- Apple Silicon Mac（M1/M2/M3/M4シリーズ）
- macOS Sequoia 15.1+ (Tahoe 26.0.1以降)
- フルディスクアクセス権限（ターミナル.app）
- 外部ストレージ（USB/Thunderbolt/SSD）

### 推奨事項
- PlayCover使用時は必ずボリュームをマウント
- Mac終了前には必ずボリュームをアンマウント
- 外部ストレージ取り外し前に「ディスク全体を取り外し」を実行

---

## 🔗 関連リンク

- **GitHub**: https://github.com/HEHEX8/PlayCoverManager
- **PlayCover Community**: https://github.com/PlayCover/PlayCover

---

## 📝 ライセンス

このプロジェクトは個人利用および学習目的で作成されました。

---

**最終更新**: 2025年10月28日（v5.0.0-alpha4 Phase 7完了、v4.43.0安定版）
