# PlayCover Manager v4.22.0 - Deletion Preview

**リリース日**: 2025年10月27日  
**重要度**: 🟡 **IMPORTANT** - より安全な運用のためアップデート推奨

---

## 📋 削除プレビュー機能の追加

### ユーザーフィードバック

> 「このコマンドは危険すぎるから何を削除するつもりなのか事前に全部表示してから実行するようにして」

この貴重なフィードバックを受けて、**削除対象を事前に完全表示する機能**を実装しました。

---

## 🎯 新機能: 2フェーズアプローチ

### フェーズ 1: スキャンと表示

実行前に削除対象を完全にスキャンし、6つのカテゴリに分けて表示：

```
🔥 削除対象の確認 🔥
════════════════════════════════════════════════

【1】アンマウントされるボリューム: 3個
  ⏏  PlayCover (disk2s5)
  ⏏  GenshinImpact (disk2s6)
  ⏏  ZenlessZoneZero (disk2s7)

【2】削除されるコンテナ: 3個
  🗑  PlayCover
      /Users/xxx/Library/Containers/io.playcover.PlayCover
  🗑  原神
      /Users/xxx/Library/Containers/com.miHoYo.GenshinImpact
  🗑  ゼンレスゾーンゼロ
      /Users/xxx/Library/Containers/com.HoYoverse.Nap

【3】PlayTools.framework
  🗑  /Users/xxx/Library/Frameworks/PlayTools.framework

【4】キャッシュと設定: 4個
  🗑  io.playcover.PlayCover
  🗑  io.playcover.PlayCover.savedState
  🗑  io.playcover.PlayCover.plist
  🗑  PlayCover

【5】削除されるAPFSボリューム: 3個
  💥  PlayCover (disk2s5)
  💥  原神 (disk2s6)
  💥  ゼンレスゾーンゼロ (disk2s7)

【6】マッピングファイル
  🗑  playcover-map.txt

────────────────────────────────────────────────
合計削除項目: 17個

⚠️  この操作は取り消せません！
────────────────────────────────────────────────

上記の項目をすべて削除しますか？ (yes/no):
```

### フェーズ 2: 実行

確認後、実際の削除を実行：

```
【フェーズ 2/2】クリーンアップを実行します...

【ステップ 1/6】すべてのボリュームをアンマウント
  アンマウント中: PlayCover (disk2s5)
  ✓ 完了
  ...

【ステップ 2/6】すべてのコンテナを削除
  削除中: PlayCover
  ✓ 削除完了
  ...
```

---

## ✨ 主な改善点

### 1. 完全な透明性

**Before (v4.21.1)**:
```
⚠️  警告: この操作は以下を完全に削除します：
  • すべてのPlayCoverアプリとコンテナ
  • すべてのAPFSボリューム（内蔵・外部両方）
  • PlayCoverの設定・キャッシュ・ログ
  • マッピングファイル（playcover-map.txt）

本当に実行しますか？ (yes/no):
```
→ **何が削除されるか具体的に分からない** 😰

**After (v4.22.0)**:
```
【5】削除されるAPFSボリューム: 3個
  💥  PlayCover (disk2s5)
  💥  原神 (disk2s6)
  💥  ゼンレスゾーンゼロ (disk2s7)

合計削除項目: 17個
```
→ **削除対象が完全に明確** ✅

### 2. カテゴリ別表示

6つのカテゴリに分類して表示：

1. **アンマウントされるボリューム** - ⏏ マーク
2. **削除されるコンテナ** - 🗑 マーク + パス表示
3. **PlayTools.framework** - 存在確認
4. **キャッシュと設定** - 個別ファイル名表示
5. **削除されるAPFSボリューム** - 💥 マーク + デバイス情報
6. **マッピングファイル** - 存在確認

### 3. 日本語名での表示

マッピングファイルから日本語名を取得して表示：

```
🗑  原神
    /Users/xxx/Library/Containers/com.miHoYo.GenshinImpact
```

ユーザーが認識しやすい名前で表示されます。

### 4. 削除対象がない場合の処理

```
削除対象が見つかりません
```

空の状態で実行しても安全にキャンセルされます。

---

## 🔍 技術的な実装

### データ収集フェーズ

```bash
# Collect volumes to unmount
local volumes_to_unmount=()

# Collect containers to delete
local containers_to_delete=()

# Collect PlayTools.framework
local playtools_exists=false

# Collect caches and preferences
local cleanup_items=()

# Collect volumes to delete
local volumes_to_delete=()

# Check mapping file
local mapping_exists=false
```

### 安全性チェック

システムボリュームは**スキャン時に除外**：

```bash
# Skip system volumes
if [[ "$vol_name" =~ ^(Macintosh\ HD|Data|Preboot|Recovery|VM|Update|Snapshots|Time\ Machine) ]]; then
    continue
fi
```

### 配列ベースの実行

収集した配列を使って削除を実行：

