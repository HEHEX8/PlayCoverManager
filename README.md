# PlayCover 外部ストレージ管理ツール

macOS Sequoia 15.1+ (Tahoe 26.0.1) 対応の統合管理ツール

## 🎯 概要

PlayCoverを外部ストレージで運用するための**オールインワン管理ツール**です。
初期セットアップからアプリインストール、ボリューム管理、完全リセットまで、すべての機能を統合しています。

## 📦 メインツール

### `0_PlayCover-ManagementTool.command`
**PlayCover統合管理ツール（v4.24.2）**

すべての機能を1つのスクリプトに統合した完全版です。

#### 🎛️ メイン機能

1. **初期セットアップ**
   - Apple Silicon Mac の確認
   - フルディスクアクセス権限の確認
   - Xcode Command Line Tools の確認とインストール
   - Homebrew の確認とインストール
   - PlayCover の確認とインストール（`brew install --cask playcover-community`）
   - 外部ストレージの選択
   - PlayCover メインボリュームの作成とマウント
   - マッピングファイルの作成

2. **IPA インストール**
   - IPA ファイルの選択（Finder ダイアログ）
   - アプリ情報の抽出（日本語名対応）
   - アプリ専用ボリュームの作成
   - ボリューム作成前の確認プロンプト
   - 既存アプリの検出とバージョン比較
   - アップデート確認プロンプト
   - 自動マウント（正しい位置に）
   - PlayCover へのインストール起動
   - マッピングファイルへの登録

3. **ボリューム管理**
   - **全ボリュームをマウント**
     - PlayCover メインボリュームの優先マウント
     - 全アプリボリュームの一括マウント
     - 誤った位置のボリュームを自動再マウント
     - 存在しないボリュームのクリーンアップ確認
   
   - **全ボリュームをアンマウント**
     - アプリボリュームの一括アンマウント
     - PlayCover メインボリュームのアンマウント
     - 結果サマリーの表示
   
   - **個別ボリューム操作**
     - リアルタイムステータス表示
       - ✅ 正常にマウント済み
       - ⚠️  別の場所にマウント中
       - ⭕ アンマウント済み
       - ❌ ボリュームが見つからない
     - 個別マウント/アンマウント/再マウント
     - 存在しないボリュームのマッピング削除
   
   - **ボリューム状態確認**
     - PlayCover メインボリュームの状態確認
     - 全アプリボリュームの詳細状態確認
     - 日本語名での分かりやすい表示
   
   - **ディスク全体を取り外し**
     - 全ボリュームの自動アンマウント
     - ディスク情報の表示
     - 安全な取り外し確認
     - 物理デバイスの取り外し準備

4. **🔥 超強力クリーンアップ（完全リセット）**
   - すべてのボリュームをアンマウント
   - すべてのコンテナを完全削除
   - PlayCover本体をアンインストール（`brew uninstall --cask playcover-community`）
   - PlayTools.frameworkを削除
   - キャッシュ・設定・ログを削除
   - APFSボリュームを削除（内蔵・外部両方）
   - マッピングファイルを削除
   - 二重確認システム（yes + DELETE ALL）
   - 削除前の完全プレビュー表示

**⚠️ 注意**: この操作は取り消せません！すべてのPlayCoverデータが削除されます。

---

## 🚀 使用方法

### 初回セットアップ
1. `0_PlayCover-ManagementTool.command` をダブルクリック
2. メインメニューで **[1] 初期セットアップ** を選択
3. 管理者パスワードを入力
4. 外部ストレージを選択
5. 必要なソフトウェアのインストールを確認
6. 完了を待つ

### アプリのインストール
1. `0_PlayCover-ManagementTool.command` をダブルクリック
2. メインメニューで **[2] IPAインストール** を選択
3. 管理者パスワードを入力
4. IPA ファイルを選択
5. ボリューム作成を確認
6. 既存アプリがあればアップデート確認
7. PlayCover でインストールを完了

### 日常的な管理
1. `0_PlayCover-ManagementTool.command` をダブルクリック
2. メインメニューで **[3] ボリューム管理** を選択
3. サブメニューから操作を選択
   - **[1] 全ボリュームをマウント**: Mac 起動後に実行
   - **[2] 全ボリュームをアンマウント**: Mac シャットダウン前に実行
   - **[3] 個別ボリューム操作**: 個別に管理が必要なとき
   - **[4] ボリューム状態確認**: 状態を確認したいとき
   - **[5] ディスク全体を取り外し**: 外部ストレージを取り外すとき

### 🔥 完全リセット（トラブル時）
1. `0_PlayCover-ManagementTool.command` をダブルクリック
2. メインメニューで **[3] ボリューム管理** を選択
3. サブメニューで **[6] 超強力クリーンアップ** を選択
4. 削除対象の完全プレビューを確認
5. `yes` と入力
6. `DELETE ALL` と入力して実行
7. 完了後、ターミナルが自動的に閉じる
8. **再セットアップが必要**: メインメニューの[1]から再実行

