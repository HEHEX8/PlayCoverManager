# 🔍 DMG作成方法の比較

## 📊 3つの方法

| 方法 | 難易度 | 確実性 | カスタマイズ | 推奨度 |
|------|--------|--------|--------------|--------|
| **create-dmg** | ⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ |
| **appdmg** | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **sindresorhus/create-dmg** | ⭐ | ⭐⭐⭐⭐⭐ | ⭐ | ⭐⭐⭐ |

## 🎯 詳細比較

### 1. create-dmg（Shell版）

**GitHub:** https://github.com/create-dmg/create-dmg

#### 特徴
- ✅ macOS標準的な方法
- ✅ コマンドラインで柔軟に設定
- ✅ 背景画像・座標を自由に指定
- ⚠️ 座標は「左上」基準（注意）
- ⚠️ 環境によって動作が不安定な場合あり

#### インストール
```bash
brew install create-dmg
```

#### 使い方
```bash
./create-dmg-background.sh  # 背景画像生成
./create-dmg.sh             # DMG作成
```

#### 座標系
**アイコンの左上を指定**
```bash
--icon "App.app" 110 116
--app-drop-link 422 116
```

#### 推奨ケース
- macOS標準ツールを使いたい
- コマンドラインで完結させたい
- 細かい座標調整が必要

---

### 2. appdmg（Node.js版）⭐ 推奨

**GitHub:** https://github.com/LinusU/node-appdmg

#### 特徴
- ✅ **確実に動作する**（Electronで実績多数）
- ✅ JSON設定で分かりやすい
- ✅ 座標は「中心」基準（直感的）
- ✅ エラーハンドリングが優秀
- ✅ Retina対応も簡単

#### インストール
```bash
brew install node
npm install -g appdmg
```

#### 使い方
```bash
./create-dmg-background-simple.sh  # 背景画像生成
./create-dmg-appdmg.sh             # DMG作成
```

#### 座標系
**アイコンの中心を指定**
```json
{
  "contents": [
    { "x": 150, "y": 200, "type": "file", "path": "App.app" },
    { "x": 450, "y": 200, "type": "link", "path": "/Applications" }
  ]
}
```

#### 推奨ケース
- **確実に動作させたい**（最優先）
- Electron等のNode.js環境がある
- JSON設定が好き
- 複数のプロジェクトで使い回したい

---

### 3. sindresorhus/create-dmg（npm版）

**GitHub:** https://github.com/sindresorhus/create-dmg

#### 特徴
- ✅ **超シンプル**（設定ほぼ不要）
- ✅ 1コマンドで完結
- ✅ 自動で良い感じに配置
- ⚠️ カスタマイズは最小限
- ⚠️ 背景画像の指定不可

#### インストール
```bash
npm install -g create-dmg
```

#### 使い方
```bash
npx create-dmg "build/PlayCover Manager.app"
```

#### 座標系
**自動配置（指定不可）**

#### 推奨ケース
- とにかく簡単に作りたい
- カスタマイズ不要
- シンプルなDMGで十分

---

## 🎯 どれを選ぶべき？

### 🥇 初心者・確実性重視 → **appdmg**

```bash
npm install -g appdmg
./create-dmg-background-simple.sh
./create-dmg-appdmg.sh
```

**理由:**
- 確実に動作する
- 設定がJSON（分かりやすい）
- Electron等で実績多数
- トラブルシューティング情報が豊富

### 🥈 macOS標準・柔軟性重視 → **create-dmg**

```bash
brew install create-dmg
./create-dmg-background.sh
./create-dmg.sh
```

**理由:**
- macOS標準的
- Homebrewで簡単インストール
- 座標を細かく調整可能
- AppleScriptベース

### 🥉 超シンプル・カスタマイズ不要 → **sindresorhus/create-dmg**

```bash
npm install -g create-dmg
npx create-dmg "build/App.app"
```

**理由:**
- 1コマンドで完結
- 設定ファイル不要
- 自動で良い感じに

---

## 📐 座標系の違い（重要！）

### create-dmg（Shell版）
```
--icon "App.app" X Y
```
- **X, Y = アイコンの左上**
- 例: `--icon "App.app" 110 116`

### appdmg（Node.js版）
```json
{ "x": X, "y": Y, "type": "file" }
```
- **X, Y = アイコンの中心**
- 例: `{ "x": 150, "y": 200 }`

### 変換方法
```
appdmg中心座標 → create-dmg左上座標:
  left_x = center_x - icon_size/2
  left_y = center_y - icon_size/2

例（アイコンサイズ128の場合）:
  appdmg: (150, 200) → create-dmg: (86, 136)
```

---

## 🚀 推奨ワークフロー

### 🥇 最も推奨（appdmg）

```bash
# 初回セットアップ
brew install node
npm install -g appdmg
python3 -m pip install --user Pillow

# DMG作成
./build-app.sh
./create-dmg-background-simple.sh
./create-dmg-appdmg.sh

# 確認
open build/PlayCover\ Manager-5.0.0.dmg
```

### 🥈 代替方法（create-dmg）

```bash
# 初回セットアップ
brew install create-dmg
python3 -m pip install --user Pillow

# DMG作成
./build-app.sh
./create-dmg-background.sh
./create-dmg.sh

# 確認
open build/PlayCover\ Manager-5.0.0.dmg
```

---

## 🐛 トラブルシューティング

### アイコンがずれる

**原因:** 座標系の違い

**解決策:**
1. 使用している方法を確認（create-dmg or appdmg）
2. 座標系に合わせて調整
   - create-dmg: 左上座標
   - appdmg: 中心座標

### ボリュームアイコンが表示されない

**原因:** AppIcon.icnsが見つからない

**解決策:**
```bash
./create-icon.sh  # アイコン生成
ls -la AppIcon.icns  # 確認
```

### create-dmgが失敗する

**原因:** AppleScriptの権限問題

**解決策:**
1. システム環境設定 → プライバシーとセキュリティ
2. 「アクセシビリティ」でターミナルを許可
3. または appdmg を使用（より安定）

### appdmgが失敗する

**原因:** 設定ファイルのパス間違い

**解決策:**
```bash
# パスを確認
cat appdmg-config.json

# アプリの存在確認
ls -la "build/PlayCover Manager.app"
```

---

## 📝 まとめ

| 質問 | 答え |
|------|------|
| **一番確実なのは？** | appdmg |
| **一番簡単なのは？** | sindresorhus/create-dmg |
| **一番柔軟なのは？** | create-dmg（Shell版） |
| **初心者に推奨は？** | appdmg |
| **macOS標準は？** | create-dmg（Shell版） |

### 🎯 結論

**迷ったら appdmg を使いましょう！**

理由:
- ✅ 確実に動作する
- ✅ JSON設定で分かりやすい
- ✅ Electron等で実績多数
- ✅ トラブルが少ない

---

**最終更新日:** 2025-01-29  
**推奨方式:** appdmg（Node.js版）
