# PlayCover Complete Manager v4.3.2 変更ログ

## リリース日: 2025-10-25

## 🎯 主要な改善: PlayCover保護 + 完全クリーンアップ + ロック修正

### 背景
v4.3.1のリリース後、ユーザーからのフィードバックにより以下の問題が発見されました：
1. **PlayCoverボリュームの削除問題** - 他のアプリが残っているのに削除できてしまう
2. **メニュー名の不整合** - 「IPAをインストール」vs「アプリをアンインストール」
3. **Containersフォルダの残骸** - アンインストール後もContainersが残る
4. **ロック取得失敗** - マッピングファイルロックが古い状態で残る

### 実装した改善

#### 1. PlayCoverボリューム保護機能

**問題点:**
```
現状: PlayCoverボリュームを削除
→ 他のアプリがまだある状態でも削除可能
→ 他のアプリが使えなくなる
```

**解決策:**
```bash
# 削除前のチェック
if [[ "$selected_volume" == "PlayCover" ]] && [[ $total_apps -gt 1 ]]; then
    # PlayCoverボリュームは最後まで削除不可
    echo "理由: 他のアプリがまだインストールされています"
    echo "PlayCoverボリュームを削除するには："
    echo "  1. 他のすべてのアプリを先にアンインストール"
    echo "  2. PlayCoverボリュームが最後に残った状態にする"
    echo "  3. その後、PlayCoverボリュームをアンインストール"
fi
```

**フロー:**
```
インストール済みアプリ: 3個
├─ 原神
├─ 崩壊：スターレイル
└─ PlayCover

1. PlayCover選択 → ❌ エラー（他のアプリが残っている）
2. 原神削除 → ✓ 成功
3. 崩壊削除 → ✓ 成功
4. PlayCover選択 → ✓ 削除可能（最後の1個）
```

#### 2. メニュー名の統一

**変更前 (v4.3.1):**
```
【アプリ管理】
  1. IPAをインストール         ← IPA という単語
  2. アプリをアンインストール   ← アプリ という単語
```

**変更後 (v4.3.2):**
```
【アプリ管理】
  1. アプリをインストール       ← 統一
  2. アプリをアンインストール   ← 統一
```

**理由:**
- より自然な日本語表現
- ユーザーはIPAファイルを意識する必要がない
- インストール/アンインストールで対称性がある

#### 3. Containersフォルダの完全削除

**PlayCoverの構造:**
```bash
~/Library/Containers/
├── io.playcover.PlayCover/         # PlayCover本体
│   ├── Applications/
│   ├── App Settings/
│   ├── Entitlements/
│   └── Keymapping/
│
└── [各アプリのBundle ID]/          # アプリごとのContainer
    └── Data/                       # アプリのデータ
        ├── Documents/
        ├── Library/
        └── tmp/
```

**v4.3.1の削除範囲:**
```
✓ io.playcover.PlayCover/Applications/[Bundle ID].app
✓ io.playcover.PlayCover/App Settings/[Bundle ID].plist
✓ io.playcover.PlayCover/Entitlements/[Bundle ID].plist
✓ io.playcover.PlayCover/Keymapping/[Bundle ID].plist
✗ [Bundle ID]/  ← 削除されずに残る！
```

**v4.3.2の削除範囲:**
```
✓ io.playcover.PlayCover/Applications/[Bundle ID].app
✓ io.playcover.PlayCover/App Settings/[Bundle ID].plist
✓ io.playcover.PlayCover/Entitlements/[Bundle ID].plist
✓ io.playcover.PlayCover/Keymapping/[Bundle ID].plist
✓ [Bundle ID]/  ← 完全削除！（NEW）
```

**実装:**
```bash
# Step 5: Remove Containers folder for the app
local containers_dir="${HOME}/Library/Containers/${selected_bundle}"
if [[ -d "$containers_dir" ]]; then
    print_info "Containersフォルダを削除中..."
    rm -rf "$containers_dir"
    print_success "Containersフォルダを削除しました"
fi
```

#### 4. ロック取得失敗の修正

**問題点:**
```
# 古いロックが残っている場合
playcover-map.txt.lock/  ← ディレクトリが残る
↓
mkdir "$LOCK_DIR"  ← 失敗
↓
10回リトライ → すべて失敗
↓
「マッピングファイルのロック取得に失敗しました」
```

**解決策:**
```bash
# リトライ上限に達した場合、古いロックをクリーンアップ
if [[ $lock_attempts -ge $max_lock_attempts ]]; then
    print_warning "古いロックを検出しました。クリーンアップを試みます..."
    rmdir "$LOCK_DIR" 2>/dev/null || true
    sleep 1
    # クリーンアップ後にもう1回試行
    if mkdir "$LOCK_DIR" 2>/dev/null; then
        lock_acquired=true
    fi
fi
```

**改善効果:**
- 古いロックの自動クリーンアップ
- より確実なロック取得
- エラー時の手動対処方法を表示

### コード変更箇所

**ファイル**: `playcover-complete-manager.command`

