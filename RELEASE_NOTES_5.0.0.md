# 🎉 PlayCover Manager v5.0.0

## バグフィックスリリース

このリリースは、alpha2 で発見された重大なバグを修正する安定版リリースです。

## ⚠️ 重要なバグ修正

### ストレージ種別表示の完全統一（Critical Bug Fix）

**問題:**
- メインメニュー、アプリ管理、ボリューム情報、ストレージ切替の各画面で、ストレージ種別の表示が食い違っていました
- ボリューム情報では「マウント済」と正しく表示されるのに、他の画面では「内部」や「データ無し」と誤表示される問題

**症状例:**
```
✅ ボリューム情報: 🟢 マウント済 (正しい)
❌ アプリ管理: 🏠 内部 (誤り)
❌ ストレージ切替: ⚠️ データ無し (誤り)
```

**修正内容:**
- 全ての画面で `get_mount_point()` ベースの判定ロジックに統一
- 実際のマウント状況を直接確認する方式に変更
- `/sbin/mount` の grep パターン依存を削減

**結果:**
すべての画面で一貫したストレージ種別が表示されるようになりました。

### 初期セットアップのUX改善

**問題:**
- Enter キーを8回も押す必要があった
- 無効な入力（例: "y" を数字の代わりに入力）でスクリプトが終了

**修正内容:**
- 不要な Enter 待機を削除（情報表示後は自動で次に進む）
- ディスク選択で無効な入力時に再試行ループを実装
- より詳細なエラーメッセージを表示

**結果:**
スムーズで直感的なセットアップ体験を実現しました。

## 📥 ダウンロード

### DMGインストーラー（推奨）
- **PlayCover Manager-5.0.0.dmg** - プロフェッショナルなインストーラー

### ZIPアーカイブ
- **PlayCover Manager-5.0.0.zip** - 解凍してApplicationsフォルダにドラッグ

## 💾 インストール方法

### DMGを使用（推奨）
1. DMGファイルをダウンロード
2. ダブルクリックでマウント
3. `PlayCover Manager.app` を `Applications` フォルダにドラッグ
4. 初回起動時は右クリック → 「開く」

### ZIPを使用
1. ZIPファイルをダウンロード
2. ダブルクリックで解凍
3. `PlayCover Manager.app` を `Applications` フォルダに移動
4. 初回起動時は右クリック → 「開く」

## 🔄 アップグレード方法

### alpha2 からのアップグレード
- バグ修正のみで API や設定の変更はありません
- 既存のマッピングファイルとボリュームはそのまま使用できます
- 古いバージョンを削除して新しいバージョンをインストールしてください

### 以前のバージョンからのアップグレード
1. PlayCover と管理ツールを終了
2. 古い `PlayCover Manager.app` を削除
3. 新しいバージョンをインストール
4. 既存のボリュームとマッピングはそのまま使用できます

## 📋 主な機能

- ✅ APFS 外部ボリューム管理
- ✅ 内蔵⇄外部ストレージ切り替え
- ✅ バッチ操作（複数アプリの一括マウント/アンマウント）
- ✅ 自動マウント・アンマウント
- ✅ アプリ実行状態の自動検出
- ✅ 安全な取り外し機能
- ✅ 詳細なストレージ情報表示

## 💻 システム要件

- **OS**: macOS Sequoia 15.1 以降
- **アーキテクチャ**: Apple Silicon (M1/M2/M3/M4)
- **ストレージ**: USB/Thunderbolt/SSD (APFS フォーマット)
- **その他**: 
  - Homebrew（初回セットアップ時に自動インストール可能）
  - Xcode Command Line Tools（初回セットアップ時に自動インストール可能）

## 🔧 技術的な変更

### 判定ロジックの統一
```bash
# 統一後のロジック（全画面共通）
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
fi
```

### 修正されたファイル
- `lib/03_storage.sh`: ストレージ切替メニュー
- `lib/06_setup.sh`: 初期セットアップフロー
- `lib/07_ui.sh`: メインメニュー、アプリ管理

### 修正コミット
- `5c0faaf`: 初期セットアップのUX改善とストレージ種別表示の統一（第1弾）
- `f5482c1`: ストレージ種別表示ロジックをボリューム情報と統一（第2弾）
- `2776123`: ストレージ切替の表示ロジックをボリューム情報と完全統一（第3弾）

## 📖 ドキュメント

- [README](https://github.com/HEHEX8/PlayCoverManager/blob/main/README.md)
- [CHANGELOG](https://github.com/HEHEX8/PlayCoverManager/blob/main/CHANGELOG.md)
- [詳細ガイド](https://github.com/HEHEX8/PlayCoverManager/blob/main/DETAILED-GUIDE.md)

## 🐛 既知の問題

現在のところ、既知の問題はありません。

## 💬 フィードバック

問題を発見した場合は、[GitHub Issues](https://github.com/HEHEX8/PlayCoverManager/issues) で報告してください。

## 📄 ライセンス

MIT License

---

**リリース日:** 2025-01-29  
**バージョン:** 5.0.0  
**タイプ:** Stable Release (Bug Fix)
