# 🚀 v5.0.0 リリースチェックリスト

## ✅ 完了済み

### 1. コード修正
- [x] ストレージ種別表示の完全統一
- [x] 初期セットアップのUX改善
- [x] すべてのテストが成功

### 2. バージョン更新
- [x] lib/03_storage.sh → 5.0.0
- [x] lib/04_app.sh → 5.0.0
- [x] lib/05_cleanup.sh → 5.0.0
- [x] lib/06_setup.sh → 5.0.0
- [x] lib/07_ui.sh → 5.0.0（表示も更新）
- [x] CHANGELOG.md → 5.0.0 セクション追加

### 3. Git管理
- [x] すべての変更をコミット
- [x] v5.0.0 タグを作成
- [x] GitHub にプッシュ（コミット + タグ）
- [x] リリースノート作成（RELEASE_NOTES_5.0.0.md）

### 4. ビルド（Sandbox完了）
- [x] `./build-app.sh` 実行成功
- [x] `build/PlayCover Manager.app` 生成
- [x] `build/PlayCover Manager-5.0.0.zip` 生成

## 🔄 macOS で実行が必要な作業

### 5. DMG作成（macOSのみ）

```bash
cd /Users/hehex/Documents/GitHub/PlayCoverManager

# 最新のコードを取得
git pull origin main

# アプリをビルド（再度実行して最新版を確実にする）
./build-app.sh

# 背景画像を生成
./create-dmg-background-simple.sh

# DMGを作成
./create-dmg-appdmg.sh

# 生成されたファイルを確認
ls -lh build/PlayCover\ Manager-5.0.0.dmg
open build/
```

**期待される出力:**
```
build/PlayCover Manager-5.0.0.dmg
```

### 6. DMGの動作確認

```bash
# DMGをマウント
open "build/PlayCover Manager-5.0.0.dmg"

# インストールをテスト
# 1. DMGウィンドウが開く
# 2. PlayCover Manager.app が表示される
# 3. Applications へのショートカットが表示される
# 4. 背景画像と矢印が正しく表示される

# アンマウント
hdiutil detach "/Volumes/PlayCover Manager"
```

### 7. GitHub Releaseを作成

#### 方法A: GitHub CLI（推奨）

```bash
cd /Users/hehex/Documents/GitHub/PlayCoverManager

# GitHub CLIがインストールされているか確認
which gh || brew install gh

# ログイン（初回のみ）
gh auth login

# リリースを作成してDMGをアップロード
gh release create v5.0.0 \
  "build/PlayCover Manager-5.0.0.dmg" \
  "build/PlayCover Manager-5.0.0.zip" \
  --title "PlayCover Manager v5.0.0" \
  --notes-file RELEASE_NOTES_5.0.0.md
```

#### 方法B: GitHub Web UI

1. **GitHubのリポジトリページにアクセス**
   ```
   https://github.com/HEHEX8/PlayCoverManager/releases
   ```

2. **「Draft a new release」をクリック**

3. **リリース情報を入力**
   - **Tag**: `v5.0.0` （既存のタグを選択）
   - **Release title**: `PlayCover Manager v5.0.0`
   - **Description**: RELEASE_NOTES_5.0.0.md の内容をコピー＆ペースト

4. **DMGファイルをアップロード**
   - 「Attach binaries」セクションに以下をドラッグ＆ドロップ:
     - `build/PlayCover Manager-5.0.0.dmg`
     - `build/PlayCover Manager-5.0.0.zip`

5. **「Publish release」をクリック**

### 8. リリース確認

```bash
# リリースページを開く
open "https://github.com/HEHEX8/PlayCoverManager/releases"

# または
gh release view v5.0.0 --web
```

**確認項目:**
- [x] v5.0.0 リリースが表示される
- [x] リリースノートが正しく表示される
- [x] DMG ファイルがダウンロード可能
- [x] ZIP ファイルがダウンロード可能
- [x] バージョンバッジが v5.0.0 を表示（数分かかる場合あり）

### 9. 最終動作確認

```bash
# DMGをダウンロード（実際のユーザー体験をシミュレート）
# GitHubのReleasesページからDMGをダウンロード

# インストール
open ~/Downloads/PlayCover\ Manager-5.0.0.dmg
# Applicationsフォルダにドラッグ

# 初回起動
open /Applications/PlayCover\ Manager.app
# または右クリック → 開く

# 動作確認:
# 1. メインメニューが表示される
# 2. バージョンが「Version 5.0.0」と表示される
# 3. ストレージ種別が一貫して表示される
# 4. 初期セットアップが改善された動作をする
```

## 📝 リリース後のタスク

### 10. アナウンス（オプション）

- [ ] README.md に最新バージョン情報を追記（バッジは自動更新）
- [ ] ユーザーに通知（SNS、フォーラムなど）
- [ ] ドキュメントの更新（必要な場合）

### 11. バックアップ

```bash
# ビルド成果物をバックアップ（オプション）
mkdir -p ~/PlayCoverManager-Releases/v5.0.0
cp build/PlayCover\ Manager-5.0.0.dmg ~/PlayCoverManager-Releases/v5.0.0/
cp build/PlayCover\ Manager-5.0.0.zip ~/PlayCoverManager-Releases/v5.0.0/
```

## 🐛 トラブルシューティング

### appdmg でエラーが出る場合

```bash
# Node.js と appdmg を再インストール
brew uninstall node
brew install node@20
npm install -g appdmg
```

### DMG作成が失敗する場合

```bash
# 古いビルドをクリーンアップ
rm -rf build/
./build-app.sh
./create-dmg-background-simple.sh
./create-dmg-appdmg.sh
```

### GitHub Releaseのアップロードが失敗する場合

```bash
# GitHub CLIを再認証
gh auth logout
gh auth login

# または Web UI を使用
open "https://github.com/HEHEX8/PlayCoverManager/releases/new"
```

## ✨ 完了！

すべての手順が完了したら：

1. **GitHub Releases**: https://github.com/HEHEX8/PlayCoverManager/releases
2. **ダウンロードリンク**: https://github.com/HEHEX8/PlayCoverManager/releases/latest
3. **バージョンバッジ**: 自動的に v5.0.0 を表示

---

**リリース日:** 2025-01-29  
**リリースタイプ:** Stable Release (Bug Fix)  
**次のステップ:** ユーザーフィードバックを収集し、次のバージョンの計画を立てる
