# Bug Fix Summary - v1.5.2: rsync Compatibility Fix

## 🔧 Documentation and Compatibility Fix
**macOS 標準 rsync との互換性問題を修正**

---

## 問題

### 症状
ユーザーの環境で以下のエラーが発生：
```
rsync: unrecognized option `--info=progress2'
rsync error: syntax or usage error (code 1) at main.c(1333) [client=2.6.9]
```

### 原因
1. **ドキュメントの誤記**: `BUGFIX_SUMMARY_V1.5.1.md` に `--info=progress2` と記載
2. **互換性の問題**: `--info=progress2` は rsync 3.1.0+ の機能
3. **macOS 標準**: macOS は rsync 2.6.9 を標準搭載
4. **実装は正しい**: コードは既に `--progress` を使用（互換性あり）

---

## 修正内容

### 実際のコード（v1.5.1時点で既に正しい）

**Internal → External (line 1110):**
```bash
# ✅ CORRECT: macOS rsync 2.6.9 compatible
if sudo /usr/bin/rsync -avH --progress "$target_path/" "$temp_mount/" 2>&1; then
```

**External → Internal (line 1239):**
```bash
# ✅ CORRECT: macOS rsync 2.6.9 compatible
if sudo /usr/bin/rsync -avH --progress "$current_mount/" "$target_path/" 2>&1; then
```

### rsync オプションの説明

| オプション | 説明 | 互換性 |
|----------|------|--------|
| `-a` | アーカイブモード（再帰的、パーミッション保持など） | ✅ rsync 2.6.9+ |
| `-v` | 詳細表示 | ✅ rsync 2.6.9+ |
| `-H` | ハードリンク保持 | ✅ rsync 2.6.9+ |
| `--progress` | ファイルごとの進捗表示 | ✅ rsync 2.6.9+ |
| `--info=progress2` | 全体進捗表示（より詳細） | ❌ rsync 3.1.0+ のみ |

---

## ドキュメント修正

### BUGFIX_SUMMARY_V1.5.1.md の誤記を修正

**Before (誤記):**
```bash
# After: 詳細な進捗表示
rsync -aH --info=progress2 ...
```

**After (正しい):**
```bash
# After: 詳細な進捗表示
rsync -avH --progress ...
```

---

## ユーザーへの対応

### エラーが発生した場合の確認事項

1. **スクリプトのバージョン確認**:
   ```bash
   grep -n "rsync.*--" 2_playcover-volume-manager.command
   ```
   
   期待される出力:
   ```
   1110:   if sudo /usr/bin/rsync -avH --progress ...
   1239:   if sudo /usr/bin/rsync -avH --progress ...
   ```

2. **古いバージョンを使用している場合**:
   - 最新のスクリプトをダウンロード
   - または手動で `--info=progress2` を `--progress` に置換

3. **Homebrew rsync を使用している場合**:
   ```bash
   # Homebrew の rsync（新しいバージョン）
   brew install rsync
   
   # パスを明示的に指定
   /opt/homebrew/bin/rsync -avH --info=progress2 ...
   ```

---

## フェイルセーフの動作確認

ユーザーからの報告:
> "フェイルセーフはちゃんと機能しているみたいでよろしい"

### 正常に動作したフェイルセーフ機能

1. **エラー検出**: rsync のエラーを正しく検出
2. **エラー表示**: 「✗ データのコピーに失敗しました」
3. **バックアップ復元**: 「ℹ バックアップを復元中...」
4. **データ保護**: 元のデータは失われていない
5. **安全な終了**: メニューに正常復帰

```
✗ データのコピーに失敗しました
ℹ バックアップを復元中...
✓ バックアップを復元しました
```

---

## 進捗表示の違い

### `--progress` (macOS 標準 rsync)
```
Documents/file1.txt
     102,400 100%   10.42MB/s    0:00:00
Documents/file2.txt
   5,242,880 100%   52.43MB/s    0:00:00
...
```
- ファイルごとに進捗表示
- 多数のファイルで出力が長くなる
- しかし確実に動作する ✅

### `--info=progress2` (Homebrew rsync 3.1.0+)
```
   933,009,045 100%  156.50MB/s    0:00:05
```
- 全体の進捗を1行で表示
- よりクリーンな出力
- macOS 標準では使えない ❌

---

## テスト確認

### ✓ macOS 標準 rsync (2.6.9) での動作
```bash
# 確認
rsync --version
# rsync version 2.6.9 protocol version 29

# テスト
/usr/bin/rsync -avH --progress test1/ test2/
# ✅ 正常動作
```

### ✓ Homebrew rsync (3.x) での動作
```bash
# 確認
/opt/homebrew/bin/rsync --version
# rsync version 3.2.7 protocol version 31

# テスト
/opt/homebrew/bin/rsync -avH --info=progress2 test1/ test2/
# ✅ 正常動作（より詳細な進捗）
```

---

## 変更点

### ドキュメント
- `BUGFIX_SUMMARY_V1.5.1.md` の誤記を修正
- `BUGFIX_SUMMARY_V1.5.2.md` を新規作成（このファイル）

### コード
- **変更なし** - v1.5.1 時点で既に正しい実装

### バージョン
- ドキュメント修正のみ: 1.5.1 → 1.5.2

---

## 重要度

**Priority: DOCUMENTATION**

- コードは既に正しい ✅
- ドキュメントの誤記を修正 📝
- ユーザーの混乱を解消 💡

---

## まとめ

✅ コードは v1.5.1 時点で既に正しい  
✅ macOS 標準 rsync と互換性あり  
✅ フェイルセーフが正常に機能  
✅ ドキュメントの誤記を修正  

**ユーザーがエラーを経験した場合、古いバージョンのスクリプトを使用している可能性があります。最新版では問題は発生しません。**

---

## ユーザーへのメッセージ

もし `rsync: unrecognized option '--info=progress2'` エラーが表示される場合:

1. **スクリプトを確認**: 
   ```bash
   grep "rsync.*--info=progress2" 2_playcover-volume-manager.command
   ```
   
2. **該当行がある場合**: 古いバージョンです。最新版をダウンロードしてください。

3. **該当行がない場合**: 既に最新版です。フェイルセーフが正常に動作しており、データは保護されています。

**フェイルセーフの動作は設計通りです。エラーが発生してもデータは失われません。** 👍
