# PlayCover Manager v4.21.1 - Critical Safety Fix

**リリース日**: 2025年10月27日  
**重要度**: 🔴 **CRITICAL** - 即座にアップデート推奨

---

## 🔒 重大なセキュリティ修正

### 問題の発見
v4.21.0の超強力クリーンアップ機能において、**システムボリュームを誤って削除しようとする危険性**が発見されました。

**発見された問題**:
```bash
削除中: Macintosh HD (disk3s3s1)
```

幸い、macOSの保護機構により実際の削除は失敗しましたが、以下のような**致命的なリスク**がありました：
- 🚨 Macintosh HD（システムボリューム）
- 🚨 Data（ユーザーデータボリューム）
- 🚨 Time Machine（バックアップボリューム）
- 🚨 その他の重要なシステムボリューム

---

## 🛡️ 実装された安全対策

### 1. システムボリューム保護チェック

**Step 1（アンマウント）での保護**:
```bash
# ⚠️ SAFETY CHECK: Skip system volumes
if [[ "$vol_name" =~ ^(Macintosh\ HD|Data|Preboot|Recovery|VM|Update|Snapshots|Time\ Machine) ]]; then
    echo "⚠️  スキップ: システムボリューム ${vol_name}"
    continue
fi
```

**Step 5（削除）での保護**:
```bash
# 🔒 CRITICAL SAFETY CHECK: NEVER delete system volumes!
if [[ "$vol_name" =~ ^(Macintosh\ HD|Data|Preboot|Recovery|VM|Update|Snapshots|Time\ Machine) ]]; then
    echo "🛑 スキップ: システムボリューム ${vol_name}（削除不可）"
    continue
fi
```

### 2. 二段階アプローチ

より安全な削除方法を実装：

**方法1（優先）: マッピングファイルベース**
- `playcover-map.txt` に記録されたボリュームのみを削除
- 最も安全で確実な方法
- システムボリュームは決してマッピングに含まれない

**方法2（フォールバック）: パターンマッチング**
- マッピングファイルが無い場合の予備手段
- システムボリュームチェックを必ず実行
- 既に削除済みのボリュームはスキップ

### 3. 改善されたエラーメッセージ

削除失敗時のメッセージを明確化：
```
⚠ 削除失敗（システムボリュームまたはマウント済み）
```

---

## 📊 動作の違い（v4.21.0 vs v4.21.1）

### v4.21.0（危険）
```bash
削除中: PlayCover (disk2s5)
✓ 削除完了

削除中: GenshinImpact (disk2s6)
✓ 削除完了

削除中: Macintosh HD (disk3s3s1)  # 🚨 危険！
⚠ 削除失敗（マウント済み?）     # 運良く失敗
```

### v4.21.1（安全）
```bash
方法1: マッピングファイルから削除対象を特定

削除中: PlayCover (disk2s5)
✓ 削除完了

削除中: 原神 (disk2s6)
✓ 削除完了

🛑 スキップ: システムボリューム Macintosh HD（削除不可）  # ✅ 安全に保護
```

---

## 🎯 保護されるシステムボリューム

以下のボリュームは**絶対に削除されません**：

1. **Macintosh HD** - macOSシステム本体
2. **Data** - ユーザーデータ（APFS Data volume）
3. **Preboot** - 起動前環境
4. **Recovery** - 復旧パーティション
5. **VM** - 仮想メモリスワップ
6. **Update** - システムアップデート用
7. **Snapshots** - Time Machineローカルスナップショット
8. **Time Machine** - Time Machineバックアップ

---

## ⚠️ なぜこの問題が発生したか

### 根本原因

**危険なパターンマッチング**:
```bash
# v4.21.0の問題箇所
local playcover_volumes=$(diskutil list | grep -i "playcover\|genshin\|hkrpg\|nap\|zenless" | awk '{print $NF}')
```

**問題点**:
- `grep -i` は**部分一致**を検索
- `nap` パターンが `Snapshots` にマッチ
- システムボリュームが検出されてしまう

**実際のマッチング例**:
```
PlayCover      → playcover（意図通り）
GenshinImpact  → genshin（意図通り）
Snapshots      → nap（誤検出！）← 🚨 危険
```

---

## 🔍 技術的詳細

### macOSの保護機構

幸い、以下の理由で実際の削除は防がれました：

1. **システムボリュームは削除不可**（SIP保護）
2. **マウント済みボリュームは削除不可**
3. **diskutil apfs deleteVolume が失敗**

しかし、以下のような状況では**削除されてしまう可能性**がありました：
- アンマウント可能なシステムボリューム
- 保護が弱い補助ボリューム
- 外部Time Machineボリューム

### 防御の多層化

v4.21.1では**3層の防御**を実装：

```
第1層: マッピングファイルベース（最も安全）
         ↓
第2層: システムボリューム名チェック（正規表現）
         ↓
第3層: diskutil のエラーハンドリング（最終防衛線）
```

---

## 📋 アップグレード手順

### 1. 即座にアップデート

```bash
# 古いバージョンを削除
rm -f PlayCoverManager.command

# 新しいv4.21.1をダウンロード
# （GitHubまたは配布元から）

# 実行権限を付与
chmod +x PlayCoverManager.command
```

### 2. 既存の機能は変更なし

- 超強力クリーンアップは引き続き使用可能
- より安全になっただけで、削除対象は同じ
- 使用方法も完全に同じ

---

## 🙏 謝辞

この重大な問題を発見してくださったユーザー様に感謝します。

> 「いや、何が怖いって削除中: Macintosh HD (disk3s3s1)まあ失敗してるけども勢い余って同ドライブのDATAボリュームとかTimeMachineボリュームとか消されなくてよかった」

このフィードバックにより、多くのユーザーのデータが守られました 🙏

---

## 📚 関連ドキュメント

- `NUCLEAR_CLEANUP_GUIDE.md` - 超強力クリーンアップ機能の使用ガイド
- `README.md` - プロジェクト全体のドキュメント
- `CHANGELOG_v4.21.0.md` - v4.21.0のリリースノート

---

**最終更新:** 2025年10月27日
