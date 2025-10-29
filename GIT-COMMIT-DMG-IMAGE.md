# 🖼️ DMG背景画像のGitコミット方法

## 問題

macOS上で`dmg-background.png`を生成したが、gitが検出しない。

## 原因

`.gitignore`の設定により、以下が除外されています：
- `build/` - ビルド成果物
- `*.dmg` - DMGファイル
- `AppIcon.icns` - 生成されたアイコン

**注意:** `dmg-background.png`は通常gitで追跡すべきです（ソースファイル）。

## 解決方法

### 1. .gitignoreを確認

```bash
cd /Users/hehex/Documents/GitHub/PlayCoverManager
cat .gitignore | grep png
```

### 2. もし`*.png`が含まれていたら

#### 方法A: .gitignoreを編集（推奨）

```bash
# .gitignoreから*.pngを削除
sed -i '' '/\*.png/d' .gitignore

# または手動で編集
nano .gitignore
```

#### 方法B: 強制的に追加

```bash
git add -f dmg-background.png
git commit -m "DMG背景画像を追加"
git push origin main
```

### 3. 通常のコミット

```bash
# 全ての変更を追加
git add .

# コミット
git commit -m "DMG背景画像を追加"

# プッシュ
git push origin main
```

## 📋 完全な手順

```bash
cd /Users/hehex/Documents/GitHub/PlayCoverManager

# 1. 最新版を取得
git pull origin main

# 2. 背景画像を生成
./create-dmg-background-simple.sh

# 3. .gitignoreを確認
cat .gitignore

# 4. 強制的に追加（.gitignoreで除外されていても）
git add -f dmg-background.png

# 5. コミット
git commit -m "DMG背景画像を追加（600x400、appdmg用）"

# 6. プッシュ
git push origin main
```

## 🔍 トラブルシューティング

### Q: `git add .`で検出されない

**原因:** `.gitignore`で除外されている

**解決策:**
```bash
# 強制的に追加
git add -f dmg-background.png
```

### Q: `.gitignore`の内容を確認したい

```bash
cat .gitignore
```

### Q: `.gitignore`から`*.png`を削除したい

```bash
# sedで削除（macOS）
sed -i '' '/\*.png/d' .gitignore

# またはnanoで編集
nano .gitignore
```

## ✅ 確認方法

```bash
# gitの状態を確認
git status

# dmg-background.pngが表示されればOK
```

---

**最終更新日:** 2025-01-29
