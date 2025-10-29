# DMG作成ガイド

## 🎨 プロフェッショナルなDMGインストーラーの作成

標準のシンプルなDMGではなく、ドラッグ&ドロップレイアウトを持つプロフェッショナルなDMGを作成します。

---

## 📋 前提条件

### macOS環境が必要
- このスクリプトはmacOS上でのみ動作します
- `create-dmg` ツールを使用

### create-dmgのインストール

```bash
# Homebrewでインストール
brew install create-dmg
```

---

## 🚀 使い方

### ステップ1: アプリをビルド

```bash
cd /Users/hehex/Documents/GitHub/PlayCoverManager

# 最新コードを取得
git pull origin main

# アイコン生成
rm -rf AppIcon.iconset AppIcon.icns
./create-icon.sh

# アプリビルド
./build-app.sh
```

### ステップ2: プロフェッショナルDMGを作成

```bash
# DMGインストーラーを作成
./create-installer-dmg.sh
```

---

## 🎯 一発コマンド

```bash
cd /Users/hehex/Documents/GitHub/PlayCoverManager && \
git pull origin main && \
rm -rf build AppIcon.iconset AppIcon.icns && \
./create-icon.sh && \
./build-app.sh && \
./create-installer-dmg.sh
```

---

## 📦 作成されるDMG

### レイアウト

```
┌─────────────────────────────────────────────────┐
│  PlayCover Manager                              │
├─────────────────────────────────────────────────┤
│                                                 │
│                                                 │
│        [📱 App Icon]         [📁 Applications]│
│      PlayCover Manager                          │
│                                 ↑               │
│                        ここにドラッグ            │
│                                                 │
│                                                 │
└─────────────────────────────────────────────────┘
```

### 特徴

- ✅ **カスタムアイコンサイズ**: 128x128
- ✅ **Applicationsフォルダへのリンク**: 自動配置
- ✅ **ウィンドウサイズ**: 660x450 (最適サイズ)
- ✅ **アイコン配置**: 左側にアプリ、右側にApplications
- ✅ **ボリュームアイコン**: アプリのアイコンを使用
- ✅ **ファイル拡張子**: 非表示

---

## 🔧 カスタマイズ

### create-installer-dmg.sh の設定

```bash
# ウィンドウサイズ
--window-size 660 450

# アイコンサイズ
--icon-size 128

# アプリアイコンの位置 (x, y)
--icon "PlayCover Manager.app" 160 180

# Applicationsリンクの位置 (x, y)
--app-drop-link 500 180

# ウィンドウの初期位置
--window-pos 200 120
```

### 位置の調整

```bash
# アプリを左寄せ
--icon "PlayCover Manager.app" 160 180

# Applicationsを右寄せ
--app-drop-link 500 180

# 間隔を調整
# X座標を変更: 160 → 120 (左に移動)
# X座標を変更: 500 → 540 (右に移動)
```

---

## 📊 比較: 標準 vs プロフェッショナル

### 標準DMG (build-app.sh)

```
利点:
- シンプル
- 追加ツール不要
- Linux環境でもビルド可能

欠点:
- レイアウトが固定されない
- ユーザーが手動でApplicationsフォルダを探す必要
- 見た目が素朴
```

### プロフェッショナルDMG (create-installer-dmg.sh)

```
利点:
- ドラッグ&ドロップが明確
- アイコン配置が最適化
- ユーザー体験が向上
- プロフェッショナルな印象

欠点:
- macOS環境が必須
- create-dmgツールが必要
```

---

## 🎨 背景画像のカスタマイズ（高度）

### 背景画像を作成

```bash
# ImageMagickをインストール
brew install imagemagick

# 背景画像を作成
./create-dmg-background.sh
```

### create-installer-dmg.sh に背景を追加

```bash
create-dmg \
  --volname "${VOLUME_NAME}" \
  --background "dmg-background.png" \  # 追加
  --window-pos 200 120 \
  --window-size 660 450 \
  ...
```

---

## 🔍 トラブルシューティング

### Q: create-dmg コマンドが見つからない

**A**: Homebrewでインストール
```bash
brew install create-dmg
```

### Q: AppIcon.icns が見つからない

**A**: アイコンを先に生成
```bash
./create-icon.sh
```

### Q: アプリが見つからない

**A**: アプリを先にビルド
```bash
./build-app.sh
```

### Q: DMGのレイアウトを変更したい

**A**: `create-installer-dmg.sh` の座標を編集
```bash
# アイコンの位置
--icon "PlayCover Manager.app" 160 180
#                              ↑X  ↑Y

# Applicationsの位置
--app-drop-link 500 180
#               ↑X  ↑Y
```

---

## 📋 出力ファイル

### 成功時

```
build/
├── PlayCover Manager.app           (アプリ本体)
├── PlayCover Manager-5.0.0.zip     (ZIP配布)
└── PlayCover Manager-5.0.0.dmg     (DMGインストーラー)
```

### ファイルサイズ

```
PlayCover Manager.app:       ~75KB
PlayCover Manager-5.0.0.zip: ~63KB
PlayCover Manager-5.0.0.dmg: ~100KB (プロフェッショナル版)
```

---

## 🚀 配布推奨

### GitHub Releasesにアップロード

1. **ZIP**: すべてのプラットフォームで展開可能
   ```
   PlayCover Manager-5.0.0.zip
   ```

2. **DMG**: macOS標準のインストール方法
   ```
   PlayCover Manager-5.0.0.dmg
   ```

### 推奨配布方法

```
GitHub Releases:
├── PlayCover Manager-5.0.0.zip  (必須)
└── PlayCover Manager-5.0.0.dmg  (推奨)

ユーザーは好きな方を選択可能
```

---

## ✨ まとめ

### 基本ビルド
```bash
./build-app.sh
# → ZIP配布用
```

### プロフェッショナル配布
```bash
./build-app.sh && ./create-installer-dmg.sh
# → ZIP + DMG配布用
```

**推奨**: 両方作成してGitHub Releasesにアップロード！