1. **PlayCover保護チェック** (lines 2433-2451)
   ```bash
   if [[ "$selected_volume" == "PlayCover" ]] && [[ $total_apps -gt 1 ]]; then
       # エラーメッセージ表示
       # ガイダンス表示
       continue  # 削除せずに選択画面に戻る
   fi
   ```

2. **メニュー表示の変更** (line 2239)
   ```bash
   # 変更前: 1. IPAをインストール
   # 変更後: 1. アプリをインストール
   ```

3. **警告メッセージの更新** (lines 2464-2473)
   ```bash
   echo "  5. Containersフォルダを削除"  # 追加
   echo "  6. APFSボリュームをアンマウント"
   echo "  7. APFSボリュームを削除"
   echo "  8. マッピング情報を削除"
   ```

4. **Containers削除処理** (lines 2541-2549)
   ```bash
   # Step 5: Remove Containers folder for the app
   local containers_dir="${HOME}/Library/Containers/${selected_bundle}"
   if [[ -d "$containers_dir" ]]; then
       rm -rf "$containers_dir"
   fi
   ```

5. **ロック取得の改善** (lines 2585-2621)
   ```bash
   # 最終リトライ時にクリーンアップ
   if [[ $lock_attempts -ge $max_lock_attempts ]]; then
       rmdir "$LOCK_DIR" 2>/dev/null || true
       # もう1回試行
   fi
   ```

### 削除処理の詳細（更新版）

```
アンインストール開始
│
├─ 【保護チェック】
│   └─ PlayCoverボリューム && 他のアプリあり → ❌ エラー
│
├─ Step 1: Applications/[BundleID].app 削除
├─ Step 2: App Settings/[BundleID].plist 削除
├─ Step 3: Entitlements/[BundleID].plist 削除
├─ Step 4: Keymapping/[BundleID].plist 削除
├─ Step 5: Containers/[BundleID]/ 削除        ← NEW
├─ Step 6: APFSボリュームのアンマウント
├─ Step 7: APFSボリュームの削除
└─ Step 8: マッピング情報の削除（ロック改善）  ← 改善
```

### バージョン更新内容

```
v4.3.1 → v4.3.2
- 行数: 3283行 → 3328行 (+45行)
- サイズ: 119KB → 121KB (+2KB)
- 新規機能: PlayCover保護チェック
- 改善機能: ロック取得メカニズム
- 追加削除: Containersフォルダ
```

### 使用シーン

#### シーン1: PlayCover保護の動作
```
# インストール済み: 3個のアプリ
1. 原神
2. 崩壊：スターレイル
3. PlayCover

# PlayCoverを選択
→ ❌ エラー
「PlayCoverボリュームは削除できません」
「理由: 他のアプリがまだインストールされています」

# 他のアプリを削除後
1. PlayCover（のみ）

# PlayCoverを選択
→ ✓ 削除可能
```

#### シーン2: 完全クリーンアップ
```
削除前:
~/Library/Containers/
├── io.playcover.PlayCover/
│   ├── Applications/com.example.app.app
│   ├── App Settings/com.example.app.plist
│   ├── Entitlements/com.example.app.plist
│   └── Keymapping/com.example.app.plist
└── com.example.app/
    └── Data/

削除後:
~/Library/Containers/
└── io.playcover.PlayCover/
    （すべて削除される）
```

#### シーン3: ロック回復
```
# 古いロックが残っている状態
playcover-map.txt.lock/ が存在

# アンインストール実行
→ ロック取得を10回試行
→ 「古いロックを検出しました。クリーンアップを試みます...」
→ ロッククリーンアップ
→ 再試行 → ✓ 成功
```

### ユーザーへの影響

**ポジティブな影響:**
- ✅ PlayCoverボリュームが保護される（誤削除防止）
- ✅ より自然なメニュー表現
- ✅ Containersフォルダも完全削除
- ✅ ロック問題の自動回復
- ✅ より確実なクリーンアップ

**注意事項:**
- ⚠️ PlayCoverボリュームは最後まで削除できない（仕様）

### 次回以降の改善案

1. **削除前のサイズ計算**
   - 削除されるファイルの合計サイズを表示

2. **削除履歴の記録**
   - いつ、何を削除したかのログ

3. **復元機能**
   - 削除前の自動バックアップ

---

## まとめ

v4.3.2では、ユーザーフィードバックに基づく重要な改善を実施しました。

**主な改善点:**
1. 【保護機能】PlayCoverボリュームは他のアプリがある間は削除不可
2. 【UI改善】メニュー名を「アプリをインストール/アンインストール」に統一
3. 【完全削除】Containersフォルダも削除対象に追加（8項目に）
4. 【ロック改善】古いロックの自動クリーンアップ

**v4.3.1からの改善:**
```
保護:     なし → PlayCoverボリューム保護
メニュー: 不統一 → 統一された表現
削除項目: 7項目 → 8項目（+Containers）
ロック:   失敗しやすい → 自動回復機能
```

**推奨**: v4.3.1をお使いの方は v4.3.2 へのアップグレードを推奨します。より安全で完全なアプリ管理が可能になります。
