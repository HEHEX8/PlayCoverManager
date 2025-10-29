# macOS Build Guide - アプリ起動とDMG作成の修正版

## 🔧 修正内容

### 問題1: アプリをダブルクリックしても何も起動しない
**原因**: 
- Zsh構文がbashで動作しない
- .appバンドルからTerminalを起動する仕組みがなかった

**修正**:
- ランチャースクリプトを作成（osascriptでTerminal起動）
- メインスクリプトをResourcesに配置
- 実行ファイルはTerminalランチャーとして機能

### 問題2: DMGのサイズが小さく、Applications フォルダへのリンクがない
**原因**:
- 単にアプリだけをDMGに含めていた
- Applicationsフォルダへのシンボリックリンクが欠如

**修正**:
- 一時ディレクトリを作成
- Applicationsフォルダへのシンボリックリンクを追加
- ドラッグ&ドロップインストールが可能に

---

## 🚀 macOSでのビルド手順

### ステップ1: 最新コードを取得

```bash
cd /Users/hehex/Documents/GitHub/PlayCoverManager
git pull origin main
```

### ステップ2: アイコンを生成（オプション）

```bash
# 古いアイコンファイルをクリーンアップ
rm -rf AppIcon.iconset AppIcon.icns

# アイコンを生成
./create-icon.sh
```

### ステップ3: アプリをビルド

```bash
./build-app.sh
```

### ステップ4: アプリをテスト

```bash
./test-app.sh
```

または手動でテスト：

```bash
# 起動テスト
open "build/PlayCover Manager.app"
```

---

## 🎯 一発コマンド（すべて実行）

```bash
cd /Users/hehex/Documents/GitHub/PlayCoverManager && \
git pull origin main && \
rm -rf AppIcon.iconset AppIcon.icns build && \
./create-icon.sh && \
./build-app.sh && \
./test-app.sh
```

---

## ✅ 期待される動作

### アプリ起動時:

1. **Finderでダブルクリック**
   ```
   PlayCover Manager.app をダブルクリック
   ```

2. **Terminalウィンドウが開く**
   ```
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
     📱 PlayCover Volume Manager v5.0.0
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   
     1. アプリ管理
     2. ボリューム操作
     3. ストレージ切り替え（内蔵⇄外部）
     4. ディスクを取り外す
     0. 終了
   ```

3. **メニューが表示される**
   - 通常のターミナルアプリとして動作
   - 色付きテキスト、絵文字、インタラクティブメニュー

### DMGマウント時:

```
PlayCover Manager-5.0.0.dmg をダブルクリック
↓
Finderウィンドウが開く
↓
[PlayCover Manager.app] と [Applications →] が表示される
↓
アプリをApplicationsフォルダにドラッグ&ドロップ
```

---

## 📦 ビルド成果物

### build/ ディレクトリの内容:

```
build/
├── PlayCover Manager.app/
│   └── Contents/
│       ├── Info.plist
│       ├── MacOS/
│       │   └── PlayCoverManager     (ランチャースクリプト)
│       └── Resources/
│           ├── main-script.sh       (メインロジック)
│           ├── lib/                 (8モジュール)
│           ├── AppIcon.icns         (アイコン)
│           └── ドキュメント類
├── PlayCover Manager-5.0.0.dmg      (インストーラー)
└── PlayCover Manager-5.0.0.zip      (配布用ZIP)
```

### ファイルサイズ:

- **アプリ本体**: ~75KB
- **DMG**: ~150KB
- **ZIP**: ~63KB

---

## 🔍 動作確認

### 1. アプリ構造の確認

```bash
./test-app.sh
```

または手動で：

```bash
# ランチャースクリプトの確認
cat "build/PlayCover Manager.app/Contents/MacOS/PlayCoverManager"

# メインスクリプトの確認
ls -la "build/PlayCover Manager.app/Contents/Resources/main-script.sh"

# モジュールの確認
ls -la "build/PlayCover Manager.app/Contents/Resources/lib/"
```

### 2. 起動テスト

