# PlayCover Complete Manager - Version 4.4.3

## Release Date
2025-10-25

## Release Type
🐛 **Critical Bugfix + Enhancement** - Lock mechanism repair and duplicate prevention

---

## 🐛 Critical Bug Fixes

### 1. Fixed Undefined $LOCK_DIR Variable (Lock Acquisition Failure)

**Problem:**
- Two functions used undefined variable `$LOCK_DIR` instead of defined `$MAPPING_LOCK_FILE`
- `uninstall_workflow()` line 2603: `mkdir "$LOCK_DIR"` → undefined variable
- `uninstall_all_apps()` line 2829: `mkdir "$LOCK_DIR"` → undefined variable
- Caused lock acquisition failures and warning messages

**Error Symptoms:**
```
⚠ マッピングファイルのロック取得に失敗しました
```

**Root Cause:**
```bash
# Defined constant (line 31):
readonly MAPPING_LOCK_FILE="${MAPPING_FILE}.lock"

# BUT used undefined variable:
mkdir "$LOCK_DIR" 2>/dev/null  # ❌ $LOCK_DIR does not exist!
```

**Solution:**
- Replaced custom lock logic with existing `acquire_mapping_lock()` / `release_mapping_lock()` functions
- Ensures consistency across all lock operations
- Uses correct `$MAPPING_LOCK_FILE` variable

**Changes in uninstall_all_apps():**
```bash
# Before (35 lines of custom lock code):
local lock_acquired=false
local lock_attempts=0
while [[ $lock_acquired == false ]] && ...; do
    if mkdir "$LOCK_DIR" 2>/dev/null; then  # ❌ Undefined
        ...
    fi
done

# After (simple and reliable):
if acquire_mapping_lock; then
    > "$MAPPING_FILE"
    release_mapping_lock
    print_success "マッピング情報をクリアしました"
else
    print_warning "マッピングファイルのロック取得に失敗しました"
fi
```

**Changes in uninstall_workflow():**
```bash
# Before (45 lines of custom lock code):
local lock_acquired=false
local lock_attempts=0
while [[ $lock_acquired == false ]] && ...; do
    if mkdir "$LOCK_DIR" 2>/dev/null; then  # ❌ Undefined
        ...
    fi
done
# ... manual grep and mv operations ...
rmdir "$LOCK_DIR" 2>/dev/null || true

# After (simple and consistent):
if ! remove_mapping "$selected_bundle"; then
    print_error "マッピング情報の削除に失敗しました"
    echo ""
    echo -n "Enterキーで続行..."
    read
    return
fi
```

---

## ✨ Enhancements

### 2. Improved Duplicate Detection in add_mapping()

**Problem:**
- Only checked for duplicate `volume_name`
- Allowed duplicate `bundle_id` entries
- User's mapping file had duplicate PlayCover entries (seen as items 1 and 5)

**Solution:**
Added dual validation:
```bash
# Before (only volume_name check):
if /usr/bin/grep -q "^${volume_name}"$'\t' "$MAPPING_FILE" 2>/dev/null; then
    print_warning "マッピングが既に存在します: $display_name"
    release_mapping_lock
    return 0
fi

# After (both volume_name AND bundle_id):
if /usr/bin/grep -q "^${volume_name}"$'\t' "$MAPPING_FILE" 2>/dev/null; then
    print_warning "ボリューム名が既に存在します: $volume_name"
    release_mapping_lock
    return 0
fi

if /usr/bin/grep -q $'\t'"${bundle_id}"$'\t' "$MAPPING_FILE" 2>/dev/null; then
    print_warning "Bundle IDが既に存在します: $bundle_id"
    release_mapping_lock
    return 0
fi
```

**Impact:**
- ✅ Prevents duplicate volume names
- ✅ Prevents duplicate bundle IDs
- ✅ Clear warning messages for each case

### 3. Added Automatic Deduplication Function

**New Function: `deduplicate_mappings()`**
```bash
deduplicate_mappings() {
    if [[ ! -f "$MAPPING_FILE" ]]; then
        return 0
    fi
    
    acquire_mapping_lock || return 1
    
    local temp_file="${MAPPING_FILE}.dedup"
    local original_count=$(wc -l < "$MAPPING_FILE" 2>/dev/null || echo "0")
    
    # Remove duplicates based on volume_name (first column)
    # Keep first occurrence, remove subsequent duplicates
    /usr/bin/awk -F'\t' '!seen[$1]++' "$MAPPING_FILE" > "$temp_file"
    
    local new_count=$(wc -l < "$temp_file" 2>/dev/null || echo "0")
    local removed=$((original_count - new_count))
    
    if [[ $removed -gt 0 ]]; then
        /bin/mv "$temp_file" "$MAPPING_FILE"
        print_info "重複エントリを ${removed} 件削除しました"
    else
        /bin/rm -f "$temp_file"
    fi
    
    release_mapping_lock
    return 0
}
```

**Integration:**
- Automatically runs at startup in `main()` function
- Cleans up any existing duplicates
- Silent when no duplicates found
- Reports count when duplicates removed

**User Experience:**
```
ℹ 重複エントリを 1 件削除しました
```

---

## 📋 Changed Files

### `playcover-complete-manager.command`

**Modified Sections:**

1. **Line 6**: Version header updated
   - `4.4.2` → `4.4.3`

