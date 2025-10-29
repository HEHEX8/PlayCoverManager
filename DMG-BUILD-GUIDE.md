# DMG作成ガイド

## 🎯 推奨方法（業界標準）

**`create-dmg`ツールを使用**する方法が最も簡単で確実です。

### 必要なツール

```bash
# Node.jsのインストール（Homebrewを使用）
brew install node

# create-dmgツールのインストール
npm install -g create-dmg

# GraphicsMagickのインストール（ボリュームアイコン自動生成用、オプション）
brew install graphicsmagick
```

### 基本的なDMG作成手順

```bash
# 1. アプリアイコンを作成
./create-icon.sh

# 2. アプリをビルド
./build-app.sh

# 3. シンプルなDMGを作成
./create-dmg-modern.sh
```

### 背景画像付きDMGの作成手順

```bash
# 1. アプリアイコンを作成
./create-icon.sh

# 2. アプリをビルド
./build-app.sh

# 3. 背景画像を生成（Python PILが必要）
./create-dmg-background.sh

# 4. 背景画像付きDMGを作成
./create-dmg-with-background.sh
```

## 📋 各スクリプトの説明

### `create-dmg-modern.sh`（推奨）
- **使用ツール**: `create-dmg`（Node.js CLI）
- **特徴**:
  - ✅ ボリュームアイコン自動設定
  - ✅ アイコンレイアウト自動配置
  - ✅ コード署名サポート（オプション）
  - ✅ ライセンス追加サポート
- **出力**: シンプルで確実なDMG

### `create-dmg-with-background.sh`（カスタム背景）
- **使用ツール**: `create-dmg` + カスタム背景画像
- **特徴**:
  - ✅ カスタム背景画像（矢印＋説明文）
  - ✅ ボリュームアイコン自動設定
  - ✅ ドラッグ&ドロップの視覚的ガイド
- **出力**: プロフェッショナルな見た目のDMG

### `create-dmg-applescript.sh`（レガシー）
- **使用ツール**: `hdiutil` + `AppleScript`
- **特徴**: 完全にカスタマイズ可能だが複雑
- **問題点**: 
  - ⚠️ ボリュームアイコン設定が不安定
  - ⚠️ AppleScriptのタイミング問題
- **非推奨**: `create-dmg`ツールを使用してください

## 🎨 背景画像のカスタマイズ

### 背景画像の仕様
- **サイズ**: 660 x 400 ピクセル
- **フォーマット**: PNG（推奨）
- **アイコン配置**:
  - 左側アプリ: x=160, y=185
  - 右側Applications: x=500, y=185

### 背景画像の編集
`create-dmg-background.sh`を編集して、矢印や文字の位置・色・サイズを変更できます。

```python
# 矢印の位置
arrow_start_x = 290
arrow_end_x = 435
arrow_y = 185

# 矢印の色
arrow_color = (80, 80, 80)  # RGB

# テキストの内容
main_text = "ドラッグ&ドロップでインストール"
sub_text = "左のアプリを右のフォルダへ"
```

## 🔐 コード署名とNotarization

```bash
# コード署名付きDMG
create-dmg \
    --codesign "Developer ID Application: Your Name" \
    --volname "PlayCover Manager" \
    ...

# Notarization（Apple公証）
xcrun notarytool submit "PlayCover Manager-5.0.0.dmg" \
    --apple-id "your@email.com" \
    --password "app-specific-password" \
    --team-id "TEAM_ID"
```

## 🐛 トラブルシューティング

### Q: ボリュームアイコンが表示されない
A: `create-dmg`ツールを使用してください。自動的に設定されます。

### Q: 矢印がアイコンに被っている
A: `create-dmg-background.sh`の矢印位置を調整してください：
```python
arrow_start_x = 290  # この値を大きくする
arrow_end_x = 435    # この値を小さくする
```

### Q: Pillowがインストールできない
A: 
```bash
python3 -m pip install --user Pillow
```

### Q: create-dmgツールが見つからない
A: 
```bash
npm install -g create-dmg
# または
brew install create-dmg
```

## 📚 参考リンク

- [create-dmg GitHub](https://github.com/sindresorhus/create-dmg)
- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [Homebrew](https://brew.sh/)
