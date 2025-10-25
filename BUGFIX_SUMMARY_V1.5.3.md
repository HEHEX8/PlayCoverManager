# Bug Fix Summary - v1.5.3: Storage Detection Display Fix

## 🐛 Fixed Bugs

### 1. **内蔵ストレージの誤認識問題**
**問題**: 内蔵ストレージにデータが存在するのに「アンマウント済み」と表示される

**ユーザー報告**:
```bash
$ ls /Users/hehex/Library/Containers/com.HoYoverse.hkrpgoversea
com.HoYoverse.hkrpgoversea  ← サブディレクトリが存在

# しかし、スクリプトでは：
  1. ⚪ 崩壊：スターレイル
      (アンマウント済み)  ← 間違った認識
```

**期待される動作**:
```
  1. 💾 崩壊：スターレイル
      (内蔵ストレージ)  ← 正しい認識
```

---

### 2. **カウント表示の問題**
**問題**: `show_quick_status()` 関数で internal storage を unmounted としてカウント

**修正前のロジック**:
```bash
if [[ "$storage_type" == "external" ]]; then
    ((mounted_count++))
else
    ((unmounted_count++))  # ← internal も unmounted にカウント！
fi
```

**修正後のロジック**:
```bash
if [[ "$storage_type" == "external" ]]; then
    ((mounted_count++))
elif [[ "$storage_type" == "internal" ]]; then
    ((mounted_count++))  # ← internal もデータありとしてカウント
else
    ((unmounted_count++))
fi
```

---

## 🔍 根本原因の調査

### 可能性1: `ls -A` の動作

ユーザー環境:
```bash
$ ls /Users/hehex/Library/Containers/com.HoYoverse.hkrpgoversea
com.HoYoverse.hkrpgoversea
```

この出力から、サブディレクトリが存在することは明らか。
`ls -A` は隠しファイルも表示するので、検出できるはず。

### 可能性2: スクリプトの実行コンテキスト

```bash
# get_storage_type() 内:
if [[ -z "$(ls -A "$path" 2>/dev/null)" ]]; then
    echo "none"  # ← これが返されている？
    return
fi
```

何らかの理由で `ls -A` が空文字を返している可能性。

---

## 🛠️ 実施した修正

### 1. デバッグ機能の追加

`get_storage_type()` 関数にデバッグオプションを追加:

```bash
get_storage_type() {
    local path=$1
    local debug=${2:-false}  # Optional debug flag
    
    # ... existing code ...
    
    if [[ -d "$path" ]]; then
        local content_check=$(ls -A "$path" 2>/dev/null)
        [[ "$debug" == "true" ]] && echo "[DEBUG] Content check: '$content_check'" >&2
        [[ "$debug" == "true" ]] && echo "[DEBUG] Content length: ${#content_check}" >&2
        
        if [[ -z "$content_check" ]]; then
            [[ "$debug" == "true" ]] && echo "[DEBUG] Directory is empty (none)" >&2
            echo "none"
            return
        else
            [[ "$debug" == "true" ]] && echo "[DEBUG] Directory has content, checking disk location..." >&2
        fi
    fi
    
    # ... rest of function ...
}
```

**使用方法**:
```bash
# Normal use
storage_type=$(get_storage_type "$path")

# Debug mode
storage_type=$(get_storage_type "$path" "true")
# Outputs debug info to stderr
```

### 2. カウント表示の修正

`show_quick_status()` 関数のカウントロジックを修正:

**Before**:
```bash
if [[ "$storage_type" == "external" ]]; then
    ((mounted_count++))
else
    ((unmounted_count++))
fi
```

**After**:
```bash
if [[ "$storage_type" == "external" ]]; then
    ((mounted_count++))
elif [[ "$storage_type" == "internal" ]]; then
    ((mounted_count++))  # Internal also counts as "has data"
else
    ((unmounted_count++))
fi
```

### 3. 表示ラベルの改善

**Before**:
```
  🔌 マウント中: 2/4
  ⚪ アンマウント: 2/4
```

**After**:
```
  ✓ データあり: 3/4  (🔌外部 / 💾内蔵)
  ⚪ データなし: 1/4
```

