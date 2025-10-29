# DMG作成ガイド - PlayCover Manager

## 🎯 概要

PlayCover Managerのための**正しい方法**でDMGインストーラーを作成するガイドです。

### v2の改善点

- ✅ **正しい座標系**: create-dmgの座標は「アイコンの左上」基準
- ✅ **数学的計算**: 手動調整ではなく、計算で正確な位置を決定
- ✅ **整合性**: 背景画像とアイコン位置が完全に一致

## 📋 必要なツール

### 1. create-dmg（必須）

**Homebrewでインストール（推奨）:**
```bash
brew install create-dmg
```

**npmでインストール:**
```bash
npm install -g create-dmg
```

### 2. Python3とPillow

**Python3確認:**
```bash
python3 --version
```

**Pillow（PIL）インストール:**
```bash
python3 -m pip install --user Pillow
```

## 🚀 DMG作成手順

### ステップ1: アプリをビルド

```bash
./build-app.sh
```

**出力:** `build/PlayCover Manager.app`

### ステップ2: 背景画像を作成

```bash
./create-dmg-background-v2.sh
```

**出力:** `dmg-background.png` (660x400px)

このスクリプトは以下を自動計算します：
- アイコンの正確な位置（左上座標）
- 矢印の中心位置
- テキストの配置

### ステップ3: DMGを作成

```bash
./create-dmg-v2.sh
```

**出力:** `build/PlayCover Manager-5.0.0.dmg`

### ステップ4: 確認

```bash
open build/PlayCover\ Manager-5.0.0.dmg
```

## 📐 座標系の理解

### create-dmgの座標指定

```
--icon "App.app" X Y
--app-drop-link X Y
```

この`(X, Y)`は**アイコンの左上**を指定します。

### 座標計算の例

**画面サイズ:** 660x400  
**アイコンサイズ:** 128x128

**左アイコン（左から1/6の位置）:**
```bash
X = 660 / 6 = 110
Y = (400 - 128) / 2 - 20 = 116
```

**右アイコン（右から1/6の位置）:**
```bash
X = 660 * 5 / 6 - 128 = 422
Y = 116（左と同じ高さ）
```

**矢印（2つのアイコン中心の中央）:**
```bash
左アイコン中心 = (110 + 64, 116 + 64) = (174, 180)
右アイコン中心 = (422 + 64, 116 + 64) = (486, 180)
矢印中心 = ((174 + 486) / 2, 180) = (330, 180)
```

## 🎨 カスタマイズ

### 背景画像のカスタマイズ

`create-dmg-background-v2.sh`を編集：

```python
# 色の変更
arrow_color = (70, 70, 70)  # RGB

# テキストの変更
main_text = "ドラッグ&ドロップでインストール"
sub_text = "左のアプリを右のフォルダへ"

# フォントサイズの変更
font_main = ImageFont.truetype("...", 20)  # 20pt
font_sub = ImageFont.truetype("...", 14)   # 14pt
```

### ウィンドウサイズの変更

**両方のスクリプト**で同じ値に変更してください：

```bash
# create-dmg-background-v2.sh
WIDTH=660
HEIGHT=400

# create-dmg-v2.sh
WIDTH=660
HEIGHT=400
```

### アイコンサイズの変更

```bash
# 両方のスクリプトで
ICON_SIZE=128
```

## 🔧 トラブルシューティング

### Q: アイコンがずれている

**A:** 以下を確認：
1. 両方のスクリプトで`WIDTH`、`HEIGHT`、`ICON_SIZE`が一致しているか
2. 背景画像を再生成したか（`./create-dmg-background-v2.sh`）
3. キャッシュされた古いDMGを削除したか

### Q: ボリュームアイコンが表示されない

**A:** `AppIcon.icns`が存在するか確認：
```bash
ls -la AppIcon.icns
```

存在しない場合：
```bash
./create-icon.sh
```

### Q: create-dmgが見つからない

**A:** インストールを確認：
```bash
which create-dmg
```

インストールされていない場合：
```bash
brew install create-dmg
```

### Q: Pillowがインストールできない

**A:** ユーザーディレクトリにインストール：
```bash
python3 -m pip install --user Pillow
```

## 📦 完成したDMGの特徴

✅ **プロフェッショナルな見た目**  
✅ **カスタムボリュームアイコン**  
✅ **ドラッグ&ドロップインストール**  
✅ **日本語の説明文**  
✅ **視覚的な矢印ガイド**  

## 🎉 成功例

正常に作成されると：

1. DMGをマウント
2. Finderウィンドウが開く（660x400）
3. 左側に「PlayCover Manager.app」
4. 右側に「Applications」フォルダ
5. 中央に矢印（左→右）
6. 下部に日本語の説明文

**すべてが完璧に整列しています！**

## 📚 参考資料

- [create-dmg GitHub](https://github.com/create-dmg/create-dmg)
- [DMG Packaging Best Practices](https://stackoverflow.com/questions/96882)

## ⚠️ 重要な注意点

1. **座標はアイコンの左上を指定**（中心ではない）
2. **背景画像サイズ = ウィンドウサイズ**にすること
3. **両方のスクリプトで同じ定数を使用**すること
4. **変更後は必ず背景画像を再生成**すること

---

**最終更新日:** 2025-01-29  
**バージョン:** 2.0（正しい座標系）
