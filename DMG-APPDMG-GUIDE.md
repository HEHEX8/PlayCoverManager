# 🎯 appdmg方式 - 確実に動くDMG作成ガイド

## ✨ なぜappdmg？

- ✅ **確実に動作する**: Electron等で実績多数
- ✅ **JSONで設定**: シンプルで分かりやすい
- ✅ **座標が明確**: 中心座標で指定（直感的）
- ✅ **カスタマイズ簡単**: 設定ファイルを編集するだけ

## 📋 必要なツール

### Node.js（npm）

```bash
# Homebrewでインストール
brew install node

# 確認
node --version
npm --version
```

### appdmg

```bash
# グローバルインストール
npm install -g appdmg

# 確認
appdmg --version
```

### Python3とPillow（背景画像用）

```bash
# Python3確認
python3 --version

# Pillowインストール
python3 -m pip install --user Pillow
```

## 🚀 3ステップで完成

### ステップ1: アプリをビルド

```bash
cd /path/to/PlayCoverManager
./build-app.sh
```

**出力:** `build/PlayCover Manager.app` ✅

### ステップ2: 背景画像を作成（オプション）

```bash
./create-dmg-background-simple.sh
```

**出力:** `dmg-background.png` (600x400px) ✅

### ステップ3: DMGを作成

```bash
./create-dmg-appdmg.sh
```

**出力:** `build/PlayCover Manager-5.0.0.dmg` 🎉

## 📐 設定ファイル（appdmg-config.json）

```json
{
  "title": "PlayCover Manager",
  "icon": "AppIcon.icns",
  "background": "dmg-background.png",
  "icon-size": 128,
  "window": {
    "size": {
      "width": 600,
      "height": 400
    },
    "position": {
      "x": 200,
      "y": 120
    }
  },
  "contents": [
    {
      "x": 150,
      "y": 200,
      "type": "file",
      "path": "build/PlayCover Manager.app"
    },
    {
      "x": 450,
      "y": 200,
      "type": "link",
      "path": "/Applications"
    }
  ]
}
```

### 📍 座標の意味

**重要:** appdmgの座標は**アイコンの中心**を指定します

```
ウィンドウサイズ: 600x400
アイコンサイズ: 128x128

左アイコン（中心座標）:
  x = 150 (左から1/4の位置)
  y = 200 (中央)

右アイコン（中心座標）:
  x = 450 (右から1/4の位置)
  y = 200 (左と同じ高さ)

矢印:
  中心 = (150 + 450) / 2 = 300
  長さ = 120px
  範囲: 240 → 360
```

## 🎨 カスタマイズ

### ウィンドウサイズの変更

`appdmg-config.json`を編集：

```json
"window": {
  "size": {
    "width": 800,
    "height": 500
  }
}
```

背景画像も同じサイズに変更：

```bash
# create-dmg-background-simple.sh
WIDTH=800
HEIGHT=500
```

### アイコン位置の変更

```json
"contents": [
  {
    "x": 200,  // 左右に移動
    "y": 250,  // 上下に移動
    "type": "file",
    "path": "build/PlayCover Manager.app"
  }
]
```

### アイコンサイズの変更

```json
"icon-size": 100,  // 128 → 100に変更
```

### 背景なしバージョン

`appdmg-config.json`から背景行を削除：

```json
{
  "title": "PlayCover Manager",
  "icon": "AppIcon.icns",
  // "background": "dmg-background.png",  <- この行を削除またはコメントアウト
  "icon-size": 128,
  ...
}
```

## 🔧 トラブルシューティング

### Q: appdmgが見つからない

```bash
npm install -g appdmg
```

### Q: npmが見つからない

```bash
brew install node
```

### Q: DMG作成が失敗する

1. アプリのパスを確認：
```bash
ls -la "build/PlayCover Manager.app"
```

2. 設定ファイルの内容を確認：
```bash
cat appdmg-config.json
```

3. 背景画像を確認：
```bash
ls -la dmg-background.png
```

### Q: アイコンがずれている

appdmgの座標は**中心座標**です。create-dmgの**左上座標**とは異なります。

**修正方法:**
1. `appdmg-config.json`の座標を調整
2. DMGを再作成
3. 確認して微調整

## 📊 create-dmgとの違い

| 項目 | create-dmg | appdmg |
|------|-----------|--------|
| 座標系 | 左上 | 中心 |
| 設定方法 | コマンドライン | JSON |
| 実績 | macOS標準 | Electron多数 |
| カスタマイズ | オプション多数 | JSONで明確 |
| 推奨度 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

## 🎯 推奨ワークフロー

```bash
# 1回目: テンプレート作成
./build-app.sh
./create-dmg-background-simple.sh
./create-dmg-appdmg.sh

# 確認
open build/PlayCover\ Manager-5.0.0.dmg

# 2回目以降: 再ビルドのみ
./build-app.sh
./create-dmg-appdmg.sh
```

## 📚 参考資料

- [appdmg GitHub](https://github.com/LinusU/node-appdmg)
- [electron-installer-dmg](https://github.com/electron-userland/electron-installer-dmg)
- [実用例の記事](https://www.christianengvall.se/dmg-installer-electron-app/)

## ✅ 成功例

正常に作成されると：

1. DMGをマウント
2. Finderウィンドウが開く（600x400）
3. 左側に「PlayCover Manager.app」（中心座標: 150, 200）
4. 右側に「Applications」フォルダ（中心座標: 450, 200）
5. 中央に矢印（背景画像）
6. 下部に日本語の説明文（背景画像）

**すべてが完璧に整列します！** 🎉

---

**最終更新日:** 2025-01-29  
**方式:** appdmg（確実に動作する方法）