---

## 📄 マッピングファイル

`playcover-map.txt` - ボリュームとアプリの対応関係を記録

**フォーマット（タブ区切り）:**
```
VolumeName	BundleID	DisplayName
PlayCover	io.playcover.PlayCover	PlayCover
ZenlessZoneZero	com.HoYoverse.Nap	ゼンレスゾーンゼロ
HonkaiStarRail	com.HoYoverse.hkrpgoversea	崩壊：スターレイル
```

**特徴:**
- 3列構成（ボリューム名、Bundle ID、表示名）
- 日本語名または英語名を保存
- ボリューム管理機能で自動活用

---

## 🎨 UI デザイン

全機能で統一されたUIデザイン：

### カラースキーム
- 🟢 **緑色**: 成功メッセージ
- 🔴 **赤色**: エラーメッセージ
- 🟡 **黄色**: 警告メッセージ
- 🔵 **青色**: 情報メッセージ、ヘッダー
- 🔵 **シアン**: セクション見出し

### メッセージアイコン
- ✓ 成功
- ✗ エラー
- ⚠ 警告
- ℹ 情報

### ステータスアイコン
- ✅ 正常動作中
- ⚠️  異常状態
- ⭕ アンマウント済み
- ❌ 存在しない

### 終了処理
- **成功時**: 3秒後に自動クローズ
- **エラー時**: Enter キー待ち（ログ確認のため）
- **クリーンアップ後**: 3秒後に自動終了（再セットアップが必要）

---

## 🔧 技術的な詳細

### PlayCover 外部アプリインストールシステム

#### 従来の問題
PlayCoverボリュームが未マウント状態でPlayCoverを起動すると、内蔵ストレージ側のコンテナにデータが作成され、外部ボリュームのマウントができなくなる問題がありました。

#### 解決方法
PlayCover.app本体を外部ストレージに配置し、/Applicationsにはシンボリックリンクのみを配置：

```bash
# 実体の配置場所
~/Library/Containers/io.playcover.PlayCover/PlayCover.app

# シンボリックリンク
/Applications/PlayCover.app -> ~/Library/Containers/io.playcover.PlayCover/PlayCover.app
```

#### メリット
- ✅ 外部ドライブ未接続時、PlayCoverは自動的に起動不可
- ✅ Spotlight、Launchpad での検索は正常に動作
- ✅ 誤起動による内部ストレージデータ作成を完全に防止
- ✅ マウント時に自動でシンボリックリンクを検証・再作成

### マウントオプション
すべてのボリュームは `nobrowse` オプションでマウントされ、Finder のサイドバーやデスクトップに表示されません。

```bash
sudo mount -t apfs -o nobrowse /dev/diskXsY ~/Library/Containers/[BundleID]
```

### ボリューム配置
- **PlayCover メインボリューム**: `~/Library/Containers/io.playcover.PlayCover`
- **PlayCover アプリ本体**: `~/Library/Containers/io.playcover.PlayCover/PlayCover.app`
- **アプリボリューム**: `~/Library/Containers/[各アプリのBundleID]`

### 自動修正機能
ボリューム管理機能は、誤った位置にマウントされているボリュームを検出し、自動的に正しい位置に再マウントします。また、シンボリックリンクの破損も自動検出・修復します。

### Homebrewによる管理
PlayCover本体は公式の方法でインストール・アンインストールされます：
```bash
# インストール
brew install --cask playcover-community

# アンインストール（超強力クリーンアップ時）
brew uninstall --cask playcover-community
```

---

## ⚠️ 注意事項

### 必須要件
- Apple Silicon Mac（M1/M2/M3/M4シリーズ）
- macOS Sequoia 15.1 (Tahoe 26.0.1) 以降
- フルディスクアクセス権限（ターミナル.app）
- 外部ストレージ（USB/Thunderbolt/SSD）

### 推奨事項
- PlayCover を使用する際は必ずボリュームをマウントしてください
- Mac シャットダウン前には必ずボリュームをアンマウントしてください
- 外部ストレージを物理的に取り外す前に「ディスク全体を取り外し」を実行してください
- **外部ドライブ未接続時**: PlayCover.app はシンボリックリンクのため起動できません（正常動作）

### トラブルシューティング
- **ボリュームが見つからない**: ボリューム管理 → 状態確認
- **マウントエラー**: ボリューム管理 → 個別操作で再マウント
- **デスクトップに表示される**: 既存のマウントをアンマウントして再マウント
- **アプリが起動しない**: ボリュームが正しくマウントされているか確認
- **PlayCoverが起動できない**: 外部ストレージが接続されているか確認
- **内蔵ストレージにデータ有**: PlayCoverボリュームをアンマウントして、内部データを削除
- **🔥 すべてのアプリがクラッシュする**: 超強力クリーンアップを実行（詳細は `docs/guides/NUCLEAR_CLEANUP_GUIDE.md` を参照）
- **外部ボリューム再マウント後にクラッシュ**: 超強力クリーンアップで外部ボリュームの古いデータを完全削除

