# リリースプロセス

## バージョン 5.0.0-alpha2 のリリース手順

### 1. ✅ 完了済み: コード修正とバージョン更新

- [x] バグ修正（ストレージ種別表示の統一、初期セットアップUX改善）
- [x] バージョン番号更新（5.0.0-alpha1 → 5.0.0-alpha2）
- [x] CHANGELOG.md 作成
- [x] Gitコミット、タグ作成、プッシュ

### 2. macOS環境でのビルド（DMGとZIP作成）

このステップは **macOS環境** で実行する必要があります。

```bash
# リポジトリの最新版を取得
cd /path/to/PlayCoverManager
git pull origin main
git checkout v5.0.0-alpha2

# アプリをビルド
./build-app.sh

# 背景画像を作成（初回のみ、または更新が必要な場合）
./create-dmg-background-simple.sh

# DMGインストーラーを作成
./create-dmg-appdmg.sh
```

**生成されるファイル:**
- `build/PlayCover Manager.app` - アプリケーションバンドル
- `build/PlayCover Manager-5.0.0.zip` - ZIP配布版
- `PlayCover Manager-5.0.0-alpha2.dmg` - DMGインストーラー

### 3. GitHub Releasesの作成

#### オプション A: Web UIから（推奨）

1. **GitHubリポジトリにアクセス**
   - https://github.com/HEHEX8/PlayCoverManager/releases

2. **"Draft a new release" をクリック**

3. **リリース情報を入力**
   - **Tag**: `v5.0.0-alpha2` （既存のタグを選択）
   - **Release title**: `v5.0.0-alpha2 - ストレージ表示統一とUX改善`
   - **Description**:
     ```markdown
     ## 🎉 v5.0.0-alpha2 リリース
     
     ### 🐛 重要な修正
     
     #### 1. ストレージ種別表示の完全統一
     - メインメニュー、アプリ管理、ボリューム情報、ストレージ切替で表示が食い違っていた問題を修正
     - 全ての画面で一貫したストレージ種別表示を実現
     
     #### 2. 初期セットアップのUX改善
     - Enter押下回数を削減（8回 → 必要時のみ）
     - ディスク選択の無効入力時に再試行ループを実装
     - より詳細なエラーメッセージを表示
     
     ### 📦 インストール方法
     
     #### DMGインストーラー（推奨）
     1. `PlayCover.Manager-5.0.0-alpha2.dmg` をダウンロード
     2. DMGをマウント
     3. PlayCover Manager.app を Applications フォルダにドラッグ
     4. アプリを右クリック → 「開く」で初回起動
     
     #### ZIP版
     1. `PlayCover.Manager-5.0.0.zip` をダウンロード
     2. 解凍して Applications フォルダに移動
     
     ### 📖 ドキュメント
     - [README](https://github.com/HEHEX8/PlayCoverManager/blob/main/README.md)
     - [CHANGELOG](https://github.com/HEHEX8/PlayCoverManager/blob/main/CHANGELOG.md)
     
     ### ⚠️ 注意事項
     - Apple Silicon Mac 専用
     - macOS Sequoia 15.1 以降が必要
     - PlayCover 3.0 以降が必要
     ```

4. **ファイルをアップロード**
   - `PlayCover Manager-5.0.0-alpha2.dmg` をドラッグ&ドロップ
   - `build/PlayCover Manager-5.0.0.zip` をドラッグ&ドロップ

5. **"Publish release" をクリック**

#### オプション B: GitHub CLIから

```bash
# GitHub CLIがインストールされている場合
gh release create v5.0.0-alpha2 \
  --title "v5.0.0-alpha2 - ストレージ表示統一とUX改善" \
  --notes-file RELEASE-NOTES.md \
  "PlayCover Manager-5.0.0-alpha2.dmg#DMGインストーラー" \
  "build/PlayCover Manager-5.0.0.zip#ZIP配布版"
```

### 4. リリース後の確認

- [ ] リリースページが正しく表示されることを確認
- [ ] DMGとZIPがダウンロード可能であることを確認
- [ ] README.mdの「最新リリース」バッジが更新されることを確認
- [ ] GitHubのReleasesページに表示されることを確認

### 5. 次のステップ

#### ユーザーへの通知
- Discordサーバーでアナウンス（該当する場合）
- Twitterで告知（該当する場合）
- README.mdに最新情報を追加

#### フィードバック収集
- GitHub Issuesで問題報告を受け付け
- ユーザーからのフィードバックを収集
- 次のリリース計画を立案

---

## トラブルシューティング

### DMG作成が失敗する場合

**エラー**: `dmg-background.png not found`
```bash
# 背景画像を作成（macOSのみ）
./create-dmg-background-simple.sh
```

**エラー**: `appdmg command not found`
```bash
# appdmgをインストール
npm install -g appdmg
```

### GitHub Releasesへのアップロードが失敗する場合

1. **リポジトリの権限を確認**
   - GitHub設定でリリース作成権限があるか確認

2. **タグが正しくプッシュされているか確認**
   ```bash
   git tag -l | grep v5.0.0-alpha2
   git push origin v5.0.0-alpha2
   ```

3. **ファイルサイズを確認**
   - GitHubは2GBまでのファイルをサポート
   - 大きなファイルはGit LFSを使用

---

## 参考リンク

- [GitHub Releases公式ドキュメント](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository)
- [appdmg GitHubリポジトリ](https://github.com/LinusU/node-appdmg)
- [Semantic Versioning](https://semver.org/)
- [Keep a Changelog](https://keepachangelog.com/)
