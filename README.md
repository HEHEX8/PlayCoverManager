# PlayCover 外部ストレージ管理スクリプト集

## プロジェクト概要

macOS Tahoe 26.0.1 (2025年9月15日リリース) 向けに最適化されたPlayCoverの外部ストレージ管理スクリプト集です。PlayCoverとアプリのコンテナデータを外部ストレージに移行し、効率的なストレージ管理を実現します。

## スクリプト一覧

### 0_playcover-initial-setup.command
**PlayCover初期環境構築スクリプト**

PlayCover本体を外部ストレージに配置するための初期セットアップを行います。

**実装機能:**
1. ✅ Apple Silicon Mac専用アーキテクチャ検証
2. ✅ フルディスクアクセス確認
3. ✅ 依存関係チェック (Xcode CLI Tools, Homebrew, PlayCover)
4. ✅ スーパーユーザー権限取得
5. ✅ 外部ストレージ選択（内蔵ストレージ除外）
6. ✅ インストール確認プロンプト
7. ✅ PlayCover APFSボリューム作成
8. ✅ データ移行とマウント（競合自動解決）
9. ✅ 不足コンポーネント自動インストール
10. ✅ マッピングデータ管理 (`playcover-map.txt`)
11. ✅ 5秒後自動終了

### 1_playcover-ipa-install.command
**IPAインストールスクリプト**

選択したIPAファイルから情報を自動抽出し、専用の外部ストレージボリュームを作成してインストールします。

**実装機能:**
1. ✅ PlayCover アプリ存在確認
2. ✅ PlayCover マッピング登録確認
3. ✅ フルディスクアクセスチェック
4. ✅ スーパーユーザー権限取得
5. ✅ PlayCover ボリュームマウント確認/自動マウント
6. ✅ IPA ファイル選択（GUIダイアログ）
7. ✅ IPA 情報自動取得（Bundle ID, アプリ名）
8. ✅ インストール先ディスク自動選択
9. ✅ アプリ専用ボリューム作成（重複時は既存使用）
10. ✅ データ競合処理（内部/外部選択プロンプト）
11. ✅ マッピングデータ自動登録
12. ✅ PlayCover へ IPA インストール要求（上書き確認）
13. ✅ 完了後自動終了

## 使用方法

### 初回実行時のセキュリティ警告について

macOSのGatekeeperにより、初回実行時に以下の警告が表示される場合があります：

```
Appleは、"*.command"にMacに損害を与えたり、
プライバシーを侵害する可能性のあるマルウェアが含まれていないことを検証できませんでした。
```

**これは正常な動作です。** 以下の方法で実行できます：

#### 方法1: 右クリックから開く（推奨）

1. `.command` ファイルを **右クリック**
2. **「開く」** を選択
3. 確認ダイアログで **「開く」** をクリック
4. 以降は通常のダブルクリックで起動可能になります

#### 方法2: ターミナルから実行

```bash
cd /path/to/script
./0_playcover-initial-setup.command  # 初期セットアップ
./1_playcover-ipa-install.command    # IPAインストール
```

ターミナルから実行する場合、Gatekeeperの警告は表示されません。

#### 方法3: 隔離属性を削除（上級者向け）

```bash
# すべての.commandファイルから隔離属性を削除
xattr -d com.apple.quarantine *.command
```

### 実行前の準備

1. **フルディスクアクセス権限の付与**
   - システム設定 > プライバシーとセキュリティ > フルディスクアクセス
   - ターミナル.app を追加

2. **外部ストレージの接続**
   - USB/Thunderbolt接続の外部ドライブを準備
   - APFS対応ストレージを推奨

## 使用ワークフロー

### ステップ1: 初期セットアップ（初回のみ）

```bash
# または Finder からダブルクリック
./0_playcover-initial-setup.command
```

