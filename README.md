# PlayCover Manager

<div align="center">

[![Latest Release](https://img.shields.io/github/v/release/HEHEX8/PlayCoverManager?label=version)](https://github.com/HEHEX8/PlayCoverManager/releases/latest)
![Platform](https://img.shields.io/badge/platform-macOS%20Sequoia%2015.1%2B-lightgrey.svg)
![Architecture](https://img.shields.io/badge/architecture-Apple%20Silicon-orange.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

**APFS Volume Management Tool for PlayCover**

[English](README-EN.md) | 日本語

</div>

---

## 🎉 最新リリース

[![GitHub Release](https://img.shields.io/github/v/release/HEHEX8/PlayCoverManager?style=for-the-badge&logo=github)](https://github.com/HEHEX8/PlayCoverManager/releases/latest)

最新版のダウンロードは [Releases](https://github.com/HEHEX8/PlayCoverManager/releases/latest) から。

---

## 📖 概要

PlayCover Manager は、PlayCover で実行する iOS アプリのデータを外部ストレージに移行・管理するための macOS 専用ツールです。APFS ボリュームの作成・マウント管理を自動化し、内蔵ストレージの容量を節約します。

### 💡 なぜ v5.0.0 から？

このツールは個人用スクリプトとして始まり、何度も改良を重ねてきました。v5.0.0 で**ゼロから完全リビルド**を行い、以下を実現：

- 🔄 **アーキテクチャ刷新**: 巨大な単一スクリプト → 8モジュール構成
- 🐚 **Bash → Zsh 移行**: macOS 標準シェルへの対応
- 🇯🇵 **完全日本語化**: すべてのUIとメッセージを日本語に
- 📦 **DMG インストーラー**: プロフェッショナルな配布形式
- 🎨 **視認性向上**: カラースキーム最適化とエラーハンドリング強化

大規模な再設計を反映し、初回の正式リリースとして **v5.0.0** としました。

### 主な機能

- ✅ **外部ストレージ移行**: ゲームデータを外部ドライブに安全に移動
- ✅ **内蔵⇄外部切り替え**: ワンクリックでストレージモード変更
- ✅ **バッチ操作**: 複数ボリュームの一括マウント/アンマウント
- ✅ **データ保護**: 容量チェック、実行中チェック、rsync 同期
- ✅ **完全クリーンアップ**: 全データを安全に削除（隠しオプション）

---

## 🚀 クイックスタート

### 前提条件

- macOS Sequoia 15.1 以降
- Apple Silicon Mac (M1/M2/M3/M4)
- PlayCover 3.0 以降
- 外部ストレージ（APFS 対応）

### インストール方法1: DMGインストーラー（推奨）

1. **最新DMGをダウンロード**
   - [GitHub Releases](https://github.com/HEHEX8/PlayCoverManager/releases/latest) から最新の `.dmg` をダウンロード

2. **インストール**
   - DMGをマウント
   - PlayCover Manager.app を Applications フォルダにドラッグ

3. **初回起動**
   - アプリを右クリック → 「開く」を選択
   - Gatekeeper警告が出た場合は「開く」をクリック

### インストール方法2: ソースコードから

```bash
# リポジトリをクローン
git clone https://github.com/HEHEX8/PlayCoverManager.git
cd PlayCoverManager

# 実行権限を付与
chmod +x main.sh

# 起動
./main.sh
```

### インストール方法3: 自分でビルド

```bash
# リポジトリをクローン
git clone https://github.com/HEHEX8/PlayCoverManager.git
cd PlayCoverManager

# アプリケーションをビルド
./build-app.sh

# DMGインストーラーを作成（オプション）
./create-dmg-background-simple.sh
./create-dmg-appdmg.sh

# ビルドされたアプリをインストール
mv "build/PlayCover Manager.app" /Applications/
```

**DMG作成の詳細**: 
- [DMG-APPDMG-GUIDE.md](DMG-APPDMG-GUIDE.md) - DMG作成ガイド
- [RELEASE-DMG-GUIDE.md](RELEASE-DMG-GUIDE.md) - リリース方法

### 初回セットアップ

1. ツールを起動すると自動的に初期セットアップが開始されます
2. 外部ストレージを選択（USB/Thunderbolt/SSD）
3. PlayCover 用 APFS ボリュームが自動作成されます
4. セットアップ完了後、メインメニューが表示されます

---

## 📚 使い方

### メインメニュー

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  📱 PlayCover Volume Manager
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  1. アプリ管理
  2. ボリューム操作
  3. ストレージ切り替え（内蔵⇄外部）
  4. ディスクを取り外す
  0. 終了

選択してください (0-4):
```

### 1. アプリ管理

- **IPA インストール**: 複数 IPA ファイルの一括インストール（進捗表示付き）
- **アンインストール**: アプリと関連ボリュームの削除

### 2. ボリューム操作

- **全ボリュームマウント**: 登録済みボリュームを一括マウント
- **全ボリュームアンマウント**: 安全に一括アンマウント
- **個別操作**: 特定ボリュームのマウント/アンマウント/再マウント

### 3. ストレージ切り替え

- **内蔵 → 外部**: 内蔵データを外部ボリュームに移行
- **外部 → 内蔵**: 外部データを内蔵ストレージに戻す
- 容量チェック・アプリ実行中チェック・データ保護機能完備

### 4. ディスク取り外し

外部ストレージを安全に取り外します（全ボリュームのアンマウント処理）

---

## 🏗️ アーキテクチャ

### モジュール構造

```
PlayCoverManager/
├── main.sh                    # メインエントリーポイント
├── playcover-manager.command  # GUI起動スクリプト
├── lib/                       # モジュール
│   ├── 00_core.sh            # コア機能・ユーティリティ
│   ├── 01_mapping.sh         # マッピングファイル管理
│   ├── 02_volume.sh          # APFS ボリューム操作
│   ├── 03_storage.sh         # ストレージ切り替え
│   ├── 04_app.sh             # アプリインストール・管理
│   ├── 05_cleanup.sh         # クリーンアップ機能
│   ├── 06_setup.sh           # 初期セットアップ
│   └── 07_ui.sh              # UI・メニュー表示
└── README.md                  # このファイル
```

### 技術詳細

- **言語**: Zsh (macOS 標準シェル)
- **テスト**: 包括的な検証済み

### アイコンとDMG作成

プロジェクトにはカスタムアイコンとDMGインストーラー作成機能が含まれています：

```bash
# アイコンを生成（macOS上で実行）
./create-icon.sh

# アイコン付きでビルド
./build-app.sh

# DMGインストーラーを作成
./create-dmg-background-simple.sh
./create-dmg-appdmg.sh
```

**詳細ガイド:**
- [ICON_GUIDE.md](ICON_GUIDE.md) - アイコン作成
- [DMG-APPDMG-GUIDE.md](DMG-APPDMG-GUIDE.md) - DMGインストーラー作成
- [RELEASE-DMG-GUIDE.md](RELEASE-DMG-GUIDE.md) - GitHub Releasesへの公開

---

## 🐛 バグ報告

バグを発見した場合は、[Issues](https://github.com/HEHEX8/PlayCoverManager/issues) で以下の情報と共に報告してください：

- macOS バージョン
- Mac モデル（M1/M2/M3/M4）
- PlayCover バージョン
- 再現手順
- エラーメッセージ

---

## 📝 既知の制限

1. **APFS 容量表示**: macOS の仕様により、Finder で容量が実際と異なって見える場合があります
   - ツールは正常動作しています
   - 実際の効果は Macintosh HD の「使用済み」（上部の数値）で確認してください

2. **Intel Mac 未サポート**: Apple Silicon 専用です

3. **PlayCover 依存**: PlayCover がインストールされている必要があります

---

## 🔐 セキュリティ

- sudo 権限は必要最小限のみ使用
- データ破損防止のための多重チェック
- 破壊的操作には確認プロンプトを表示
- rsync による安全なデータ転送

---

## 📜 ライセンス

MIT License

---

## 🙏 謝辞

このツールは、PlayCover で iOS ゲームを楽しむユーザーのために開発されました。

---

## 📮 連絡先

- **GitHub**: [HEHEX8/PlayCoverManager](https://github.com/HEHEX8/PlayCoverManager)
- **Issues**: [Bug Reports](https://github.com/HEHEX8/PlayCoverManager/issues)
- **Releases**: [Latest Version](https://github.com/HEHEX8/PlayCoverManager/releases/latest)

---

<div align="center">

**最新リリースをチェック**

[![GitHub Release](https://img.shields.io/github/v/release/HEHEX8/PlayCoverManager?style=for-the-badge)](https://github.com/HEHEX8/PlayCoverManager/releases/latest)

</div>
