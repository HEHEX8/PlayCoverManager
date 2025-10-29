# 🚀 DMGファイルのリリース方法

## ❌ gitにDMGを含めない理由

- DMGファイルは大きい（数十〜数百MB）
- Gitはバイナリファイルに適していない
- リポジトリサイズが肥大化する
- **GitHub Releases**が正しい配布方法

## ✅ 正しい方法：GitHub Releases

### ステップ1: DMGを作成

```bash
cd /Users/hehex/Documents/GitHub/PlayCoverManager

# アプリをビルド
./build-app.sh

# 背景画像を生成
./create-dmg-background-simple.sh

# DMGを作成
./create-dmg-appdmg.sh

# 確認
ls -lh build/PlayCover\ Manager-5.0.0.dmg
```

### ステップ2: GitHub Releaseを作成（Web UI）

1. **GitHubのリポジトリページにアクセス**
   ```
   https://github.com/HEHEX8/PlayCoverManager
   ```

2. **Releasesセクションに移動**
   - 右側の「Releases」をクリック
   - または直接アクセス: `https://github.com/HEHEX8/PlayCoverManager/releases`

3. **新しいリリースを作成**
   - 「Create a new release」または「Draft a new release」をクリック

4. **リリース情報を入力**
   ```
   Tag: v5.0.0
   Release title: PlayCover Manager v5.0.0
   Description:
   
   ## 🎉 PlayCover Manager v5.0.0
   
   ### ダウンロード
   - **DMGインストーラー（推奨）**: PlayCover Manager-5.0.0.dmg
   
   ### インストール方法
   1. DMGファイルをダウンロード
   2. ダブルクリックでマウント
   3. PlayCover Manager.appをApplicationsフォルダにドラッグ
   
   ### 主な機能
   - APFS外部ボリューム管理
   - 内蔵⇄外部ストレージ切り替え
   - バッチ操作
   
   ### システム要件
   - macOS Sequoia 15.1+
   - Apple Silicon (M1/M2/M3/M4)
   ```

5. **DMGファイルをアップロード**
   - 「Attach binaries」セクションにDMGをドラッグ＆ドロップ
   - または「choose your files」をクリックして選択

6. **公開**
   - 「Publish release」をクリック

### ステップ3: GitHub CLI（gh）を使う方法

```bash
cd /Users/hehex/Documents/GitHub/PlayCoverManager

# GitHub CLIがインストールされているか確認
brew install gh

# ログイン（初回のみ）
gh auth login

# リリースを作成してDMGをアップロード
gh release create v5.0.0 \
  "build/PlayCover Manager-5.0.0.dmg" \
  --title "PlayCover Manager v5.0.0" \
  --notes "
## 🎉 PlayCover Manager v5.0.0

### ダウンロード
- **DMGインストーラー（推奨）**: PlayCover Manager-5.0.0.dmg

### インストール方法
1. DMGファイルをダウンロード
2. ダブルクリックでマウント
3. PlayCover Manager.appをApplicationsフォルダにドラッグ

### 主な機能
- APFS外部ボリューム管理
- 内蔵⇄外部ストレージ切り替え
- バッチ操作

### システム要件
- macOS Sequoia 15.1+
- Apple Silicon (M1/M2/M3/M4)
"
```

### ステップ4: リリースを更新（既存のリリースにDMG追加）

```bash
# 既存のリリースにファイルを追加
gh release upload v5.0.0 "build/PlayCover Manager-5.0.0.dmg"
```

## 📦 完全な手順（推奨）

```bash
cd /Users/hehex/Documents/GitHub/PlayCoverManager

# 1. 最新のコードを確認
git pull origin main
git status

# 2. ビルドとDMG作成
./build-app.sh
./create-dmg-background-simple.sh
./create-dmg-appdmg.sh

# 3. DMGを確認
open build/

# 4. GitHub CLIでリリース（推奨）
gh release create v5.0.0 \
  "build/PlayCover Manager-5.0.0.dmg" \
  --title "PlayCover Manager v5.0.0" \
  --notes-file RELEASE_NOTES_5.0.0.md

# または手動でGitHub Webからアップロード
```

## 🔍 確認方法

1. **GitHubのReleasesページを開く**
   ```
   https://github.com/HEHEX8/PlayCoverManager/releases
   ```

2. **v5.0.0が表示されているか確認**

3. **DMGファイルがダウンロードできるか確認**

## 🎯 ベストプラクティス

### ✅ すべきこと

1. **GitHub Releasesを使う**
   - DMGファイルはここに配置
   - ダウンロード数も追跡できる

2. **バージョンタグを付ける**
   - `v5.0.0`のような明確なタグ

3. **リリースノートを書く**
   - 変更内容を明記
   - インストール方法を記載

4. **複数の配布形式を提供**
   - DMG（推奨）
   - ZIP（オプション）

### ❌ やってはいけないこと

1. **gitにDMGをコミット**
   - リポジトリが肥大化
   - クローンが遅くなる

2. **ビルド成果物をgitに含める**
   - `build/`ディレクトリは`.gitignore`で除外

3. **バージョン管理しない**
   - 必ずタグを付ける

## 📊 ファイルサイズの目安

| ファイル | サイズ | Git管理 |
|---------|--------|---------|
| ソースコード | KB〜MB | ✅ Yes |
| 背景画像(.png) | KB | ✅ Yes |
| アイコン(.icns) | KB | ⚠️ 生成物 |
| .app | MB〜数十MB | ❌ No |
| .dmg | 数十MB〜数百MB | ❌ No |

## 🔗 参考リンク

- [GitHub Releases ドキュメント](https://docs.github.com/en/repositories/releasing-projects-on-github)
- [gh release コマンド](https://cli.github.com/manual/gh_release)

---

**最終更新日:** 2025-01-29  
**推奨方法:** GitHub Releases + GitHub CLI
