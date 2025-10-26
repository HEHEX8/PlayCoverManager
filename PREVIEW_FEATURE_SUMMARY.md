# 🎯 v4.22.0 削除プレビュー機能 - 実装サマリー

## ユーザーフィードバック

> **「このコマンドは危険すぎるから何を削除するつもりなのか事前に全部表示してから実行するようにして」**

この貴重なフィードバックを受けて、**完全な削除プレビュー機能**を実装しました。

---

## 🔄 実装の流れ

### Before (v4.21.1): 即座に実行

```
🔥 超強力クリーンアップ（完全リセット）🔥

⚠️  警告: この操作は以下を完全に削除します：
  • すべてのPlayCoverアプリとコンテナ
  • すべてのAPFSボリューム（内蔵・外部両方）
  • PlayCoverの設定・キャッシュ・ログ
  • マッピングファイル（playcover-map.txt）

⚠️  この操作は取り消せません！

本当に実行しますか？ (yes/no): ← 何が削除されるか不明確
```

### After (v4.22.0): プレビュー → 確認 → 実行

```
🔥 超強力クリーンアップ（完全リセット）🔥

【フェーズ 1/2】削除対象をスキャンしています...

🔥 削除対象の確認 🔥
════════════════════════════════════════════════

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

ℹ️  ゲームデータはアカウントに紐付いているため、
    再インストール後に復元できます
────────────────────────────────────────────────

上記の項目をすべて削除しますか？ (yes/no): ← すべて明確！
```

---

## 📋 実装された機能

### 1. 2フェーズアプローチ

#### フェーズ 1: スキャンと表示

```bash
# 1. ボリュームをスキャン
local volumes_to_unmount=()
local volumes_to_delete=()

# 2. コンテナをスキャン
local containers_to_delete=()

# 3. PlayTools.frameworkをチェック
local playtools_exists=false

# 4. キャッシュ・設定をスキャン
local cleanup_items=()

# 5. マッピングファイルをチェック
local mapping_exists=false

# 6. すべて表示
echo "【1】アンマウントされるボリューム: ${#volumes_to_unmount[@]}個"
echo "【2】削除されるコンテナ: ${#containers_to_delete[@]}個"
...
echo "合計削除項目: ${total_items}個"
```

#### フェーズ 2: 確認後に実行

```bash
# 確認後、収集した配列を使って削除
for vol_info in "${volumes_to_unmount[@]}"; do
    # アンマウント実行
done

for container_info in "${containers_to_delete[@]}"; do
    # コンテナ削除実行
done

for vol_info in "${volumes_to_delete[@]}"; do
    # ボリューム削除実行
done
```

### 2. カテゴリ別表示

#### 【1】アンマウントされるボリューム

```
⏏  PlayCover (disk2s5)
⏏  原神 (disk2s6)
⏏  ゼンレスゾーンゼロ (disk2s7)
```

- デバイス名付きで表示
- 日本語名を使用

#### 【2】削除されるコンテナ

```
🗑  PlayCover
    /Users/xxx/Library/Containers/io.playcover.PlayCover
🗑  原神
    /Users/xxx/Library/Containers/com.miHoYo.GenshinImpact
```

- 日本語表示名 + フルパス
- 削除されるディレクトリが明確

#### 【3】PlayTools.framework

```
🗑  /Users/xxx/Library/Frameworks/PlayTools.framework
```

または

```
✓  存在しません（削除不要）
```

- 存在確認済み表示

#### 【4】キャッシュと設定

```
🗑  io.playcover.PlayCover
🗑  io.playcover.PlayCover.savedState
🗑  io.playcover.PlayCover.plist
🗑  PlayCover
```

- 個別ファイル名を列挙

#### 【5】削除されるAPFSボリューム

```
💥  PlayCover (disk2s5)
💥  原神 (disk2s6)
💥  ゼンレスゾーンゼロ (disk2s7)
```

- **最も危険な操作**なので💥マーク
- デバイス名と日本語名を表示

#### 【6】マッピングファイル

```
🗑  playcover-map.txt
```

または

```
✓  存在しません（削除不要）
```

### 3. 日本語名の活用

マッピングファイルから日本語名を取得：

```bash
if [[ -f "$MAPPING_FILE" ]]; then
    local map_name=$(grep "$container" "$MAPPING_FILE" 2>/dev/null | awk -F'\t' '{print $3}')
    [[ -n "$map_name" ]] && display_name="$map_name"
fi
```

**結果**:
- `com.miHoYo.GenshinImpact` → **原神**
- `com.HoYoverse.Nap` → **ゼンレスゾーンゼロ**
- `com.HoYoverse.hkrpgoversea` → **崩壊：スターレイル**

ユーザーが認識しやすい！

### 4. 合計カウント

```
────────────────────────────────────────────────
合計削除項目: 17個
────────────────────────────────────────────────
```

削除されるアイテムの総数を明示。

### 5. 空の状態処理

