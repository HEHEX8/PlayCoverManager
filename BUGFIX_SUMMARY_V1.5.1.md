# Bug Fix Summary - v1.5.1: Storage Switching Data Copy

## 🚨 Critical Bug Fixed
**ストレージ切り替え時にデータがコピーされない問題を修正**

---

## 問題

### 症状
```
外部 → 内蔵への切り替え実行

結果:
- 外部ボリューム: 1GB のデータ
- 内蔵ストレージ: 0 bytes (空) ← データ損失！
```

### エラーログ
```
ℹ 既存データをバックアップ中...
mv: cannot rename a mount point  ← エラー

ℹ データをコピー中...
sent 42305 bytes  received 20 bytes
total size is 933009045  speedup is 22043.92  ← 転送されていない
✓ データのコピーが完了しました  ← 実際は失敗
```

---

## 原因

### 1. マウントポイントの移動
```bash
# マウントされているディレクトリを移動しようとした
sudo mv "$target_path" "$backup_path"
→ mv: cannot rename a mount point
```

### 2. rsync が同じ場所にコピー
```bash
# $current_mount と $target_path が同じパス
rsync "$target_path/" "$target_path/"
→ 何も転送されない（speedup が異常に高い）
```

### 3. 検証なし
- データが正しくコピーされたか確認していない
- 0 bytes でも「成功」と表示

---

## 修正内容

### 1. マウントポイント検出とアンマウント
```bash
# マウント状態をチェック
if マウントポイント?; then
    print_info "既存のマウントポイントをアンマウント中..."
    sudo umount "$target_path"
    sleep 1  # 待機
fi

# その後バックアップ（通常のディレクトリとして）
sudo mv "$target_path" "$backup_path"
```

### 2. デバッグ情報の追加
```bash
# コピー前
print_info "コピー元: ${current_mount}"
print_info "  ファイル数: 444"
print_info "  データサイズ: 933M"

# コピー実行
rsync -avH --progress ...

# コピー後（検証）
print_info "  コピー完了: 444 ファイル (933M)"
```

### 3. rsync の改善
```bash
# Before: 進捗が見えない
rsync -av --progress ... | grep -v "..." | tail -20

# After: 詳細な進捗表示（macOS 標準 rsync 互換）
rsync -avH --progress ...
```

**注意**: ドキュメント初版では `--info=progress2` と記載していましたが、これは macOS 標準の rsync 2.6.9 では使えません。実際のコードでは最初から `--progress` を使用しており、互換性の問題はありません。

---

## 修正結果

### Before (v1.5.0)
```
エラーログ:
- mv: cannot rename a mount point
- speedup is 22043.92

結果:
- 内蔵ストレージ: 0 bytes (空) ❌
```

### After (v1.5.1)
```
正常なログ:
ℹ コピー元: /Users/.../com.example.app
ℹ   ファイル数: 444
ℹ   データサイズ: 933M
ℹ 既存のマウントポイントをアンマウント中...
ℹ データをコピー中...

   933,009,045 100%  156.50MB/s    0:00:05

✓ データのコピーが完了しました
ℹ   コピー完了: 444 ファイル (933M)

結果:
- 内蔵ストレージ: 933M のデータ ✓
```

---

## テスト確認

### ✓ 外部 → 内蔵（マウント中）
```
v1.5.0: データ損失 ❌
v1.5.1: 正常にコピー ✓
```

### ✓ 外部 → 内蔵（アンマウント済み）
```
v1.5.0: 進捗不明 △
v1.5.1: 正常にコピー ✓
```

### ✓ 内蔵 → 外部
```
v1.5.0: 動作するが進捗不明 △
v1.5.1: データサイズ表示 ✓
```

---

## 変更点

### ファイル
- `2_playcover-volume-manager.command`
  - `switch_storage_location()` 関数を修正
  - バージョン: 1.5.0 → 1.5.1

### 主な改善
1. ✅ マウントポイント検出とアンマウント
2. ✅ デバッグ情報追加（ファイル数、サイズ）
3. ✅ rsync 進捗表示改善
4. ✅ コピー後のデータ検証

---

## 重要度

**Priority: CRITICAL**

- データ損失の危険性を修正
- すべてのユーザーは v1.5.1 にアップグレードすべき

---

## アップグレード

1. スクリプトファイルを更新
2. 再実行するだけ
3. データへの影響なし

### v1.5.0 で被害を受けた場合
1. バックアップディレクトリを確認
   - `.com.example.app.backup`
2. 外部ボリュームに元データが残っている可能性
3. 必要に応じて手動復元

---

## まとめ

✅ マウントポイントの移動エラー修正  
✅ データコピーの失敗を修正  
✅ デバッグ情報で透明性向上  
✅ データ検証で安心感向上  

**データの安全性が大幅に向上しました！**
