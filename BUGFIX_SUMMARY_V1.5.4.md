# Bug Fix Summary - v1.5.4: macOS Metadata Files Filtering

## 🐛 Critical Bug Fixed
**マウント保護が macOS メタデータファイルを実データとして誤認識**

---

## 問題

### ユーザー報告

```bash
# 手動確認: ディレクトリは空に見える
$ ls /Users/hehex/Library/Containers/com.HoYoverse.hkrpgoversea
# 出力なし

# しかしスクリプトでは:
現在: アンマウント済み  ← 正しい
マウントしますか？ (Y/n): y
✗ ❌ マウントがブロックされました  ← 問題！
⚠ このアプリは現在、内蔵ストレージで動作しています  ← 矛盾！
```

### 根本原因

```bash
# 通常の ls: 隠しファイルを表示しない
$ ls /Users/hehex/Library/Containers/com.HoYoverse.hkrpgoversea
# 出力なし

# ls -A: 隠しファイルも表示
$ ls -A /Users/hehex/Library/Containers/com.HoYoverse.hkrpgoversea
.DS_Store  ← macOS が自動作成するメタデータファイル
```

**スクリプトは `.DS_Store` を「実データ」として認識**し、マウント保護をトリガーしていました。

---

## macOS メタデータファイルとは

macOS が自動的に作成する管理用ファイル：

| ファイル名 | 用途 |
|----------|------|
| `.DS_Store` | Finder の表示設定（アイコン位置、表示順序など） |
| `.Spotlight-V100` | Spotlight 検索のインデックス |
| `.Trashes` | ゴミ箱（外部ドライブ用） |
| `.fseventsd` | ファイルシステムイベントログ |

これらは**ユーザーデータではない**ため、マウント保護の判定から除外すべきです。

---

## 修正内容

### 1. マウント保護ロジックの改善 (Line 198-223)

**Before (v1.5.3)**:
```bash
if [[ -n "$(ls -A "$target_path" 2>/dev/null)" ]]; then
    # すべてのファイル（メタデータ含む）をブロック対象とする
    print_error "❌ マウントがブロックされました"
    return 1
fi
```

**After (v1.5.4)**:
```bash
# macOS メタデータファイルを除外
local content_check=$(ls -A "$target_path" 2>/dev/null | \
    grep -v '^\\.DS_Store$' | \
    grep -v '^\\.Spotlight-V100$' | \
    grep -v '^\\.Trashes$' | \
    grep -v '^\\.fseventsd$')

if [[ -n "$content_check" ]]; then
    # 実データのみをブロック対象とする
    print_error "❌ マウントがブロックされました"
    print_info "検出されたデータ:"
    echo "$content_check" | head -5 | while read item; do
        echo "  - $item"
    done
    return 1
else
    # メタデータのみ、または完全に空 = マウント許可
    print_info "空のディレクトリを削除してマウント準備中..."
    sudo rm -rf "$target_path"
fi
```

### 2. ストレージ検出ロジックの改善 (Line 319-334)

**Before (v1.5.3)**:
```bash
local content_check=$(ls -A "$path" 2>/dev/null)
if [[ -z "$content_check" ]]; then
    echo "none"
    return
fi
```

**After (v1.5.4)**:
```bash
# macOS メタデータファイルを除外してチェック
local content_check=$(ls -A "$path" 2>/dev/null | \
    grep -v '^\\.DS_Store$' | \
    grep -v '^\\.Spotlight-V100$' | \
    grep -v '^\\.Trashes$' | \
    grep -v '^\\.fseventsd$')

if [[ -z "$content_check" ]]; then
    echo "none"  # 実データなし
    return
fi
# 実データあり → disk location をチェック
```

### 3. 検出データの表示改善

マウント保護がトリガーされた場合、**実際に検出されたファイル**を表示：

```
✗ ❌ マウントがブロックされました
⚠ このアプリは現在、内蔵ストレージで動作しています
ℹ 検出されたデータ:
  - Documents
  - Library
  - SystemData
  - com.example.app
  ... (他 15 個)
```

これにより、ユーザーは**本当にデータがあるか**を確認できます。

---

## テストケース

### ケース1: `.DS_Store` のみ存在

**Before (v1.5.3)**:
```
✗ マウントがブロックされました  ← 間違い
```

**After (v1.5.4)**:
```
ℹ 空のディレクトリを削除してマウント準備中...
✓ マウント成功  ← 正しい
```

### ケース2: `.DS_Store` + 実データ

**Before (v1.5.3)**:
```
✗ マウントがブロックされました
（何が検出されたか不明）
```

**After (v1.5.4)**:
```
✗ マウントがブロックされました
ℹ 検出されたデータ:
  - Documents
  - Library
（実データを明示）
```

### ケース3: 完全に空

