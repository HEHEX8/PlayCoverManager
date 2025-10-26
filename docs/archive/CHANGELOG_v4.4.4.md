# PlayCover Complete Manager - Version 4.4.4

## Release Date
2025-10-25

## Release Type
🔧 **Enhancement** - Complete PlayCover removal with terminal exit

---

## ✨ New Features

### 1. PlayCover.app Automatic Removal on Uninstall

**Problem:**
- When uninstalling PlayCover volume, only container data was removed
- PlayCover.app remained in `/Applications/` directory
- Users had to manually delete PlayCover.app separately

**Solution:**
PlayCover volume uninstall now includes:
1. Remove PlayCover container data (as before)
2. **NEW**: Delete `/Applications/PlayCover.app`
3. **NEW**: Automatic terminal exit

**Implementation (Individual Uninstall):**
```bash
# Step 10: If PlayCover volume, remove PlayCover.app and exit
if [[ "$selected_volume" == "PlayCover" ]]; then
    echo ""
    print_info "PlayCover本体を削除中..."
    
    local playcover_app="/Applications/PlayCover.app"
    if [[ -d "$playcover_app" ]]; then
        if rm -rf "$playcover_app" 2>/dev/null; then
            print_success "PlayCover.appを削除しました"
        else
            print_warning "PlayCover.appの削除に失敗しました（手動削除が必要です）"
        fi
    else
        print_warning "PlayCover.appが見つかりませんでした"
    fi
    
    echo ""
    print_success "PlayCoverのアンインストールが完了しました"
    echo ""
    print_warning "PlayCoverを削除したため、このスクリプトは今後使用できません"
    echo "再度使用するには、PlayCoverを再インストールしてください"
    echo ""
    echo -n "Enterキーでターミナルを終了します..."
    read
    exit 0
fi
```

**Implementation (Batch Uninstall):**
```bash
# Step 8: Remove PlayCover.app
echo ""
print_info "PlayCover本体を削除中..."

local playcover_app="/Applications/PlayCover.app"
if [[ -d "$playcover_app" ]]; then
    if rm -rf "$playcover_app" 2>/dev/null; then
        print_success "PlayCover.appを削除しました"
    else
        print_warning "PlayCover.appの削除に失敗しました（手動削除が必要です）"
    fi
else
    print_warning "PlayCover.appが見つかりませんでした"
fi

# ... Summary display ...

print_warning "PlayCoverを削除したため、このスクリプトは今後使用できません"
echo "再度使用するには、PlayCoverを再インストールしてください"
echo ""
echo -n "Enterキーでターミナルを終了します..."
read
exit 0
```

### 2. Terminal Auto-Exit After PlayCover Removal

**Rationale:**
- PlayCover removal makes the script non-functional
- Script depends on PlayCover environment (`~/Library/Containers/io.playcover.PlayCover/`)
- Continuing after PlayCover removal would cause errors
- Clean exit prevents user confusion

**User Experience:**

**Before v4.4.4:**
```
✓ ボリュームを削除しました
✓ マッピング情報を削除しました
✓ アンインストールが完了しました

Enterキーでメニューに戻る...  ← Back to menu (but script won't work!)
```

**After v4.4.4:**
```
✓ ボリュームを削除しました
✓ マッピング情報を削除しました
ℹ PlayCover本体を削除中...
✓ PlayCover.appを削除しました
✓ PlayCoverのアンインストールが完了しました

⚠ PlayCoverを削除したため、このスクリプトは今後使用できません
再度使用するには、PlayCoverを再インストールしてください

Enterキーでターミナルを終了します...  ← Terminal closes
[Process completed]
```

---

## 🔍 Technical Details

### Uninstall Flow Comparison

**Individual Uninstall Flow:**
```
1. User selects PlayCover volume
2. Confirmation prompt
3. Delete container data
4. Delete APFS volume
5. Remove from playcover-map.txt  ✓ Already implemented
6. Check if volume == "PlayCover"  ← NEW
7. Delete /Applications/PlayCover.app  ← NEW
8. Display completion message  ← NEW
9. exit 0  ← NEW (terminal closes)
```

**Batch Uninstall Flow:**
```
1. User selects "ALL"
2. Confirmation prompt
3. Loop through all apps:
   - Delete container data
   - Delete APFS volumes
4. Clear playcover-map.txt  ✓ Already implemented
5. Delete /Applications/PlayCover.app  ← NEW
6. Display completion message  ← NEW
7. exit 0  ← NEW (terminal closes)
```

### PlayCover Volume Detection

**Method:**
```bash
if [[ "$selected_volume" == "PlayCover" ]]; then
    # This is the PlayCover container volume
    # Remove PlayCover.app and exit
fi
```

**Why this works:**
- PlayCover volume is always named "PlayCover" (constant: `PLAYCOVER_VOLUME_NAME`)
- Other app volumes have custom names (e.g., "GenshinImpact", "ZenlessZoneZero")
- Simple string comparison is reliable

### Mapping File Consistency

**Already Implemented in v4.4.3:**
- Individual uninstall: Uses `remove_mapping($bundle_id)` (line 2632)
- Batch uninstall: Clears entire file `> "$MAPPING_FILE"` (line 2852)

**No changes needed** - mapping removal was already working correctly.

---

## 📋 Changed Files

### `playcover-complete-manager.command`

**Modified Sections:**

1. **Line 6**: Version header updated
   - `4.4.3` → `4.4.4`

2. **Lines 2640-2666**: Individual uninstall enhancement
   - Added PlayCover volume detection
   - Added PlayCover.app removal
   - Added terminal exit with `exit 0`
   - Added user warning message

