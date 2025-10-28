# macOSでのクイックスタート

## 🚨 エラーが出た場合の対処法

### エラー: `iconutil: Failed to generate ICNS`

このエラーは元画像がJPEG形式なのに`.png`拡張子になっていることが原因です。

---

## 🔧 解決方法

### ステップ1: リポジトリを最新化

```bash
cd /Users/hehex/Documents/GitHub/PlayCoverManager
git pull origin main
```

### ステップ2: 診断スクリプトを実行

```bash
./debug-icon.sh
```

このスクリプトは自動的に：
- 元画像がJPEGかPNGか確認
- JEPGの場合、自動的にPNGに変換
- 生成されたアイコンファイルの検証
- 問題がある場合、詳細な診断情報を表示

### ステップ3: アイコン生成を再試行

```bash
# 古いファイルをクリーンアップ
rm -rf AppIcon.iconset AppIcon.icns

# 再生成
./create-icon.sh
```

### ステップ4: ビルド

```bash
./build-app.sh
```

---

## 🎯 一発コマンド（推奨）

```bash
# すべてを一度に実行
cd /Users/hehex/Documents/GitHub/PlayCoverManager && \
git pull origin main && \
rm -rf AppIcon.iconset AppIcon.icns && \
./create-icon.sh && \
./build-app.sh
```

成功すれば：
```
build/
├── PlayCover Manager.app       # アイコン付きアプリ
└── PlayCover Manager-5.0.0.zip # 配布用ZIP
```

---

## 📋 期待される出力

### create-icon.sh の成功例:

```
🎨 Creating macOS icon from app-icon.png...

📋 Detected format: JPEG
🔄 Converting JPEG to PNG format...
✅ Converted to PNG: app-icon-converted.png

📁 Creating AppIcon.iconset directory...
🔧 Generating icon sizes...
✅ Generated 10 icon sizes
🔍 Verifying generated icons...
✅ All icons verified
🎨 Converting to .icns format...
✅ AppIcon.icns created successfully!

📦 Next steps:
   1. Run ./build-app.sh to rebuild the app with the new icon
   2. The icon will be automatically included in the app bundle

-rw-r--r--  1 hehex  staff   123K Oct 29 03:00 AppIcon.icns
AppIcon.icns: Mac OS X icon, 1024x1024, 512x512, 256x256, 128x128, 64x64, 48x48, 32x32, 16x16

🧹 Cleaned up temporary files

✨ Done!
```

### build-app.sh の成功例:

```
🚀 Building PlayCover Manager v5.0.0...

📦 Creating .app bundle structure...
📝 Copying main script...
📚 Copying library modules...
🔧 Updating script paths...
🎨 Adding app icon...
📄 Creating Info.plist...
🎨 Creating app icon...
📖 Creating bundled README...
📚 Copying documentation...

📦 Creating distributable DMG...
created: build/PlayCover Manager-5.0.0.dmg

📦 Creating distributable ZIP...

✅ Build complete!

📁 Output files:
   • App Bundle: build/PlayCover Manager.app
   • DMG: build/PlayCover Manager-5.0.0.dmg
   • ZIP: build/PlayCover Manager-5.0.0.zip

🚀 Distribution ready!
```

---

## ❌ トラブルシューティング

### Q: まだ `Failed to generate ICNS` エラーが出る

**A: debug-icon.shの出力を確認**

```bash
./debug-icon.sh
```

出力の最後に問題の診断が表示されます。

### Q: AppIcon.iconsetの中のPNGが壊れている

**A: 完全にクリーンアップして再生成**

```bash
# すべてのアイコン関連ファイルを削除
rm -rf AppIcon.iconset AppIcon.icns app-icon-converted.png

# 元画像を再ダウンロード（必要に応じて）
# git checkout app-icon.png

# 再生成
./create-icon.sh
```

### Q: sips コマンドがエラーを出す

**A: sipsの詳細出力を確認**

```bash
# 手動でテスト
sips -s format png app-icon.png --out test.png
file test.png
```

JPEGをPNGに変換できない場合は、別の方法：

```bash
# ImageMagickを使用（Homebrewでインストール可能）
brew install imagemagick
convert app-icon.png -resize 1024x1024 app-icon-fixed.png
mv app-icon-fixed.png app-icon.png
```

---

## 🎨 別の方法: オンラインツールを使用

もし上記の方法がうまくいかない場合：

1. **app-icon.pngをダウンロード**
2. **オンライン変換**
   - https://cloudconvert.com/png-to-icns
   - app-icon.png をアップロード
   - ICNS形式でダウンロード
3. **ダウンロードしたファイルをリネーム**
   ```bash
   mv ~/Downloads/app-icon.icns AppIcon.icns
   ```
4. **ビルド**
   ```bash
   ./build-app.sh
   ```

---

## ✅ 確認方法

### アイコンが含まれているか確認:

```bash
ls -lh "build/PlayCover Manager.app/Contents/Resources/AppIcon.icns"
```

### Info.plistでアイコン設定を確認:

```bash
grep -A1 "CFBundleIconFile" "build/PlayCover Manager.app/Contents/Info.plist"
```

期待される出力:
```xml
<key>CFBundleIconFile</key>
<string>AppIcon</string>
```

### アプリを開いてアイコンを確認:

```bash
open "build/PlayCover Manager.app"
```

Finderでアイコンが表示されているか確認してください。

---

## 📦 配布準備

アイコン付きアプリのビルドに成功したら：

```bash
# ZIPファイルを確認
ls -lh "build/PlayCover Manager-5.0.0.zip"

# GitHub Releasesにアップロード
# または直接配布
```

---

## 📞 サポート

問題が解決しない場合：

1. **debug-icon.shの完全な出力を保存**
   ```bash
   ./debug-icon.sh > debug-output.txt 2>&1
   ```

2. **GitHubでIssueを作成**
   - debug-output.txt を添付
   - macOSバージョンを記載
   - エラーメッセージ全文を記載

3. **一時的な解決策**
   - アイコンなしでビルド（`./build-app.sh`は正常に動作）
   - オンラインツールで.icnsを生成して手動配置