**処理内容:**
1. Apple Silicon Mac確認
2. フルディスクアクセス権限検証
3. 依存ソフトウェア確認
4. 管理者パスワード入力
5. 外部ストレージ選択
6. 不足コンポーネントインストール承認
7. PlayCover ボリューム作成
8. データ競合処理（内部/外部選択）
9. ボリュームマウント
10. 不足ソフトウェア自動インストール
11. マッピングデータ記録
12. 5秒後自動終了

### ステップ2: IPAインストール（必要に応じて繰り返し）

```bash
# または Finder からダブルクリック
./1_playcover-ipa-install.command
```

**処理内容:**
1. PlayCover アプリ確認
2. PlayCover マッピング確認
3. フルディスクアクセス確認
4. 管理者パスワード入力
5. PlayCover ボリュームマウント確認
6. IPA ファイル選択（GUI）
7. IPA 情報自動抽出
8. インストール先ディスク自動選択
9. アプリ専用ボリューム作成
10. データ競合処理
11. マッピングデータ登録
12. PlayCover へインストール要求
13. 完了後自動終了

## データ構造

### マッピングファイル形式

**ファイル名**: `playcover-map.txt` (スクリプトと同じディレクトリ)

**形式**: `VolumeName [TAB] BundleID`

**例**:
```
PlayCover	io.playcover.PlayCover
GenshinImpact	com.miHoYo.GenshinImpact
HonkaiStarRail	com.HoYoverse.HonkaiStarRail
```

### ディレクトリ構成

```
外部ストレージ (例: /dev/disk5)
├── PlayCover (APFS Volume)
│   └── マウント先: ~/Library/Containers/io.playcover.PlayCover/
├── GenshinImpact (APFS Volume)
│   └── マウント先: ~/Library/Containers/com.miHoYo.GenshinImpact/
└── HonkaiStarRail (APFS Volume)
    └── マウント先: ~/Library/Containers/com.HoYoverse.HonkaiStarRail/

直接アクセス:
/Volumes/PlayCover/
/Volumes/GenshinImpact/
/Volumes/HonkaiStarRail/
```

## 技術仕様

### 対応環境

- **OS**: macOS Tahoe 26.0.1 (2025年9月15日リリース)
- **アーキテクチャ**: Apple Silicon (arm64) のみ
- **シェル**: zsh (macOS標準)
- **ファイルシステム**: APFS

### ボリューム検出の技術詳細

**v1.1.0 での重要な改善**

1. **`-nomount` フラグの使用**
   ```bash
   # ボリューム作成時に自動マウントを防止
   diskutil apfs addVolume "$CONTAINER" APFS "$VOLUME_NAME" -nomount
   ```
   - `/Volumes/` への自動マウントを防ぐ
   - 後続の検索処理を簡素化
   - `0_playcover-initial-setup.command` と統一

2. **`diskutil info` による直接検索**
   ```bash
   # ボリューム名から直接デバイスノードを取得（最優先）
   volume_device=$(diskutil info "$VOLUME_NAME" | grep "Device Node:" | awk '{print $NF}')
   ```
   - 最も確実な検出方法
   - マウント状態に依存しない
   - `diskutil list` の grep より信頼性が高い

3. **多段階フォールバック**
   - Method 1: `diskutil info` で直接検索
   - Method 2: `/Volumes/` マウントポイント検索
   - Method 3: `diskutil list` 全体検索
   - Method 4: コンテナ内検索
   - Method 5: `diskutil apfs list` 検索
   - Method 6: 全APFSボリューム検索

### 依存ソフトウェア

- Xcode Command Line Tools
- Homebrew (Apple Silicon版)
- PlayCover Community Edition

### セキュリティ要件

- フルディスクアクセス権限（必須）
- 管理者権限（sudo）

## エラーハンドリング

### 自動対応するケース

- ボリューム名の重複 → 既存ボリュームを使用
- マッピングデータの重複 → スキップ
- データ競合 → ユーザー選択プロンプト

### 処理中断するケース

