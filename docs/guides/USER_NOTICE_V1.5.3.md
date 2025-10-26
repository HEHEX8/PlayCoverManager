# v1.5.3 リリースノート - ストレージ検出表示の修正

## 🎯 修正された問題

### ご報告いただいた問題

```bash
$ ls /Users/hehex/Library/Containers/com.HoYoverse.hkrpgoversea
com.HoYoverse.hkrpgoversea  ← データが存在

# しかしスクリプトでは：
  1. ⚪ 崩壊：スターレイル
      (アンマウント済み)  ← 間違った認識！
```

**期待される動作**:
```
  1. 💾 崩壊：スターレイル
      (内蔵ストレージ)  ← 正しい認識
```

---

## ✅ v1.5.3 での修正

### 1. カウント表示の修正

**Before (v1.5.2)**:
```
━━━━━━━━━━━━ 現在の状態 ━━━━━━━━━━━━

  🔌 マウント中: 0/1
  ⚪ アンマウント: 1/1  ← 内蔵データも「アンマウント」扱い

  【ボリューム一覧】
    ⚪ 崩壊：スターレイル
```

**After (v1.5.3)**:
```
━━━━━━━━━━━━ 現在の状態 ━━━━━━━━━━━━

  ✓ データあり: 1/1  (🔌外部 / 💾内蔵)
  ⚪ データなし: 0/1

  【ボリューム一覧】
    💾 崩壊：スターレイル  ← 正しく認識！
```

### 2. わかりやすい表示

- **旧**: 「マウント中 / アンマウント」
  - 誤解を招く（内蔵も「アンマウント」扱い）
  
- **新**: 「データあり / データなし」
  - より明確（内蔵・外部どちらもデータあり）

---

## 🔍 デバッグツールの提供

問題が継続する場合の診断ツールを用意しました：

### 使用方法

```bash
cd /path/to/script
./debug_storage_detection.sh "/Users/hehex/Library/Containers/com.HoYoverse.hkrpgoversea"
```

### 出力例

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

このツールで、スクリプトがどのようにストレージを検出しているか確認できます。

---

## 🚀 アップグレード方法

### 1. 最新版をダウンロード

最新の `2_playcover-volume-manager.command` (v1.5.3) に置き換えてください。

### 2. バージョン確認

スクリプト起動時のメニューで確認：

```
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║            PlayCover ボリューム管理                        ║
║                                                           ║
║              macOS Tahoe 26.0.1 対応版                     ║
║                 Version 1.5.3  ← ここを確認                ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
```

### 3. 動作確認

メインメニューで正しく表示されるか確認：

- ✅ 内蔵データは「💾」アイコン
- ✅ 外部データは「🔌」アイコン
- ✅ データなしは「⚪」アイコン

---

## 💡 補足情報

### マウントブロック機能は正常動作

ご報告いただいた通り、マウントブロック機能は正しく動作しています：

```
❌ マウントがブロックされました
このアプリは現在、内蔵ストレージで動作しています
```

今回の修正は**表示のみ**の問題で、保護機能自体は正常に機能していました。

### ストレージ切り替え機能も動作

内蔵→外部、外部→内蔵の切り替えも正常に動作します。
表示が修正されたことで、現在の状態がより明確になりました。

---

## 📞 問題が継続する場合

もし v1.5.3 でもまだ「アンマウント済み」と表示される場合：

### Step 1: デバッグスクリプト実行

```bash
./debug_storage_detection.sh "/Users/hehex/Library/Containers/com.HoYoverse.hkrpgoversea"
```

出力を保存して共有してください。

### Step 2: 手動確認

```bash
# ディレクトリの内容確認
ls -la "/Users/hehex/Library/Containers/com.HoYoverse.hkrpgoversea"

# マウント状態確認
mount | grep "com.HoYoverse.hkrpgoversea"

# ディスク情報確認
df "/Users/hehex/Library/Containers/com.HoYoverse.hkrpgoversea"
diskutil info $(df "/Users/hehex/Library/Containers/com.HoYoverse.hkrpgoversea" | tail -1 | awk '{print $1}' | sed 's|/dev/\(disk[0-9]*\).*|/dev/\1|')
```

これらの出力を共有していただければ、さらに詳しく調査できます。

---

## ✅ まとめ

### 修正内容
1. ✅ 内蔵ストレージを「データあり」としてカウント
2. ✅ 表示ラベルを「データあり / データなし」に改善
3. ✅ デバッグツール追加

### 確認済み動作
- ✅ マウントブロック機能は正常
- ✅ ストレージ切り替え機能は正常
- ✅ 今回は表示の問題のみ

### お願い
v1.5.3 にアップデート後、正しく表示されるかご確認ください。
問題が継続する場合は、デバッグスクリプトの結果を共有していただけると助かります。

---

**リリース日**: 2025-01-XX  
**バージョン**: 1.5.3  
**優先度**: High（表示の正確性）