3. **Lines 2858-2883**: Batch uninstall enhancement
   - Added PlayCover.app removal step
   - Added terminal exit with `exit 0`
   - Added user warning message

---

## 📊 Code Statistics

### Lines Changed
- **Added**: ~40 lines (PlayCover removal + exit logic)
- **Modified**: 2 functions

### File Size
- **Before**: 3518 lines (v4.4.3)
- **After**: 3558 lines (v4.4.4)
- **Growth**: +40 lines

---

## 🎯 Testing Scenarios

### Scenario 1: Individual Uninstall of PlayCover
```
User action:
  1. Select "2. アプリをアンインストール"
  2. Select PlayCover volume
  3. Confirm with "yes"

Expected result:
  ✓ Container data deleted
  ✓ APFS volume deleted
  ✓ Mapping entry removed
  ✓ PlayCover.app deleted
  ⚠ Warning message displayed
  → Terminal exits
```

### Scenario 2: Batch Uninstall (ALL)
```
User action:
  1. Select "2. アプリをアンインストール"
  2. Enter "ALL"
  3. Confirm with "yes"

Expected result:
  ✓ All app containers deleted
  ✓ All APFS volumes deleted
  ✓ All mapping entries cleared
  ✓ PlayCover.app deleted
  ⚠ Warning message displayed
  → Terminal exits
```

### Scenario 3: Individual Uninstall of Non-PlayCover App
```
User action:
  1. Select "2. アプリをアンインストール"
  2. Select game app (e.g., GenshinImpact)
  3. Confirm with "yes"

Expected result:
  ✓ App container deleted
  ✓ APFS volume deleted
  ✓ Mapping entry removed
  → Script continues (no exit)
  → User can uninstall more apps
```

---

## 🔄 Upgrade Impact

### Breaking Changes
**None** - Only adds new behavior when PlayCover is uninstalled

### Behavioral Changes
1. **PlayCover uninstall**: Now removes PlayCover.app automatically
2. **Terminal exit**: Script terminates after PlayCover removal
3. **Warning message**: Clear notification about script becoming unusable

### Migration Path
Simply replace script file - no manual intervention needed.

---

## 📝 Version Comparison

| Feature | v4.4.3 | v4.4.4 |
|---------|--------|--------|
| Lock mechanism | ✅ Fixed | ✅ Fixed |
| Duplicate prevention | ✅ Yes | ✅ Yes |
| Mapping removal | ✅ Yes | ✅ Yes |
| PlayCover.app removal | ❌ Manual | ✅ Automatic |
| Terminal exit | ❌ No | ✅ Yes (after PlayCover removal) |
| Warning message | ❌ No | ✅ Yes |

---

## 💡 Design Rationale

### Why Remove PlayCover.app?

1. **Complete cleanup**: Users expect complete uninstall
2. **Consistency**: Matches behavior of other uninstallers
3. **No orphaned files**: Prevents confusion with leftover app

### Why Exit Terminal?

1. **Prevent errors**: Script can't function without PlayCover
2. **Clear communication**: User knows script is done
3. **Avoid confusion**: Prevents attempts to use broken script
4. **Clean state**: Fresh start when PlayCover reinstalled

### Why Check Volume Name?

1. **Accurate detection**: Volume name is definitive identifier
2. **Simple logic**: No complex checks needed
3. **Reliable**: PlayCover volume always named "PlayCover"
4. **Maintainable**: Easy to understand and modify

---

## 🚀 User Journey

### Complete Removal Journey

**Step 1: User decides to remove everything**
```
User: "I want to remove PlayCover and all games"
Action: Select "2. アプリをアンインストール" → "ALL"
```

**Step 2: Confirmation**
```
⚠ この操作は以下を実行します:
  1. すべてのアプリを PlayCover から削除
  2-7. [other cleanup steps]

✗ この操作は取り消せません！
✗ PlayCoverを含むすべてのアプリが削除されます！

本当にすべてのアプリをアンインストールしますか？ (yes/NO): yes
```

**Step 3: Execution**
```
ℹ [1/6] PlayCover を削除中...
✓ ✓ PlayCover

ℹ [2/6] ゼンレスゾーンゼロ を削除中...
✓ ✓ ゼンレスゾーンゼロ

[... other apps ...]

ℹ マッピング情報をクリア中...
✓ マッピング情報をクリアしました

ℹ PlayCover本体を削除中...
✓ PlayCover.appを削除しました
```

**Step 4: Completion**
```
═══════════════════════════════════════════════
✓ 一括アンインストールが完了しました

  成功: 6 個

⚠ PlayCoverを削除したため、このスクリプトは今後使用できません
再度使用するには、PlayCoverを再インストールしてください

Enterキーでターミナルを終了します...
[Process completed]
```

### Re-installation Journey

**When user wants to use PlayCover again:**
```
1. Download and install PlayCover.app
2. Run this script again
3. Initial setup will detect PlayCover
4. Script becomes functional again
```

---

## 🙏 Credits

Feature request by user:
- "PlayCoverコンテナボリュームのアンインストールは、アプリそのものもアンインストールする"
- "アンインストール完了後はターミナルを閉じるようにする"
- "アンインストールした項目はplaycover-map.txtの登録からも抹消する"

All three requirements implemented in v4.4.4! 🎉

---

## 📌 Summary

v4.4.4 provides a **complete, clean, and user-friendly uninstall experience**:

✅ **Complete removal**: PlayCover.app + containers + volumes + mappings  
✅ **Clean exit**: Terminal closes automatically  
✅ **Clear communication**: User knows exactly what happened  
✅ **Prevents errors**: Script can't be used in broken state  
✅ **Fresh start**: Clean slate for re-installation

The uninstall process is now production-ready and matches user expectations! 🎊