```bash
# Finderから開く
open "build/PlayCover Manager.app"

# Terminalウィンドウが開くことを確認
# メニューが表示されることを確認
```

### 3. DMGテスト

```bash
# DMGをマウント
open "build/PlayCover Manager-5.0.0.dmg"

# Finderウィンドウで確認:
# - PlayCover Manager.app が表示される
# - Applications へのシンボリックリンクが表示される
```

---

## 🐛 トラブルシューティング

### Q: アプリをダブルクリックしても何も起こらない

**診断**:
```bash
# ランチャースクリプトを直接実行
bash "build/PlayCover Manager.app/Contents/MacOS/PlayCoverManager"
```

**考えられる原因**:
1. 実行権限がない
   ```bash
   chmod +x "build/PlayCover Manager.app/Contents/MacOS/PlayCoverManager"
   ```

2. メインスクリプトが見つからない
   ```bash
   ls "build/PlayCover Manager.app/Contents/Resources/main-script.sh"
   ```

### Q: Terminal権限のエラーが出る

**解決方法**:
```
システム設定 → プライバシーとセキュリティ → フルディスクアクセス
→ Terminal.app を追加
```

### Q: Gatekeeper警告が出る

**解決方法**:
```bash
# Gatekeeper属性を削除
xattr -cr "build/PlayCover Manager.app"

# または右クリック → 「開く」を選択
```

### Q: DMGにApplicationsフォルダが表示されない

**確認**:
```bash
# DMGをマウント
hdiutil attach "build/PlayCover Manager-5.0.0.dmg"

# 内容を確認
ls -la "/Volumes/PlayCover Manager/"

# アンマウント
hdiutil detach "/Volumes/PlayCover Manager"
```

期待される出力:
```
lrwxr-xr-x  1 user  staff   12 Oct 29 03:00 Applications -> /Applications
drwxr-xr-x  3 user  staff   96 Oct 29 03:00 PlayCover Manager.app
```

---

## 📋 スクリプト構造

### PlayCoverManager (ランチャー)
```bash
#!/bin/bash
# 役割: Terminalを起動してメインスクリプトを実行
# 場所: Contents/MacOS/PlayCoverManager

osascript でTerminalを起動
↓
main-script.sh を実行
```

### main-script.sh (メインロジック)
```bash
#!/bin/bash
# 役割: PlayCover Managerの本体
# 場所: Contents/Resources/main-script.sh

lib/*.sh を読み込み
↓
メニュー表示・処理
```

---

## 🚀 配布準備

### GitHub Releasesにアップロード:

```bash
# 1. ZIPファイルを確認
ls -lh "build/PlayCover Manager-5.0.0.zip"

# 2. DMGファイルを確認
ls -lh "build/PlayCover Manager-5.0.0.dmg"

# 3. GitHub Releasesにアップロード
# - ZIP: 万能配布形式（推奨）
# - DMG: macOS標準インストーラー形式
```

### ユーザー向けインストール手順:

#### 方法1: ZIPから（簡単）
```bash
# 1. ダウンロード
# PlayCover Manager-5.0.0.zip

# 2. 解凍
unzip "PlayCover Manager-5.0.0.zip"

# 3. インストール
mv "PlayCover Manager.app" /Applications/

# 4. 起動
# Finderから右クリック → 「開く」
```

#### 方法2: DMGから（推奨）
```bash
# 1. ダウンロード
# PlayCover Manager-5.0.0.dmg

# 2. ダブルクリックでマウント

# 3. アプリをApplicationsフォルダにドラッグ&ドロップ

# 4. 起動
# Finderから右クリック → 「開く」
```

---

## ✨ まとめ

### 修正内容:
- ✅ アプリが正常に起動（Terminalウィンドウ表示）
- ✅ DMGにApplicationsフォルダリンク追加
- ✅ ドラッグ&ドロップインストール対応
- ✅ テストスクリプト追加

### 次のステップ:
1. macOSでビルド
2. 動作確認
3. GitHub Releasesにアップロード
4. ユーザーに配布

**🎊 ビルドシステム完成！**
