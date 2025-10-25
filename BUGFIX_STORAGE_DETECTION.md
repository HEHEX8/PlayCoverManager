# バグ修正 - ストレージタイプ検出の改善

## 🐛 発見されたバグ

### 症状

ZZZ（ゼンレスゾーンゼロ）を外部→内蔵に切り替えた後、アンマウントされているにもかかわらず、まだ「🔌 外部ストレージ」として表示される。

### 原因

`get_storage_type()` 関数の判定ロジックが不正確でした：

**問題点:**
1. `Solid State: Yes` だけでは内蔵/外部を判定できない
   - 外付けSSDも `Solid State: Yes` になる
2. APFSボリュームとしてマウントされているかを確認していない
   - 内蔵にコピー後もボリュームがマウントされていれば外部と判定すべき

---

## ✅ 修正内容

### 新しい判定ロジック（優先順位順）

#### 1. マウント状態の確認（最優先）

```bash
# パスがAPFSボリュームとしてマウントされているか確認
local mount_check=$(/sbin/mount | /usr/bin/grep " on ${path} ")
if [[ -n "$mount_check" ]] && [[ "$mount_check" =~ "apfs" ]]; then
    echo "external"  # マウントされたAPFSボリューム = 外部ストレージ
    return
fi
```

**理由:**
- `~/Library/Containers/{bundle_id}` が独立したAPFSボリュームとしてマウントされている場合、それは外部ストレージのボリューム
- 内蔵ストレージにコピーした場合、通常のディレクトリになるのでマウントポイントではない

#### 2. Device Location の確認

```bash
local disk_location=$(diskutil info "/dev/$disk_id" 2>/dev/null | \
    /usr/bin/grep "Device Location:" | \
    /usr/bin/awk -F: '{print $2}' | \
    /usr/bin/sed 's/^ *//')

if [[ "$disk_location" == "Internal" ]]; then
    echo "internal"
elif [[ "$disk_location" == "External" ]]; then
    echo "external"
```

**理由:**
- `Device Location` フィールドが最も信頼できる情報源
- "Internal" または "External" を明示的に示す

#### 3. フォールバック判定

```bash
# disk0 または disk1 は通常内蔵ディスク
if [[ "$disk_id" == "disk0" ]] || [[ "$disk_id" == "disk1" ]]; then
    echo "internal"
else
    echo "external"
fi
```

**理由:**
- macOSでは通常、disk0が内蔵ディスク
- disk1はFusion Driveの場合などに使用される
- disk2以降は外部ディスクの可能性が高い

---

## 📊 判定例

### ケース1: 外部APFSボリュームにマウント

```bash
パス: ~/Library/Containers/com.HoYoverse.Nap
マウント状態: /dev/disk5s1 on ~/Library/Containers/com.HoYoverse.Nap (apfs)

判定結果: external ✅
理由: APFSボリュームとしてマウントされている
```

### ケース2: 内蔵ディスクの通常ディレクトリ

```bash
パス: ~/Library/Containers/com.HoYoverse.Nap
マウント状態: マウントポイントではない（通常のディレクトリ）
デバイス: /dev/disk1s5 (システムディスク)

判定結果: internal ✅
理由: マウントポイントではなく、disk1（内蔵）上にある
```

### ケース3: 外部ディスクの通常ディレクトリ（稀）

```bash
パス: /Volumes/ExternalDrive/SomeApp
デバイス: /dev/disk5
Device Location: External

判定結果: external ✅
理由: Device Location が External
```

---

## 🔍 修正前後の比較

### 修正前のロジック

```bash
# 問題: Solid State だけで判定していた
local is_internal=$(diskutil info "/dev/$disk_id" | grep "Solid State:" | grep -i "yes")
local disk_type=$(diskutil info "/dev/$disk_id" | grep "Device Location:" | grep -i "internal")

if [[ -n "$is_internal" ]] || [[ -n "$disk_type" ]]; then
    echo "internal"
else
    echo "external"
fi
```

**問題点:**
- 外付けSSDも `Solid State: Yes` になる
- マウント状態を考慮していない
- 判定が曖昧

### 修正後のロジック

