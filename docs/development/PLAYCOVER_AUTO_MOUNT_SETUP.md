# PlayCover 自動マウント設定ガイド

## 概要

PlayCoverを未マウント状態で起動すると内蔵ストレージにデータが作成され、その後ボリュームをマウントできなくなる問題を解決します。

**解決策**: PlayCover起動時に自動的にボリュームをマウントする LaunchAgent を設定

## 問題の詳細

```
⚪️ 未マウント | 🏠 内蔵ストレージにデータ有
```

この状態になると：
- ボリュームマウント不可（内蔵ストレージにデータ存在のため）
- 手動でデータ削除が必要

## インストール手順

### 1. ファイル配置

**スクリプト本体**:
```bash
# ホームディレクトリにコピー
cp playcover-auto-mount.sh ~/playcover-auto-mount.sh
chmod +x ~/playcover-auto-mount.sh
```

**LaunchAgent plist**:
```bash
# plistファイルをコピー
cp com.playcover.automount.plist ~/Library/LaunchAgents/

# ユーザー名を実際の名前に置換（重要！）
sed -i '' 's/YOUR_USERNAME/'"$USER"'/g' ~/Library/LaunchAgents/com.playcover.automount.plist
```

### 2. LaunchAgent 有効化

```bash
# LaunchAgentを読み込み
launchctl load ~/Library/LaunchAgents/com.playcover.automount.plist

# 状態確認
launchctl list | grep com.playcover.automount
```

### 3. 動作確認

#### テスト1: ログファイル確認
```bash
# ログファイルが作成されることを確認
tail -f ~/Library/Logs/playcover-auto-mount.log
```

#### テスト2: 実際の起動テスト
1. PlayCoverボリュームをアンマウント
2. PlayCover.appを起動
3. **期待動作**: 起動前に自動的にボリュームがマウントされる

### 4. トラブルシューティング

#### ログ確認
```bash
# 詳細ログ
cat ~/Library/Logs/playcover-auto-mount.log

# LaunchAgent標準出力
cat /tmp/playcover-automount.out

# LaunchAgent エラー出力
cat /tmp/playcover-automount.err
```

#### LaunchAgent再起動
```bash
# アンロード
launchctl unload ~/Library/LaunchAgents/com.playcover.automount.plist

# 再ロード
launchctl load ~/Library/LaunchAgents/com.playcover.automount.plist
```

#### 手動実行テスト
```bash
# スクリプトが正しく動作するか確認
~/playcover-auto-mount.sh
echo $?  # 0 = 成功, 1 = エラー
```

## 動作仕様

### 実行タイミング
- `/Applications/PlayCover.app` が変更された時（起動時含む）
- システム起動時（RunAtLoad）

### 実行条件チェック
1. ✅ PlayCoverボリュームが存在するか
2. ✅ 既に正しくマウント済みか
3. ✅ 内蔵ストレージにデータが存在しないか（**重要**）
4. ✅ マウント実行

### エラー時の動作
- ログファイルにエラー記録
- 通知センターに警告表示
- PlayCover起動は継続（ユーザー対応可能）

## 安全性

### データ保護
- **内蔵ストレージにデータが既に存在する場合はマウントしない**
- データ消失リスクなし
- エラー時は通知で警告

### 既存システムへの影響
- PlayCover以外のアプリには影響なし
- システムリソース消費は最小限
- アンインストールはplist削除のみで完全に削除可能

## アンインストール

```bash
# LaunchAgent停止・削除
launchctl unload ~/Library/LaunchAgents/com.playcover.automount.plist
rm ~/Library/LaunchAgents/com.playcover.automount.plist

# スクリプト削除
rm ~/playcover-auto-mount.sh

# ログ削除（任意）
rm ~/Library/Logs/playcover-auto-mount.log
```

## 統合管理

メインスクリプト (`playcover-complete-manager.command`) に統合することも可能：

```bash
# 自動マウント設定メニューを追加
# - LaunchAgent インストール
# - LaunchAgent アンインストール  
# - 動作確認
```

## 注意事項

1. **ユーザー名の置換を忘れずに**: plistファイル内の`YOUR_USERNAME`を実際のユーザー名に置換
2. **実行権限の付与**: `chmod +x`を忘れずに
3. **初回テスト**: 必ず動作確認を実施してから本番運用
4. **ログ監視**: 問題発生時はログファイルを確認

## 技術詳細

### WatchPaths の仕組み
- `/Applications/PlayCover.app` のファイルシステム変更を監視
- アプリ起動時は実行ファイルが読み込まれるため変更イベント発生
- LaunchAgentがイベントを検知してスクリプト実行

### マウント前チェックの重要性
```bash
# 内蔵ストレージのデータチェック（システムファイル除外）
CONTENT_CHECK=$(/bin/ls -A1 "$PLAYCOVER_CONTAINER" 2>/dev/null | \
    /usr/bin/grep -v -x -F '.DS_Store' | \
    /usr/bin/grep -v -x -F '.Spotlight-V100' | \
    # ... その他システムファイル
)
```

このチェックがないと、既存データを上書きしてしまう危険性があります。

---

**作成日**: 2025-10-26  
**対象**: PlayCover自動マウント問題  
**ステータス**: ✅ 完成（テスト待ち）
