# ボリューム操作関連 統一共通関数化サマリー

## 📋 採用した実装の一覧

### 1. load_mappings_array()
**採用元**: `lib/07_ui.sh` - `individual_volume_control()` の実装
```bash
# 元の実装（644-651行目）
local -a mappings_array=()
while IFS=$'\t' read -r volume_name bundle_id display_name recent_flag; do
    [[ -z "$volume_name" || -z "$bundle_id" ]] && continue
    mappings_array+=("${volume_name}|${bundle_id}|${display_name}")
done < "$MAPPING_FILE"
```
**理由**: 
- recent_flagを無視し、必要な3列のみ抽出
- パイプ区切りで統一フォーマット
- エラーハンドリングが適切

---

### 2. check_any_app_running()
**採用元**: `lib/07_ui.sh` - `individual_volume_control()` の実装
```bash
# 元の実装（667-676行目）
local any_app_running=false
for ((j=1; j<=${#mappings_array}; j++)); do
    IFS='|' read -r _ check_bundle_id _ <<< "${mappings_array[$j]}"
    if [[ "$check_bundle_id" != "$PLAYCOVER_BUNDLE_ID" ]]; then
        if is_app_running "$check_bundle_id"; then
            any_app_running=true
            break
        fi
    fi
done
```
**理由**:
- PlayCoverを除外する処理が明確
- 早期break最適化
- PlayCoverロック判定に必要な情報

---

### 3. get_volume_lock_status()
**採用元**: `lib/07_ui.sh` - `individual_volume_control()` の実装
```bash
# 元の実装（692-708行目）
if [[ "$bundle_id" == "$PLAYCOVER_BUNDLE_ID" ]]; then
    if is_playcover_running; then
        is_locked=true
        lock_reason="app_running"
    elif [[ "$any_app_running" == "true" ]]; then
        is_locked=true
        lock_reason="app_storage"
    fi
else
    if is_app_running "$bundle_id"; then
        is_locked=true
        lock_reason="app_running"
    fi
fi
```
**理由**:
- PlayCoverの特殊なロック条件を正確に実装
- `app_running` vs `app_storage` の区別が明確
- 表示メッセージに必要な情報を提供

---

### 4. get_volume_detailed_status()
**採用元**: `lib/07_ui.sh` - `individual_volume_control()` の実装
```bash
# 元の実装（710-774行目）
local actual_mount=$(validate_and_get_mount_point_cached "$volume_name")
local vol_status=$?

if [[ $vol_status -eq 1 ]]; then
    status_line="❌ ボリュームが見つかりません"
elif [[ $vol_status -eq 0 ]]; then
    # Volume is mounted...
    if [[ -z "$actual_mount" ]]; then
        # Cache stale protection
        local storage_mode=$(get_storage_mode "$target_path" "$volume_name")
        # ...
    elif [[ "$actual_mount" == "$target_path" ]]; then
        status_line="🟢 マウント済: ${actual_mount}"
    else
        status_line="⚠️  マウント位置異常: ${actual_mount}"
    fi
else
    # Volume exists but not mounted (vol_status == 2)
    local storage_mode=$(get_storage_mode "$target_path" "$volume_name")
    # ...
fi
```
**理由**:
- キャッシュstale保護機能
- 3つのボリューム状態を網羅（not_found/mounted/unmounted）
- storage_modeの完全な処理
- マウント位置異常検出

---

### 5. format_volume_display_entry()
**採用元**: `lib/07_ui.sh` - `individual_volume_control()` の実装
```bash
# 元の実装（777-809行目）
if $is_locked; then
    if [[ "$lock_reason" == "app_running" ]]; then
        echo "  ${BOLD}🔒 ${GOLD}ロック中${NC} ... | 🏃 アプリ動作中${NC}"
    elif [[ "$lock_reason" == "app_storage" ]]; then
        echo "  ${BOLD}🔒 ${GOLD}ロック中${NC} ... | 🚬 下記アプリの終了待機中${NC}"
    fi
elif [[ "$extra_info" == "internal_intentional" ]] || [...]; then
    echo "  ${BOLD}🔒 ${GOLD}ロック中${NC} ... | 🍎 内蔵ストレージモード${NC}"
elif [[ "$extra_info" == "internal_contaminated" ]]; then
    echo "  ${BOLD}${YELLOW}${display_index}.${NC} ... ${BOLD}${ORANGE}⚠️  内蔵データ検出${NC}"
else
    echo "  ${BOLD}${CYAN}${display_index}.${NC} ${BOLD}${WHITE}${display_name}${NC}"
fi
```
**理由**:
- 最も詳細な表示ロジック
- アイコンとカラーが統一
- 戻り値でselectable判定が可能
- internal_intentional_emptyも適切に処理

---

## 🔄 リファクタリング前後の比較

### individual_volume_control()
**変更前**: 180行（632-811行目）
**変更後**: 50行
**削減**: **130行（72%削減）**

### batch_mount_all()
**変更前**: マッピング読み込みに9行
**変更後**: 共通関数呼び出しで5行
**削減**: 4行

### batch_unmount_all()
**変更前**: マッピング読み込みに7行
**変更後**: 共通関数呼び出しで5行
**削減**: 2行

### show_quick_status()
**変更前**: マッピング読み込み+ステータス判定で45行
**変更後**: 共通関数使用で35行
**削減**: 10行

---

## 📊 統計

- **総削減行数**: 159行
- **追加行数**: 236行（共通関数実装）
- **純増減**: +77行（機能追加と汎用化）
- **重複削減**: 3箇所 → 1箇所（共通関数）

---

## ✅ 採用しなかった実装

### lib/02_volume.sh の batch_mount_all/batch_unmount_all
- マッピング読み込み部分のみ共通関数化
- batch特有の処理（storage_mode判定、ユーザー確認）は個別実装を維持

### lib/07_ui.sh の show_quick_status
- ボリューム詳細ステータス取得は共通関数化
- 統計カウント（external/internal/unmounted）は独自ロジックを維持

**理由**: これらは用途が異なるため、完全統一は不適切。共通部分のみ関数化。

---

## 🎯 今後の拡張性

共通関数により、以下が容易に：
1. 新しいストレージモードの追加
2. 表示フォーマットの統一変更
3. ロック条件の追加
4. デバッグ用ログ出力の追加

すべての変更が1箇所（00_core.sh）で完結します。
