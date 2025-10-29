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

- ✅ **クイックランチャー**: アプリを素早く起動（状態表示付き）
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

### クイックランチャー

アプリが1個以上インストールされている場合、起動時に自動表示されます：

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  🚀 クイックランチャー
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ⭐ 1. 崩壊：スターレイル    [🔌] ● Ready        🔐
     2. 原神                 [🏠] ⚠️ 内蔵データ検出
     3. ゼンレスゾーンゼロ   [🔌] 📦 未マウント    🔐

  最近起動: 崩壊：スターレイル

  番号でアプリ起動 | Enter=最近起動 | m=管理メニュー | 0=終了
選択:
```

**アイコンの意味:**
- `🔌`: 外部ストレージ設定
- `🏠`: 内蔵ストレージ設定
- `●`: 起動可能（Ready）
- `⚠️`: 警告（内蔵データ検出・要対応）
- `🔄`: 要再マウント
- `📦`: 未マウント（自動マウント実行）
- `📭`: 初期状態（データなし）
- `🔐`: sudo権限が必要
- `⭐`: 最近起動したアプリ

### メインメニュー

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  📱 PlayCover Volume Manager
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  1. クイックランチャー
  2. アプリ管理
  3. ボリューム操作
  4. ストレージ切り替え（内蔵⇄外部）
  5. ディスクを取り外す
  0. 終了

選択してください (0-5):
```

### 1. クイックランチャー

- **素早い起動**: 番号選択でアプリを即座に起動
- **自動マウント**: 未マウント状態の場合は自動でマウント実行
- **状態表示**: 各アプリの現在の状態をアイコンで視覚的に表示
- **最近起動の記録**: Enterキーで最近起動したアプリを再起動
- **汚染検出**: 内蔵ストレージの意図しないデータを警告表示

### 2. アプリ管理

- **IPA インストール**: 複数 IPA ファイルの一括インストール（進捗表示付き）
- **アンインストール**: アプリと関連ボリュームの削除

### 3. ボリューム操作

- **全ボリュームマウント**: 登録済みボリュームを一括マウント
- **全ボリュームアンマウント**: 安全に一括アンマウント
- **個別操作**: 特定ボリュームのマウント/アンマウント/再マウント

### 4. ストレージ切り替え

- **内蔵 → 外部**: 内蔵データを外部ボリュームに移行
- **外部 → 内蔵**: 外部データを内蔵ストレージに戻す
- **汚染データ処理**: 意図しない内蔵データの検出と対処選択
- 容量チェック・アプリ実行中チェック・データ保護機能完備

### 5. ディスク取り外し

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

#### ストレージモード検出

アプリの現在のストレージ状態を自動検出し、適切なアクションを提示：

**検出モード:**
- `external`: 外部ストレージに正しくマウント済み（Ready）
- `external_wrong_location`: 外部ボリュームが間違った位置にマウント（要再マウント）
- `internal_intentional`: ユーザーが選択した内蔵ストレージ（Ready）
- `internal_intentional_empty`: 内蔵ストレージ選択済みだがデータなし（初期状態）
- `internal_contaminated`: **意図しない内蔵データ検出**（警告表示）
- `none`: データなし・未マウント状態

**汚染検出の仕組み:**
1. 外部ストレージ設定のアプリで内蔵コンテナにデータが存在
2. `.internal_storage` マーカーファイルが存在しない
3. 以下のいずれかの原因で発生：
   - 外部ボリューム未マウント時にアプリを起動
   - 他のMacで同じアプリを使用
   - 手動でデータを内蔵に作成

**対処方法:**
- クイックランチャーで「⚠️ 内蔵データ検出」と表示
- ストレージ切り替えメニューで対処を選択可能：
  1. 削除して外部ボリュームをマウント
  2. 保持して外部ボリュームと統合
  3. スキップ（後で個別に処理）

#### インストール完了検知（v5.0.2）

IPAインストール完了を正確に検知するため、2パターン対応の検知システムを採用：

**検知パターンA: 標準アプリ（185MB～3GB）**
1. **Phase 1: 基本完了シグナル**
   - PlayCoverの設定ファイル（`App Settings/{bundle_id}.plist`）の変更を監視
   - 2回目の更新（mtime変更）を検知 → インストール処理完了の可能性

2. **Phase 2: ファイル安定性検証**
   - mtimeが4秒間変化しないことを確認
   - `lsof`でPlayCoverがファイルにアクセスしていないことを確認
   - 両方の条件を満たして初めて完了と判定

**検知パターンB: 極小アプリ（1～10MB）**
1. **Phase 1b: シングルアップデートパターン**
   - 1回目の更新後、8秒経過しても2回目が来ない場合
   - 極小アプリ（例：Via 1.6MB）は1回の更新のみで完了するケース
   
2. **Phase 2: ファイル安定性検証**（パターンAと同様）
   - mtimeが4秒間変化しないことを確認 → 完了判定

**パラメータ:**
- `check_interval`: 2秒（速度とCPU負荷のバランス）
- `stability_threshold`: 4秒（安定性判定の閾値）
- `single_update_wait`: 8秒（極小アプリのフォールバック判定時間）

**利点:**
- **小容量IPA（180MB）**: 高速検知（2nd update + 4秒待機 ≈ 6-10秒）
- **大容量IPA（2-3GB）**: 正確な検知（false positive防止）
- **極小IPA（1-10MB）**: 確実な検知（タイムアウト回避）
- すべてのサイズ範囲で最適な検知を実現

**進行状況インジケータ:**
- `.` : 1回目の更新待ち
- `◆` : 1回目の更新検知（2回目待ち）
- `◇` : 2回目の更新検知（安定性チェック開始）
- `⏳` : 安定性検証中

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