削除対象が何もない場合：

```
削除対象が見つかりません

Enterキーでメニューに戻る...
```

安全にキャンセル。

---

## 🛡️ 安全性の向上

### 1. システムボリューム保護（継続）

スキャン時にシステムボリュームを除外：

```bash
# Skip system volumes
if [[ "$vol_name" =~ ^(Macintosh\ HD|Data|Preboot|Recovery|VM|Update|Snapshots|Time\ Machine) ]]; then
    continue
fi
```

v4.21.1の安全機能は**すべて維持**。

### 2. 配列ベースの実行

- スキャン時に配列に格納
- 実行時は配列から取得
- **再スキャンなし**（より安全で高速）

```bash
# Scan phase
volumes_to_delete+=("${display}|${vol_name}|${device}")

# Execution phase
for vol_info in "${volumes_to_delete[@]}"; do
    local display=$(echo "$vol_info" | cut -d'|' -f1)
    local device=$(echo "$vol_info" | cut -d'|' -f3)
    
    echo "  削除中: ${display} (${device})"
    sudo diskutil apfs deleteVolume "$device"
done
```

### 3. 完全な透明性

**すべての操作が事前に可視化**：
- ✅ 何が削除されるか
- ✅ どこにあるか
- ✅ いくつ削除されるか

誤操作のリスクが激減！

---

## 📊 コード変更サマリー

### 追加されたコード量

- **約300行**の新しいコード
- スキャンロジック: 約150行
- 表示ロジック: 約100行
- リファクタリング: 約50行

### 変更箇所

1. **nuclear_cleanup() 関数の完全リライト**
   - Before: 直接削除を実行
   - After: スキャン → 表示 → 確認 → 実行

2. **データ構造の導入**
   ```bash
   local volumes_to_unmount=()      # 配列
   local containers_to_delete=()    # 配列
   local volumes_to_delete=()       # 配列
   local cleanup_items=()           # 配列
   local playtools_exists=false     # ブール値
   local mapping_exists=false       # ブール値
   ```

3. **表示フォーマットの統一**
   - 6カテゴリ分類
   - アイコンの統一（⏏ 🗑 💥 ✓）
   - 色分け（CYAN, RED, YELLOW, GREEN）

---

## 🎯 ユーザー体験の改善

### Before (v4.21.1)

```
😰 不安: 何が削除されるか分からない
😰 恐怖: システムボリュームが表示されてパニック
😰 後悔: 削除後に「あれも消えた？」
```

### After (v4.22.0)

```
😌 安心: すべて明確に表示される
😌 確認: 削除前にチェック可能
😌 透明: 何も隠されていない
😌 信頼: 安全だと分かって実行できる
```

---

## 🔍 実装の工夫

### 1. パイプ区切り文字列

配列の各要素は `|` で区切られた文字列：

```bash
volumes_to_delete+=("${display}|${vol_name}|${device}")

# 使用時
local display=$(echo "$vol_info" | cut -d'|' -f1)
local vol_name=$(echo "$vol_info" | cut -d'|' -f2)
local device=$(echo "$vol_info" | cut -d'|' -f3)
```

**メリット**:
- 複数の情報を1つの要素にパック
- `cut` で簡単に分割
- zsh の配列制約に対応

### 2. 日本語名フォールバック

```bash
# Get display name from mapping if available
local display_name="$container"
if [[ -f "$MAPPING_FILE" ]]; then
    local map_name=$(grep "$container" "$MAPPING_FILE" 2>/dev/null | awk -F'\t' '{print $3}')
    [[ -n "$map_name" ]] && display_name="$map_name"
fi
```

マッピングファイルがあれば日本語名、なければBundle ID。

### 3. 存在チェックの最適化

```bash
# Scan phase
local playtools_exists=false
if [[ -d "$playtools_path" ]]; then
    playtools_exists=true
fi

# Display phase
if [[ "$playtools_exists" == true ]]; then
    echo "  🗑  ${playtools_path}"
else
    echo "  ✓  存在しません（削除不要）"
fi
```

スキャン時に1回だけチェック。

---

## 📚 関連ドキュメント

- `CHANGELOG_v4.22.0.md` - 詳細な変更ログ
- `SAFETY_FIX_SUMMARY.md` - v4.21.1の安全性修正
- `NUCLEAR_CLEANUP_GUIDE.md` - 機能使用ガイド
- `README.md` - プロジェクト全体のドキュメント

---

## 🙏 謝辞

**「このコマンドは危険すぎるから何を削除するつもりなのか事前に全部表示してから実行するようにして」**

この明確で的確なフィードバックにより、**より安全で透明性の高いツール**になりました。

危険な操作だからこそ、**完全な透明性**が必要。このフィードバックの重要性を改めて実感しました。

ありがとうございました！🙏

---

**作成日**: 2025年10月27日  
**バージョン**: v4.22.0  
**改善内容**: 削除プレビュー機能の追加
