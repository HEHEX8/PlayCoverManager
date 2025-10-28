# PlayCover Manager

macOS用PlayCover統合管理ツール - モジュラーアーキテクチャ版

[![Platform](https://img.shields.io/badge/platform-macOS-lightgrey)](https://www.apple.com/macos/)
[![Language](https://img.shields.io/badge/language-Zsh-orange)](https://www.zsh.org/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

---

## 🚀 バージョン情報

### モジュラー版: v5.0.0-alpha1（Phase 4完了）
- **ディレクトリ**: `playcover-manager/`
- **状態**: ✅ Phase 4完了（全機能実装・包括的テスト・自動テストスイート完備）
- **統計**: 5,624行、91関数、8モジュール + main.sh
- **テスト**: 61テスト、100%パス率
- **言語**: 日本語のみ

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

### Phase 4完了状態

✅ **Phase 1**: 基本構造とコアモジュール  
✅ **Phase 2**: 全モジュール実装（8モジュール + main.sh）  
✅ **Phase 3**: 包括的検証（11段階すべてクリア）  
✅ **Phase 4**: 自動テストスイート（61テスト、100%パス率）

### モジュール構成

```
playcover-manager/
├── main.sh (101行)              # メインエントリーポイント
└── lib/
    ├── 00_core.sh (458行)      # コア機能（13関数）
    ├── 01_mapping.sh (172行)   # マッピング管理（9関数）
    ├── 02_volume.sh (505行)    # ボリューム操作（14関数）
    ├── 03_storage.sh (1207行)  # ストレージ管理（17関数）
    ├── 04_app.sh (1106行)      # アプリ管理（25関数）
    ├── 05_cleanup.sh (404行)   # クリーンアップ（3関数）
    ├── 06_setup.sh (471行)     # 初期セットアップ（8関数）
    └── 07_ui.sh (900行)        # UIとメニュー（13関数）
```

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

**最終更新**: 2025年10月28日（v5.0.0-alpha1 Phase 4完了、v4.43.0安定版）