- 非Apple Silicon Mac
- フルディスクアクセス権限なし
- 外部ストレージ未接続
- インストール承認の拒否
- ユーザーによるキャンセル（Ctrl+C）

### 終了処理

- 正常終了/キャンセル問わず5秒後に自動クローズ
- 成功メッセージの表示
- sudo認証の自動クリーンアップ

## 次のステップ

### 推奨される追加機能

1. **ボリューム管理ツールの開発**
   - マッピングデータを活用した管理UI
   - 複数アプリケーションへの対応
   - マウント/アンマウント操作

2. **自動マウントの設定**
   - launchd による起動時自動マウント
   - plist ファイルの生成

3. **バックアップ機能**
   - Time Machine統合
   - 差分バックアップ

## トラブルシューティング

### フルディスクアクセスエラー

```
✗ フルディスクアクセス権限が必要です
```

**解決方法**: システム設定でターミナルに権限を付与

### ボリューム作成エラー

```
✗ ボリュームの作成に失敗しました
```

**解決方法**: 外部ストレージがAPFS対応か確認

### マウントエラー

```
✗ ボリュームのマウントに失敗しました
```

**原因と解決方法**:

1. **内蔵コンテナとの干渉**
   - 診断: `./diagnose-mount.sh` を実行
   - 解決: 内蔵コンテナを削除 `sudo rm -rf ~/Library/Containers/[BUNDLE_ID]`

2. **既存マウントの競合**
   - 診断: `mount | grep [ボリューム名]` で確認
   - 解決: `sudo umount [マウントポイント]` でアンマウント

3. **ファイルシステムエラー**
   - 解決: ディスクユーティリティで外部ドライブを修復

### ボリューム作成後に見つからないエラー

```
✗ 作成したボリュームが見つかりません
```

**原因**: ボリュームは作成されて `/Volumes/` にマウントされているが、スクリプトが検出できない

**解決方法**:
1. 診断スクリプトで確認: `./diagnose-volume-creation.sh`
2. 手動でボリュームをアンマウント: `sudo diskutil unmount /Volumes/[ボリューム名]`
3. スクリプトを再実行

**v1.1.0 以降では自動的に `/Volumes/` からも検出されます**

## ライセンスとサポート

### 作成情報

- **作成日**: 2025年10月24日
- **バージョン**: 1.0.0
- **対応OS**: macOS Tahoe 26.0.1

### 使用上の注意

- このスクリプトは外部ストレージへのデータ移行を行います
- 実行前に重要なデータのバックアップを推奨します
- PlayCoverの動作中は実行しないでください

## 変更履歴

### v1.1.0 (2025-10-24)

- ✅ **ボリューム作成の改善**（重要）
  - `-nomount` フラグの追加で自動マウントを防止
  - `0_playcover-initial-setup.command` と同じロジックに統一
  - `/Volumes/` への自動マウントによる検出失敗を解決
- ✅ **ボリューム検出の強化**
  - `diskutil info` による直接検索を最優先（最も確実）
  - 6つの検出メソッドによる多段階フォールバック
  - ボリューム名からデバイスノードを直接取得
  - ボリューム作成後の待機処理追加
- ✅ **マウント処理の改善**
  - 既存マウント競合の自動検出とアンマウント
  - 内蔵コンテナ干渉の自動削除
  - 詳細なエラーログ出力
  - マウント状態の厳密な検証
- ✅ **診断・ユーティリティスクリプトの追加**
  - `diagnose-mount.sh` - マウント問題の診断
  - `diagnose-volume-creation.sh` - ボリューム作成問題の診断
  - `remount-volume.sh` - クイック再マウントツール
- ✅ **ボリューム整合性チェック**
  - 既存ボリュームのAPFS検証
  - 破損ボリュームの再作成オプション
  - マウント前の最終確認処理

### v1.0.0 (2025-10-24)

- 初回リリース
- 全11ステップの実装完了
- macOS Tahoe 26.0.1 完全対応
- zsh構文への完全準拠