```bash
# 1. まずマウント状態を確認（最優先）
local mount_check=$(/sbin/mount | /usr/bin/grep " on ${path} ")
if [[ -n "$mount_check" ]] && [[ "$mount_check" =~ "apfs" ]]; then
    echo "external"
    return
fi

# 2. Device Location を確認
local disk_location=$(diskutil info "/dev/$disk_id" | grep "Device Location:" | ...)

if [[ "$disk_location" == "Internal" ]]; then
    echo "internal"
elif [[ "$disk_location" == "External" ]]; then
    echo "external"
else
    # 3. フォールバック: disk ID で判定
    if [[ "$disk_id" == "disk0" ]] || [[ "$disk_id" == "disk1" ]]; then
        echo "internal"
    else
        echo "external"
    fi
fi
```

**改善点:**
- ✅ マウント状態を優先的に確認
- ✅ Device Location で明確に判定
- ✅ フォールバック判定を追加
- ✅ より正確な判定

---

## 🧪 テストケース

### テスト1: 外部ボリュームマウント状態

```bash
# 状態
/dev/disk5s1 on ~/Library/Containers/com.HoYoverse.Nap (apfs, local, nodev, nosuid, journaled, noowners, nobrowse)

# 期待される結果
🔌 外部ストレージ
```

### テスト2: 内蔵に切り替え後（ボリュームアンマウント）

```bash
# 状態
~/Library/Containers/com.HoYoverse.Nap は通常のディレクトリ
/dev/disk1s5 on / (apfs, sealed, local, read-only, journaled)

# 期待される結果
💾 内蔵ストレージ
```

### テスト3: 内蔵→外部に切り替え後

```bash
# 状態
/dev/disk5s2 on ~/Library/Containers/com.HoYoverse.Nap (apfs, local, nodev, nosuid, journaled, noowners, nobrowse)

# 期待される結果
🔌 外部ストレージ
```

---

## 💡 なぜこの方法が正確なのか？

### マウント状態が最優先である理由

1. **明確な区別**
   - マウントポイント = 独立したボリューム = 外部管理
   - 通常のディレクトリ = システムディスクの一部 = 内蔵

2. **PlayCoverの使用方法に合致**
   - 外部ストレージ: APFSボリュームをマウント
   - 内蔵ストレージ: 通常のディレクトリ

3. **切り替え後の状態を正確に反映**
   - 外部→内蔵: ボリュームアンマウント → ディレクトリになる → 内蔵と判定
   - 内蔵→外部: ディレクトリ削除 → ボリュームマウント → 外部と判定

---

## 🔧 デバッグ方法

### 現在の状態を確認

```bash
# マウント状態を確認
mount | grep Containers

# 出力例（外部ストレージ）:
/dev/disk5s1 on /Users/xxx/Library/Containers/com.HoYoverse.Nap (apfs, ...)

# 出力例（内蔵ストレージ）:
# （何も表示されない = マウントポイントではない）
```

### ディスク情報を確認

```bash
# デバイスを確認
df ~/Library/Containers/com.HoYoverse.Nap

# ディスク情報を確認
diskutil info /dev/disk5
```

### 手動でストレージタイプを判定

```bash
# スクリプトの関数を手動実行
path="$HOME/Library/Containers/com.HoYoverse.Nap"
mount | grep " on ${path} "

# 出力あり → 外部
# 出力なし → 内蔵の可能性
```

---

## ✅ 修正完了

### 変更されたファイル

```
/home/user/webapp/2_playcover-volume-manager.command
```

### 修正された関数

```bash
get_storage_type()  # 行 264-306
```

### 変更内容

- ✅ マウント状態の確認を最優先に追加
- ✅ Device Location の解析を改善
- ✅ フォールバック判定を追加
- ✅ より正確で信頼性の高い判定ロジック

---

## 🚀 次のステップ

1. **スクリプトの再起動**
   ```bash
   ./2_playcover-volume-manager.command
   ```

2. **ストレージ状態の確認**
   - オプション 6 を選択
   - アプリ一覧でストレージアイコンを確認
   - 内蔵に切り替え済みなら💾が表示されるはず

3. **必要に応じて再切り替え**
   - まだ🔌が表示される場合、実際にはまだ外部にある可能性
   - その場合は再度切り替えを実行

---

**修正完了！再テストをお願いします！** 🎉

---

**修正日**: 2025-01-XX  
**バージョン**: v1.3.2  
**修正者**: AI Assistant  
**ステータス**: ✅ 修正完了・検証待ち