```bash
# Delete volumes using collected list
if [[ ${#volumes_to_delete[@]} -gt 0 ]]; then
    for vol_info in "${volumes_to_delete[@]}"; do
        local display=$(echo "$vol_info" | cut -d'|' -f1)
        local device=$(echo "$vol_info" | cut -d'|' -f3)
        
        echo "  削除中: ${display} (${device})"
        ...
    done
fi
```

---

## 📊 動作の違い（v4.21.1 vs v4.22.0）

### v4.21.1（プレビューなし）

```
🔥 超強力クリーンアップ（完全リセット）🔥

⚠️  警告: この操作は以下を完全に削除します：
  • すべてのPlayCoverアプリとコンテナ
  • すべてのAPFSボリューム（内蔵・外部両方）
  • PlayCoverの設定・キャッシュ・ログ
  • マッピングファイル（playcover-map.txt）

本当に実行しますか？ (yes/no): yes

⚠️  最終確認: 'DELETE ALL' と正確に入力してください: DELETE ALL

クリーンアップを開始します...
【ステップ 1/6】すべてのボリュームをアンマウント
  アンマウント中: PlayCover (disk2s5)
  ...
```

### v4.22.0（プレビューあり）

```
🔥 超強力クリーンアップ（完全リセット）🔥

【フェーズ 1/2】削除対象をスキャンしています...

🔥 削除対象の確認 🔥

【1】アンマウントされるボリューム: 3個
  ⏏  PlayCover (disk2s5)
  ⏏  原神 (disk2s6)
  ⏏  ゼンレスゾーンゼロ (disk2s7)

【2】削除されるコンテナ: 3個
  🗑  PlayCover
      /Users/xxx/Library/Containers/io.playcover.PlayCover
  🗑  原神
      /Users/xxx/Library/Containers/com.miHoYo.GenshinImpact
  🗑  ゼンレスゾーンゼロ
      /Users/xxx/Library/Containers/com.HoYoverse.Nap

【3】PlayTools.framework
  🗑  /Users/xxx/Library/Frameworks/PlayTools.framework

【4】キャッシュと設定: 4個
  🗑  io.playcover.PlayCover
  🗑  io.playcover.PlayCover.savedState
  🗑  io.playcover.PlayCover.plist
  🗑  PlayCover

【5】削除されるAPFSボリューム: 3個
  💥  PlayCover (disk2s5)
  💥  原神 (disk2s6)
  💥  ゼンレスゾーンゼロ (disk2s7)

【6】マッピングファイル
  🗑  playcover-map.txt

────────────────────────────────────────────────
合計削除項目: 17個

⚠️  この操作は取り消せません！
────────────────────────────────────────────────

上記の項目をすべて削除しますか？ (yes/no): yes

⚠️  最終確認: 'DELETE ALL' と正確に入力してください: DELETE ALL

【フェーズ 2/2】クリーンアップを実行します...

【ステップ 1/6】すべてのボリュームをアンマウント
  アンマウント中: PlayCover (disk2s5)
  ✓ 完了
  ...
```

---

## 🛡️ 安全性の向上

### 1. 視覚的な確認

削除前に**すべての項目を確認可能**：
- ✅ どのボリュームが削除されるか
- ✅ どのコンテナが削除されるか
- ✅ どのファイルが削除されるか
- ✅ 合計いくつの項目が削除されるか

### 2. システムボリューム保護（継続）

v4.21.1の安全機能は**すべて維持**：
- ✅ システムボリュームの明示的スキップ
- ✅ マッピングファイル優先アプローチ
- ✅ 二重確認システム

### 3. 誤操作の防止

削除対象が明確なので：
- ✅ 予期しない削除を防止
- ✅ 確認してからキャンセル可能
- ✅ 透明性の高い運用

---

## 📋 アップグレード手順

### 1. 新バージョンの導入

```bash
# 古いバージョンを削除
rm -f PlayCoverManager.command

# 新しいv4.22.0をダウンロード
# （GitHubまたは配布元から）

# 実行権限を付与
chmod +x PlayCoverManager.command
```

### 2. 使用方法（変更なし）

1. `PlayCoverManager.command` を起動
2. メニューから `5. 🔥 超強力クリーンアップ` を選択
3. **【NEW】削除対象のプレビューを確認**
4. `yes` と入力
5. `DELETE ALL` と入力

---

## 🙏 謝辞

「このコマンドは危険すぎるから何を削除するつもりなのか事前に全部表示してから実行するようにして」

この的確なフィードバックにより、より安全で透明性の高いツールになりました。

ありがとうございました！🙏

---

## 📚 関連ドキュメント

- `NUCLEAR_CLEANUP_GUIDE.md` - 超強力クリーンアップ機能の使用ガイド
- `SAFETY_FIX_SUMMARY.md` - v4.21.1の安全性修正サマリー
- `CHANGELOG_v4.21.1.md` - v4.21.1のリリースノート
- `README.md` - プロジェクト全体のドキュメント

---

**最終更新:** 2025年10月27日
