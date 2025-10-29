# 🚀 DMG作成クイックスタート

## 📋 必要なもの

✅ macOS（Sequoia 15.1+推奨）  
✅ Homebrew  
✅ create-dmg  
✅ Python3とPillow

## ⚡ 3ステップで完成

### 1️⃣ ツールをインストール

```bash
# Homebrewでcreate-dmgをインストール
brew install create-dmg

# Pythonライブラリをインストール
python3 -m pip install --user Pillow
```

### 2️⃣ アプリをビルド

```bash
cd /path/to/PlayCoverManager

# アプリケーションをビルド
./build-app.sh
```

**出力:** `build/PlayCover Manager.app` ✅

### 3️⃣ DMGを作成

```bash
# 背景画像を生成
./create-dmg-background.sh

# DMGを作成
./create-dmg.sh
```

**出力:** `build/PlayCover Manager-5.0.0.dmg` 🎉

## ✨ 完成！

DMGファイルができました：

```bash
# DMGを開いて確認
open build/PlayCover\ Manager-5.0.0.dmg
```

## 📐 何が作られるか

### DMGの中身

1. **左側**: PlayCover Manager.app（128x128アイコン）
2. **中央**: 矢印（左→右）
3. **右側**: Applications フォルダへのリンク
4. **下部**: 日本語の説明文

### 座標系の仕組み

```
ウィンドウサイズ: 660x400
アイコンサイズ: 128x128

左アイコン位置（左上座標）:
  X = 660 / 6 = 110
  Y = (400 - 128) / 2 - 20 = 116

右アイコン位置（左上座標）:
  X = 660 * 5 / 6 - 128 = 422
  Y = 116

矢印: 2つのアイコンの中心を結ぶ
```

## 🔧 カスタマイズ

### 背景色を変更

`create-dmg-background.sh`を編集：

```python
# 背景色（RGB）
img = Image.new('RGB', (WIDTH, HEIGHT), color=(200, 208, 214))

# 矢印の色
arrow_color = (70, 70, 70)
```

### テキストを変更

```python
main_text = "ドラッグ&ドロップでインストール"
sub_text = "左のアプリを右のフォルダへ"
```

### サイズを変更

**重要:** 両方のスクリプトで同じ値に！

```bash
# create-dmg-background.sh
WIDTH=660
HEIGHT=400
ICON_SIZE=128

# create-dmg.sh
WIDTH=660
HEIGHT=400
ICON_SIZE=128
```

## 🐛 トラブルシューティング

### Q: create-dmgが見つからない

```bash
brew install create-dmg
```

### Q: Pillowがインストールできない

```bash
python3 -m pip install --user Pillow
```

### Q: アイコンがずれる

1. 両方のスクリプトで`WIDTH`/`HEIGHT`/`ICON_SIZE`が同じか確認
2. 背景画像を再生成: `./create-dmg-background.sh`
3. DMGを再作成: `./create-dmg.sh`

### Q: ボリュームアイコンが表示されない

```bash
# アイコンファイルを確認
ls -la AppIcon.icns

# 無ければ生成
./create-icon.sh
```

## 📚 詳細ドキュメント

完全ガイド: [DMG-BUILD-README.md](DMG-BUILD-README.md)

---

**最終更新:** 2025-01-29  
**これでプロフェッショナルなDMGインストーラーが作れます！** 🎉