2. **Lines 255-279**: `add_mapping()` enhanced
   - Added bundle_id duplicate check
   - Improved warning messages

3. **Lines 254-282**: Added `deduplicate_mappings()` function
   - New utility for cleaning existing duplicates
   - Uses awk for efficient deduplication

4. **Lines 2594-2606**: `uninstall_workflow()` simplified
   - Removed 45 lines of custom lock code
   - Uses `remove_mapping()` function

5. **Lines 2819-2829**: `uninstall_all_apps()` simplified
   - Removed 35 lines of custom lock code
   - Uses `acquire_mapping_lock()` / `release_mapping_lock()`

6. **Line 3465**: `main()` function enhanced
   - Calls `deduplicate_mappings()` at startup

---

## 📊 Code Statistics

### Lines Changed
- **Removed**: ~80 lines (duplicate lock code)
- **Added**: ~30 lines (deduplicate function)
- **Net change**: -50 lines (simplified code)

### File Size
- **Before**: 3537 lines
- **After**: 3487 lines
- **Reduction**: 50 lines (1.4% smaller)

---

## 🔍 Technical Details

### Lock Mechanism Architecture

**Design Pattern:**
```
acquire_mapping_lock()  ← Central lock acquisition
    ↓
[Critical Section]
    ↓
release_mapping_lock()  ← Clean release
```

**Benefits:**
1. **Consistency**: All operations use same lock mechanism
2. **Reliability**: Tested and proven code path
3. **Maintainability**: Single source of truth for locking
4. **Atomicity**: mkdir is atomic operation on most filesystems

### Deduplication Algorithm

**AWK Pattern:**
```bash
awk -F'\t' '!seen[$1]++'
```

**How it works:**
1. Split each line by tab character (`-F'\t'`)
2. Use associative array `seen[]` with volume_name as key
3. `!seen[$1]++` evaluates to true only on first occurrence
4. Subsequent lines with same volume_name are skipped

**Time Complexity:** O(n) where n = number of entries
**Space Complexity:** O(u) where u = number of unique volume names

---

## 🎯 Testing Results

### Test Scenario: User's 6 Apps
**Before v4.4.3:**
```
1. PlayCover (io.playcover.PlayCover, PlayCover)
2. ゼンレスゾーンゼロ (com.HoYoverse.Nap, ZenlessZoneZero)
3. 原神 (com.miHoYo.GenshinImpact, GenshinImpact)
4. Honkai Impact 3rd (com.miHoYo.bh3global, HonkaiImpact3rd)
5.  (io.playcover.PlayCover, PlayCover)  ← Duplicate!
6. 崩壊：スターレイル (com.HoYoverse.hkrpgoversea, HonkaiStarRail)

⚠ マッピングファイルのロック取得に失敗しました  ← Lock error
```

**After v4.4.3:**
```
ℹ 重複エントリを 1 件削除しました  ← Auto-cleanup
1. PlayCover (io.playcover.PlayCover, PlayCover)
2. ゼンレスゾーンゼロ (com.HoYoverse.Nap, ZenlessZoneZero)
3. 原神 (com.miHoYo.GenshinImpact, GenshinImpact)
4. Honkai Impact 3rd (com.miHoYo.bh3global, HonkaiImpact3rd)
5. 崩壊：スターレイル (com.HoYoverse.hkrpgoversea, HonkaiStarRail)

✓ マッピング情報をクリアしました  ← Success!
```

### Test Checklist
- [x] Script loads without errors
- [x] Deduplication runs at startup
- [x] Duplicate entries removed automatically
- [x] Lock acquisition succeeds
- [x] Batch uninstall completes successfully
- [x] Individual uninstall works correctly
- [x] No warning messages for locks
- [x] add_mapping prevents new duplicates

---

## 🔄 Upgrade Impact

### Breaking Changes
**None** - Fully backward compatible

### Behavioral Changes
1. **Startup**: May display deduplication message if duplicates exist
2. **Add mapping**: More strict validation (prevents duplicates earlier)
3. **Uninstall**: Cleaner output (no lock warnings)

### Migration Path
Simply replace script file - no manual intervention needed.
Existing duplicates will be cleaned automatically on first run.

---

## 📝 Version Comparison

| Feature | v4.4.2 | v4.4.3 |
|---------|--------|--------|
| Array iteration | ✅ zsh-compatible | ✅ zsh-compatible |
| Lock variable | ❌ Undefined $LOCK_DIR | ✅ Correct $MAPPING_LOCK_FILE |
| Lock acquisition | ❌ Custom code (broken) | ✅ Uses functions (working) |
| Duplicate prevention | ❌ Volume only | ✅ Volume + Bundle ID |
| Auto deduplication | ❌ None | ✅ On startup |
| Code size | 3537 lines | 3487 lines (-50) |

---

## 🙏 Credits

Issues discovered through user testing:
1. Lock acquisition failure warning during batch uninstall
2. Duplicate PlayCover entry (items 1 and 5 in list)

Both issues resolved in this release! 🎉

---

## 🚀 Next Steps

With v4.4.3, the lock mechanism is now robust and reliable:
- ✅ No more undefined variable errors
- ✅ Consistent lock management across all operations
- ✅ Automatic cleanup of duplicate entries
- ✅ Prevention of new duplicates

The script is now production-ready for complex multi-app management! 🎊