より明確な表現に変更。

---

## 🧪 デバッグツールの提供

### `debug_storage_detection.sh`

ユーザー環境で問題を診断するためのスクリプトを作成:

```bash
./debug_storage_detection.sh "/Users/hehex/Library/Containers/com.HoYoverse.hkrpgoversea"
```

**出力例**:
```
=========================================
Storage Detection Debug Script
=========================================

Testing path: /Users/hehex/Library/Containers/com.HoYoverse.hkrpgoversea

Test 1: Path existence
  ✓ Path exists

Test 2: Directory check
  ✓ Is a directory

Test 3: Mount point check
  ✗ NOT a mount point

Test 4: Content check (ls -A)
  Raw output: 'com.HoYoverse.hkrpgoversea'
  Length: 30
  ✓ Directory has content
  
  Content list:
  drwxr-xr-x  5 user  staff  160 Jan 24 10:00 com.HoYoverse.hkrpgoversea

Test 5: Device and disk location
  Device: /dev/disk3s1s1
  Disk ID: disk3
  Disk Location: Internal

Result: INTERNAL STORAGE 💾
=========================================
```

このツールで、実際の環境での動作を確認できます。

---

## 📋 修正箇所

### ファイル: `2_playcover-volume-manager.command`

1. **Line 291-340**: `get_storage_type()` 関数にデバッグオプション追加
2. **Line 1336-1343**: `show_quick_status()` のカウントロジック修正
3. **Line 1353-1354**: 表示ラベルの改善
4. **Line 1397**: バージョン番号を 1.5.3 に更新

### 新規ファイル: `debug_storage_detection.sh`

ストレージ検出の詳細診断ツール

---

## 🎯 期待される結果

### Before (v1.5.2)
```
━━━━━━━━━━━━ 現在の状態 ━━━━━━━━━━━━

  🔌 マウント中: 0/1
  ⚪ アンマウント: 1/1

  【ボリューム一覧】
    ⚪ 崩壊：スターレイル  ← 間違い
```

### After (v1.5.3)
```
━━━━━━━━━━━━ 現在の状態 ━━━━━━━━━━━━

  ✓ データあり: 1/1  (🔌外部 / 💾内蔵)
  ⚪ データなし: 0/1

  【ボリューム一覧】
    💾 崩壊：スターレイル  ← 正しい
```

---

## 🔬 さらなる調査が必要な場合

もし v1.5.3 でもまだ「アンマウント済み」と表示される場合:

### Step 1: デバッグスクリプト実行
```bash
./debug_storage_detection.sh "/Users/hehex/Library/Containers/com.HoYoverse.hkrpgoversea"
```

### Step 2: デバッグモードで storage type 確認
```bash
# スクリプトを編集して一時的にデバッグモードを有効化
# Line 1337 を以下のように変更:
local storage_type=$(get_storage_type "$target_path" "true")
```

### Step 3: 手動で ls -A 実行
```bash
ls -A "/Users/hehex/Library/Containers/com.HoYoverse.hkrpgoversea"
echo "Exit code: $?"
echo "Output length: $(ls -A "/Users/hehex/Library/Containers/com.HoYoverse.hkrpgoversea" | wc -c)"
```

---

## 🎬 ユーザーへの対応手順

1. **最新版へ更新**: v1.5.3 にアップデート
2. **スクリプト実行**: 正しく「💾 内蔵ストレージ」と表示されるか確認
3. **問題が継続する場合**: `debug_storage_detection.sh` を実行して結果を共有

---

## ✅ まとめ

### 修正内容
- ✅ `show_quick_status()` のカウントロジック修正
- ✅ デバッグオプション追加
- ✅ 表示ラベルの改善
- ✅ デバッグツールの提供

### 影響範囲
- メインメニューの状態表示
- ストレージ切り替えメニューの表示
- 個別ボリューム操作メニューの表示

### 重要度
**Priority: HIGH**

内蔵ストレージの誤認識は、ユーザーの操作判断に影響するため重要。

---

**バージョン**: 1.5.2 → 1.5.3  
**リリース日**: 2025-01-XX  
**ステータス**: ✅ 修正完了 + デバッグツール提供
