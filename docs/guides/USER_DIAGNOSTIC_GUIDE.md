# 診断ガイド - マウント保護の問題

## 🔍 現在の状況

### ユーザー様の報告

1. **ストレージ切り替えメニュー**: 「⚪ アンマウント済み」と表示（正しい）
2. **マウント試行**: マウント保護がブロック（間違い？）
3. **手動確認**: `ls` コマンドで空ディレクトリを確認

### 矛盾点

- 空ディレクトリなのに、マウント保護が「内蔵ストレージが存在する」と判定
- これは `mount_volume()` 関数内の `ls -A` チェックが何かを検出している

---

## 🧪 診断手順

### ステップ1: マウント保護ロジックの詳細確認

以下のスクリプトを実行してください：

```bash
cd /path/to/script
./test_mount_protection.sh "/Users/hehex/Library/Containers/com.HoYoverse.hkrpgoversea"
```

**期待される出力**:
```
========================================
Mount Protection Logic Debug
========================================

Testing path: /Users/hehex/Library/Containers/com.HoYoverse.hkrpgoversea

Step 1: Check if directory exists
  ✓ Directory exists

Step 2: Check if it's a mount point
  ✓ NOT a mount point

Step 3: Check directory content (ls -A)
  Command: ls -A "/Users/hehex/Library/Containers/com.HoYoverse.hkrpgoversea"
  Raw output: ''
  Output length: 0 characters
  Output bytes: 0

  Detailed listing (ls -la):
  total 0
  drwxr-xr-x  2 user  staff   64 Jan 25 10:00 .
  drwx------+ 5 user  staff  160 Jan 25 10:00 ..

Step 4: Protection decision
  ✓ ALLOWED: Directory is empty
  → Mount protection will ALLOW mounting
  → Empty directory will be deleted first

========================================
```

**もし出力が異なる場合**（例：Content detected）、その内容を共有してください。

### ステップ2: ls と ls -A の比較

```bash
# 通常の ls
echo "=== ls ==="
ls "/Users/hehex/Library/Containers/com.HoYoverse.hkrpgoversea"

# 隠しファイルを含む ls -A
echo ""
echo "=== ls -A ==="
ls -A "/Users/hehex/Library/Containers/com.HoYoverse.hkrpgoversea"

# 詳細表示 ls -la
echo ""
echo "=== ls -la ==="
ls -la "/Users/hehex/Library/Containers/com.HoYoverse.hkrpgoversea"

# ファイル数カウント
echo ""
echo "=== File count ==="
echo "Total files: $(ls -A "/Users/hehex/Library/Containers/com.HoYoverse.hkrpgoversea" 2>/dev/null | wc -l | xargs)"
```

### ステップ3: マウント状態の確認

```bash
# マウントポイントの確認
echo "=== Mount check ==="
mount | grep "com.HoYoverse.hkrpgoversea"

# ディスクユーティリティでの確認
echo ""
echo "=== Diskutil check ==="
diskutil info "/Users/hehex/Library/Containers/com.HoYoverse.hkrpgoversea" 2>&1 | head -20
```

### ステップ4: 権限の確認

```bash
# ディレクトリの権限
ls -ld "/Users/hehex/Library/Containers/com.HoYoverse.hkrpgoversea"

# 親ディレクトリの確認
ls -la "/Users/hehex/Library/Containers" | grep "hkrpg"
```

---

## 🤔 考えられる原因

### 原因1: 隠しファイルの存在

`ls` では表示されないが、`ls -A` では検出される隠しファイル（`.DS_Store` など）が存在する可能性。

**確認方法**:
```bash
ls -A "/Users/hehex/Library/Containers/com.HoYoverse.hkrpgoversea"
```

**期待**: 何も表示されない  
**もし表示される**: それがマウント保護をトリガーしている

### 原因2: シンボリックリンクやエイリアス

ディレクトリが実際には別の場所へのリンクである可能性。

**確認方法**:
```bash
file "/Users/hehex/Library/Containers/com.HoYoverse.hkrpgoversea"
readlink "/Users/hehex/Library/Containers/com.HoYoverse.hkrpgoversea"
```

### 原因3: 権限の問題

スクリプト実行時（sudo）と手動確認時で見える内容が異なる可能性。

**確認方法**:
```bash
# 通常ユーザーとして
ls -A "/Users/hehex/Library/Containers/com.HoYoverse.hkrpgoversea"

# sudo として
sudo ls -A "/Users/hehex/Library/Containers/com.HoYoverse.hkrpgoversea"
```

### 原因4: タイミングの問題

マウント試行時に一時ファイルが作成される可能性。

**確認方法**:
スクリプト内で `ls -A` の直前と直後にログを追加。

---

## 🛠️ 暫定的な解決策

### 方法1: 手動でディレクトリを削除

```bash
# ディレクトリを削除
sudo rm -rf "/Users/hehex/Library/Containers/com.HoYoverse.hkrpgoversea"

# 再度マウント試行
# スクリプトから「崩壊：スターレイル」をマウント
```

### 方法2: デバッグモードでスクリプト実行

スクリプトを一時的に編集して、`mount_volume()` 関数にデバッグ出力を追加：

**Line 203-206 付近を以下のように変更**:

```bash
# Check if it contains actual data (not just an empty mount point directory)
echo "[DEBUG] Checking content of: $target_path" >&2
local content_check=$(ls -A "$target_path" 2>/dev/null)
echo "[DEBUG] Content: '$content_check'" >&2
echo "[DEBUG] Length: ${#content_check}" >&2

if [[ -n "$content_check" ]]; then
    echo "[DEBUG] BLOCKING: Content detected" >&2
    # Directory has content = internal storage data exists
    print_error "❌ マウントがブロックされました"
    # ... rest of error message ...
else
    echo "[DEBUG] ALLOWING: Directory is empty" >&2
    # Directory is empty = safe to remove and mount
    print_info "空のディレクトリを削除してマウント準備中..."
    sudo rm -rf "$target_path"
fi
```

---

## 📊 結果の共有

以下の情報を共有していただけると、問題を特定できます：

1. **test_mount_protection.sh の出力**
2. **ls vs ls -A の比較結果**
3. **mount コマンドの出力**
4. **手動削除後の動作**

---

## 🎯 次のバージョンでの改善案

### v1.5.4 で実装予定

1. **詳細ログ出力**: マウント保護の判定理由を明確に表示
2. **デバッグモード**: 環境変数 `DEBUG=1` でデバッグ情報を出力
3. **厳密なチェック**: `ls -A` の結果を文字数とファイル数でダブルチェック
4. **ユーザー確認**: 保護ブロック時に「本当にデータがあるか」を表示

### 実装例

```bash
# Before
if [[ -n "$(ls -A "$target_path" 2>/dev/null)" ]]; then
    # Block mounting
fi

# After (v1.5.4)
local content=$(ls -A "$target_path" 2>/dev/null)
local file_count=$(echo "$content" | wc -w | xargs)

if [[ -n "$content" ]] && [[ $file_count -gt 0 ]]; then
    print_error "❌ マウントがブロックされました"
    print_warning "検出された内容:"
    echo "$content" | while read item; do
        echo "    - $item"
    done
    # ... rest of protection logic ...
fi
```

---

**作成日**: 2025-01-XX  
**対象バージョン**: v1.5.3  
**ステータス**: 診断中