---

## 📂 プロジェクト構造

```
webapp/
├── 0_PlayCover-ManagementTool.command  # メイン統合ツール
├── README.md                            # このファイル
├── CHANGELOG.md                         # 詳細な更新履歴
├── docs/                                # ドキュメント
│   ├── archive/                         # 古いバグ修正・変更履歴
│   ├── guides/                          # ユーザー向けガイド
│   └── development/                     # 開発用ドキュメント
├── debug/                               # デバッグツール・ログファイル
└── archive/                             # 古いリリース・バックアップ
```

---

## 🔄 更新履歴（最近の主要版）

### v4.25.0 (最新) - Fix Initial Setup with Proper Container Initialization
- 🎯 **初期セットアップフロー修正**: PlayCoverコンテナの正しい初期化手順を実装
- ✅ PlayCoverインストール後、一度起動してコンテナを作成
- ✅ 作成された完全なコンテナを外部ストレージにコピー
- ✅ 設定ファイル、フレームワーク、キャッシュが正しく配置される
- ✅ 超強力クリーンアップでPlayCoverを正しくアンインストール（`brew uninstall --cask playcover-community`）
- ✅ 削除プレビューにPlayCoverアプリを追加（7項目に拡張）
- ✅ 初期セットアップの実行順序を最適化（ソフトウェアインストール → ボリューム作成）

### v4.24.2 - Fix Volume Detection Pattern
- 🐛 **ボリューム検出パターン修正**: 2段階grepアプローチで柔軟な検出
- ✅ `diskutil list` 出力の異なるフォーマットに対応
- ✅ `volume_exists()` と `get_volume_device()` を改善

### v4.24.1 - Fix Environment Check
- 🐛 **環境チェック修正**: 初期セットアップ後の環境検証失敗を修正
- ✅ `diskutil info` → `volume_exists()` に変更
- ✅ ボリュームの存在チェックを正しく実装
- ✅ マウント状態に関係なくボリュームを検出

### v4.24.0 - Exit After Nuclear Cleanup
- 🚪 **終了動作変更**: クリーンアップ完了後にターミナルを閉じる
- ✅ メインメニューに戻らず、再セットアップを促す
- ✅ 3秒後に自動的にターミナルを閉じる
- ✅ 次のステップを明確に表示（初期セットアップが必要）

### v4.23.1 - Fix Zsh Reserved Variable
- 🐛 **変数名競合修正**: zsh予約変数 `path` との競合を解決
- ✅ `path` → `container_path`, `item_path`, `target_path` に変更
- ✅ "inconsistent type for assignment" エラーを修正

### v4.23.0 - Complete External Command Path Fix
- 🔧 **全外部コマンドパス修正**: 18種類のコマンドをフルパス指定
- ✅ macOS環境でのPATH制限問題を完全解決（110+箇所）

### v4.22.0 - Deletion Preview
- 📋 **削除プレビュー機能**: 実行前に削除対象を完全表示
- ✅ 2フェーズアプローチ（スキャン → 確認 → 実行）
- ✅ 削除対象の詳細情報を6カテゴリに分けて表示
- ✅ より安全で透明性の高いクリーンアップ

### v4.21.1 - Critical Safety Fix
- 🔒 **重大なセキュリティ修正**: システムボリューム削除を防止
- ✅ Macintosh HD、Data等のシステムボリュームを明示的にスキップ
- ✅ マッピングファイル優先の安全なボリューム削除

### v4.21.0 - Nuclear Cleanup Feature
- 🔥 超強力クリーンアップ（完全リセット）機能追加
- ✅ すべてのボリューム・コンテナの完全削除
- ✅ PlayTools.frameworkの削除
- ✅ キャッシュ・設定・ログの完全クリア
- ✅ 二重確認システム（yes + DELETE ALL）

詳細な更新履歴は `CHANGELOG.md` を参照してください。

---

## 📚 関連ドキュメント

### ユーザー向け
- `docs/guides/NUCLEAR_CLEANUP_GUIDE.md` - 🔥 超強力クリーンアップ詳細ガイド
- `docs/guides/USER_DIAGNOSTIC_GUIDE.md` - トラブルシューティングガイド
- `docs/guides/USAGE.md` - 詳細な使用方法

### 開発者向け
- `CHANGELOG.md` - 詳細な更新履歴
- `docs/development/` - 実装ドキュメント
- `docs/archive/` - 過去のバグ修正履歴

---

## 📝 ライセンス

このプロジェクトは個人利用および学習目的で作成されました。

---

## 🙏 謝辞

- PlayCover Community
- macOS コミュニティ
- すべてのコントリビューター

---

**最終更新:** 2025年10月27日（macOS Sequoia 15.1対応、v4.25.0）