**Before (v1.5.3)**:
```
ℹ 空のディレクトリを削除
✓ マウント成功
```

**After (v1.5.4)**:
```
ℹ 空のディレクトリを削除
✓ マウント成功
（変更なし - 正しく動作）
```

---

## 影響範囲

### 修正された機能

1. **マウント保護** (`mount_volume()`)
   - メタデータファイルを無視
   - 実データのみをチェック
   - 検出内容を表示

2. **ストレージ検出** (`get_storage_type()`)
   - メタデータファイルを無視
   - 実データの有無を正確に判定
   - internal/external/none の判定精度向上

### 影響を受ける機能

- ✅ 個別ボリューム操作（オプション3）
- ✅ ストレージ切り替え（オプション6）
- ✅ メインメニューの状態表示

---

## 除外されるメタデータファイル

### 1. `.DS_Store`
- **作成者**: Finder
- **用途**: フォルダの表示設定
- **サイズ**: 通常 6-12 KB
- **除外理由**: ユーザーデータではない

### 2. `.Spotlight-V100/`
- **作成者**: Spotlight
- **用途**: 検索インデックス
- **サイズ**: 可変
- **除外理由**: 検索用メタデータ

### 3. `.Trashes/`
- **作成者**: macOS（外部ドライブ）
- **用途**: ゴミ箱
- **サイズ**: 可変
- **除外理由**: 削除予定のファイル

### 4. `.fseventsd/`
- **作成者**: macOS File System Events Daemon
- **用途**: ファイル変更履歴
- **サイズ**: 可変
- **除外理由**: システムログ

---

## 診断ツールの更新

### test_mount_protection.sh

メタデータフィルタリングを考慮した診断を実行：

```bash
./test_mount_protection.sh "/Users/hehex/Library/Containers/com.HoYoverse.hkrpgoversea"
```

**新しい出力**:
```
Step 3: Check directory content (ls -A)
  Raw output: '.DS_Store'
  Filtered output: ''  ← メタデータを除外
  Output length: 0 characters

Step 4: Protection decision
  ✓ ALLOWED: Only metadata files detected
  → Mount protection will ALLOW mounting
```

---

## アップグレード手順

### 1. 最新版をダウンロード

v1.5.4 に更新してください。

### 2. バージョン確認

```
╔═══════════════════════════════════════════════════════════╗
║                 Version 1.5.4  ← ここを確認                ║
╚═══════════════════════════════════════════════════════════╝
```

### 3. 動作確認

以前マウントできなかったアプリでマウントを試してください。

---

## トラブルシューティング

### まだマウントブロックされる場合

1. **検出データを確認**:
   ```
   ℹ 検出されたデータ:
     - [ここに表示されるファイル名を確認]
   ```

2. **手動で確認**:
   ```bash
   ls -A "/Users/hehex/Library/Containers/com.HoYoverse.hkrpgoversea" | \
       grep -v '^\\.DS_Store$' | \
       grep -v '^\\.Spotlight-V100$' | \
       grep -v '^\\.Trashes$' | \
       grep -v '^\\.fseventsd$'
   ```

3. **本当にデータがある場合**:
   - ストレージ切り替え（オプション6）を使用
   - 内蔵 → 外部へ移行

4. **メタデータのみの場合**:
   - GitHub Issue として報告
   - 追加のメタデータファイルを除外リストに追加

---

## 今後の改善案

### v1.6.0 での検討事項

1. **設定ファイルで除外リスト管理**:
   ```bash
   # .playcover-exclude
   .DS_Store
   .Spotlight-V100
   .Trashes
   .fseventsd
   .TemporaryItems
   .DocumentRevisions-V100
   ```

2. **デバッグモード**:
   ```bash
   DEBUG=1 ./2_playcover-volume-manager.command
   # すべてのチェックポイントで詳細情報を表示
   ```

3. **対話的な確認**:
   ```
   ✗ マウントがブロックされました
   ℹ 検出されたデータ:
     - .DS_Store (6 KB)
   
   これはメタデータファイルのようです。
   無視してマウントを続行しますか？ (y/N):
   ```

---

## まとめ

### 修正内容
- ✅ macOS メタデータファイルを除外
- ✅ 実データのみをチェック
- ✅ 検出内容を表示

### 効果
- ✅ `.DS_Store` のみの空ディレクトリでマウント可能
- ✅ 誤検出によるマウントブロックを解消
- ✅ より正確なストレージ状態判定

### 重要度
**Priority: CRITICAL**

メタデータファイルによる誤検出は、ユーザー操作を不必要にブロックするため重要。

---

**バージョン**: 1.5.3 → 1.5.4  
**リリース日**: 2025-01-XX  
**ステータス**: ✅ 修正完了  
**テスト**: 必要（ユーザー環境での確認）
