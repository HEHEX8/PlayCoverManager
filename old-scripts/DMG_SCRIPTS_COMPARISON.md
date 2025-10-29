# DMG作成スクリプト比較ガイド

## 📋 3つのスクリプト

プロジェクトには3つのDMG作成スクリプトがあります。用途に応じて使い分けてください。

---

## 🔧 スクリプト比較

### 1. **create-installer-dmg.sh** (標準)

**特徴**:
- `create-dmg` ツールを使用
- シンプルで高速
- 基本的なレイアウト

**推奨度**: ⭐⭐⭐
**使用場面**: 通常のビルド、CI/CD

**コマンド**:
```bash
./create-installer-dmg.sh
```

**利点**:
- ✅ 高速
- ✅ 信頼性が高い
- ✅ メンテナンスしやすい

**欠点**:
- ⚠️ `.VolumeIcon.icns` が見える場合がある
- ⚠️ 細かいレイアウト調整が難しい

---

### 2. **create-perfect-dmg.sh** (改良版)

**特徴**:
- `create-dmg` + 追加クリーンアップ
- 不可視ファイルを完全に隠す
- レイアウト最適化

**推奨度**: ⭐⭐⭐⭐
**使用場面**: GitHub Releases、正式配布

**コマンド**:
```bash
./create-perfect-dmg.sh
```

**利点**:
- ✅ クリーンな見た目
- ✅ 不可視ファイルを隠す
- ✅ `create-dmg` の利点を保持

**欠点**:
- ⚠️ 少し遅い（マウント/アンマウント処理）

---

### 3. **create-dmg-applescript.sh** (最高品質)

**特徴**:
- AppleScript で完全制御
- Finder表示を直接設定
- 最も柔軟

**推奨度**: ⭐⭐⭐⭐⭐
**使用場面**: 最終リリース、プロダクション

**コマンド**:
```bash
./create-dmg-applescript.sh
```

**利点**:
- ✅ 完璧なレイアウト制御
- ✅ 背景色のカスタマイズ
- ✅ プロフェッショナルな仕上がり
- ✅ 不可視ファイル完全非表示

**欠点**:
- ⚠️ 最も遅い
- ⚠️ AppleScript実行が必要
- ⚠️ Finderウィンドウが一瞬表示される

---

## 🎯 推奨使用方法

### 開発中
```bash
./create-installer-dmg.sh
# 高速、シンプル
```

### テスト配布
```bash
./create-perfect-dmg.sh
# クリーンな見た目
```

### 正式リリース
```bash
./create-dmg-applescript.sh
# 最高品質
```

---

## 📊 詳細比較表

| 項目 | installer | perfect | applescript |
|------|-----------|---------|-------------|
| **速度** | ⚡⚡⚡ | ⚡⚡ | ⚡ |
| **品質** | ⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **レイアウト制御** | 基本 | 良い | 完璧 |
| **不可視ファイル** | 表示される可能性 | 隠す | 完全非表示 |
| **背景色** | なし | なし | カスタム可能 |
| **CI/CD適合性** | ✅ | ✅ | ⚠️ |
| **依存ツール** | create-dmg | create-dmg | hdiutil + osascript |

---

## 🚀 一発コマンド

### 標準ビルド
```bash
cd /Users/hehex/Documents/GitHub/PlayCoverManager && \
git pull origin main && \
rm -rf build AppIcon.iconset AppIcon.icns && \
./create-icon.sh && \
./build-app.sh && \
./create-installer-dmg.sh
```

### 高品質ビルド
```bash
cd /Users/hehex/Documents/GitHub/PlayCoverManager && \
git pull origin main && \
rm -rf build AppIcon.iconset AppIcon.icns && \
./create-icon.sh && \
./build-app.sh && \
./create-perfect-dmg.sh
```

### 最高品質ビルド
```bash
cd /Users/hehex/Documents/GitHub/PlayCoverManager && \
git pull origin main && \
rm -rf build AppIcon.iconset AppIcon.icns && \
./create-icon.sh && \
./build-app.sh && \
./create-dmg-applescript.sh
```

---

## 🔧 カスタマイズポイント

### レイアウト座標

**create-installer-dmg.sh & create-perfect-dmg.sh**:
```bash
--icon "${APP_NAME}.app" 180 200      # アプリの位置
--app-drop-link 480 200               # Applications位置
--window-size 660 450                 # ウィンドウサイズ
--icon-size 128                       # アイコンサイズ
```

**create-dmg-applescript.sh**:
```applescript
set position of item "${APP_NAME}.app" to {180, 180}
set position of item "Applications" to {480, 180}
set the bounds of container window to {200, 120, 860, 520}
set icon size of viewOptions to 128
```

### 背景色

**create-dmg-applescript.sh のみ**:
```applescript
set background color of viewOptions to {11264, 15872, 20480}
# RGB値を65535で正規化: {R*256, G*256, B*256}
# 例: #2c3e50 → {44*256, 62*256, 80*256}
```

---

## 🐛 トラブルシューティング

### Q: `.VolumeIcon.icns` が見える

**A**: `create-perfect-dmg.sh` または `create-dmg-applescript.sh` を使用

### Q: レイアウトが崩れる

**A**: `create-dmg-applescript.sh` を使用（最も確実）

### Q: Finderウィンドウが開く

**A**: AppleScript版の仕様です。自動的に閉じます

### Q: 背景色を変更したい

**A**: `create-dmg-applescript.sh` の背景色設定を編集

### Q: アイコン位置を微調整したい

**A**: 各スクリプトの座標値を編集

---

## 📝 まとめ

### クイックガイド

```
通常のビルド:
  → ./create-installer-dmg.sh

クリーンな見た目が重要:
  → ./create-perfect-dmg.sh

最高品質が必要:
  → ./create-dmg-applescript.sh
```

### おすすめ

**GitHub Releasesにアップロードする場合**:
```bash
./create-dmg-applescript.sh
```

**理由**:
- 最もプロフェッショナルな見た目
- 不可視ファイルが完全に隠れる
- ユーザー体験が最高

---

## 🎨 見た目の違い

### create-installer-dmg.sh
```
✅ ドラッグ&ドロップレイアウト
⚠️  .VolumeIcon.icns が見える可能性
✅ シンプルな白背景
```

### create-perfect-dmg.sh
```
✅ ドラッグ&ドロップレイアウト
✅ 不可視ファイルを隠す
✅ シンプルな白背景
```

### create-dmg-applescript.sh
```
✅ ドラッグ&ドロップレイアウト
✅ 不可視ファイルを完全非表示
✅ カスタム背景色（ダークブルー）
✅ 完璧なアイコン配置
```

---

**推奨**: 正式リリースには `create-dmg-applescript.sh` を使用してください！
