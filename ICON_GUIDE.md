# アイコン設定ガイド

## 📁 現在のアイコン

プロジェクトには既にアイコン画像が用意されています：
- **ファイル**: `app-icon.png`
- **サイズ**: 1024x1024 (JPEG形式)
- **出典**: PlayCover Manager用カスタムアイコン

---

## 🎨 macOSアプリケーションにアイコンを追加する

### ステップ1: アイコンファイルの生成（macOS上で実行）

```bash
# macOS環境で実行
./create-icon.sh
```

このスクリプトは以下を実行します：
1. `app-icon.png` から複数サイズのPNGを生成
2. `AppIcon.iconset` ディレクトリに配置
3. `iconutil` で `.icns` ファイルに変換

**生成されるファイル**:
- `AppIcon.iconset/` - 10種類のサイズのPNGファイル
- `AppIcon.icns` - macOS用アイコンファイル（最終成果物）

---

### ステップ2: アプリケーションのビルド

```bash
# AppIcon.icnsが存在する状態でビルド
./build-app.sh
```

`build-app.sh` は自動的に：
- `AppIcon.icns` を検出
- アプリバンドルの `Contents/Resources/` にコピー
- `Info.plist` にアイコン設定を追加

---

## 🖥️ Linux環境での制限事項

現在の開発環境（Linux sandbox）では、macOS専用ツール（`sips`, `iconutil`）が使えないため、`.icns` ファイルは生成できません。

### 解決方法

**方法1: macOS環境で実行（推奨）**
```bash
# macOSマシンで
git clone https://github.com/HEHEX8/PlayCoverManager.git
cd PlayCoverManager
./create-icon.sh
./build-app.sh
```

**方法2: オンラインツールで変換**
1. `app-icon.png` をダウンロード
2. オンラインツール（例: https://cloudconvert.com/png-to-icns）でPNG→ICNS変換
3. 生成された `AppIcon.icns` をプロジェクトルートに配置
4. `./build-app.sh` を実行

**方法3: アイコンなしでビルド**
```bash
# アイコンなしでもアプリは正常に動作します
./build-app.sh
# デフォルトのアイコンが使用されます
```

---

## 📋 必要なアイコンサイズ

macOSアプリケーションには以下のサイズが必要です：

| サイズ | ファイル名 | 用途 |
|-------|-----------|------|
| 16x16 | icon_16x16.png | メニューバー |
| 32x32 | icon_16x16@2x.png | Retinaメニューバー |
| 32x32 | icon_32x32.png | Dock（小） |
| 64x64 | icon_32x32@2x.png | Retina Dock（小） |
| 128x128 | icon_128x128.png | Dock（通常） |
| 256x256 | icon_128x128@2x.png | Retina Dock（通常） |
| 256x256 | icon_256x256.png | Dock（大） |
| 512x512 | icon_256x256@2x.png | Retina Dock（大） |
| 512x512 | icon_512x512.png | Quick Look |
| 1024x1024 | icon_512x512@2x.png | Retina Quick Look |

---

## 🔄 アイコンの更新

### 新しいアイコンに変更する場合

1. **新しい画像を準備**
   ```bash
   # 1024x1024以上のPNGまたはJPEG
   cp /path/to/new-icon.png app-icon.png
   ```

2. **古いアイコンファイルを削除**
   ```bash
   rm -f AppIcon.icns
   rm -rf AppIcon.iconset
   ```

3. **再生成**
   ```bash
   # macOS環境で
   ./create-icon.sh
   ./build-app.sh
   ```

---

## ✅ アイコン設定の確認

### ビルド後の確認方法

```bash
# アイコンが含まれているか確認
ls -lh "build/PlayCover Manager.app/Contents/Resources/AppIcon.icns"

# Info.plistでアイコン設定を確認
grep -A1 "CFBundleIconFile" "build/PlayCover Manager.app/Contents/Info.plist"
```

### 期待される出力

```xml
<key>CFBundleIconFile</key>
<string>AppIcon</string>
```

---

## 🎯 トラブルシューティング

### Q: アイコンが表示されない

**A: 以下を確認**
1. `AppIcon.icns` が存在するか
2. `build-app.sh` を再実行
3. Finderのキャッシュをクリア:
   ```bash
   # macOS上で
   sudo rm -rfv /Library/Caches/com.apple.iconservices.store
   sudo find /private/var/folders/ -name com.apple.iconservices -exec rm -rfv {} \;
   killall Dock
   ```

### Q: create-icon.sh が動かない

**A: macOS環境で実行していますか？**
- Linux/Windows環境では `sips` と `iconutil` が使えません
- オンライン変換ツールを使用してください

### Q: アイコンがぼやける

**A: 高解像度の元画像を使用**
- 最低1024x1024のPNGまたはJPEGを用意
- ベクター形式（SVG）から書き出すのが最適

---

## 📦 Git管理

### 含めるファイル
- ✅ `app-icon.png` - 元画像（1024x1024）
- ✅ `create-icon.sh` - アイコン生成スクリプト
- ✅ `ICON_GUIDE.md` - このガイド

### 含めないファイル（.gitignore）
- ❌ `AppIcon.iconset/` - 中間ファイル
- ❌ `AppIcon.icns` - 生成ファイル（macOS環境で生成）
- ❌ `build/` - ビルド出力

**理由**: `.icns` ファイルはmacOS環境でのみ生成可能なため、Git管理から除外し、各環境で生成します。

---

## 🚀 配布時の推奨手順

1. **macOS環境でビルド**
   ```bash
   git clone https://github.com/HEHEX8/PlayCoverManager.git
   cd PlayCoverManager
   ./create-icon.sh  # アイコン生成
   ./build-app.sh    # アプリビルド（アイコン含む）
   ```

2. **GitHub Releasesにアップロード**
   ```bash
   # build/PlayCover Manager-5.0.0.zip をアップロード
   # アイコンが含まれたアプリが配布されます
   ```

---

## 📚 参考リンク

- [Apple Human Interface Guidelines - App Icon](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- [iconutil Manual](https://ss64.com/osx/iconutil.html)
- [PNG to ICNS Converter](https://cloudconvert.com/png-to-icns)
