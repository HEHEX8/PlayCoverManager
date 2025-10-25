# PlayCover Scripts Changelog

## 2025-01-15 - Version 4.7.0: Enhanced Volume Management with App Termination

### Critical Changes to `playcover-complete-manager.command`

#### 1. PlayCover Volume Now Controllable (Lines 1296-1326, 1197-1210, 2228-2242)

**REMOVED:** Skip logic that excluded PlayCover volume from individual operations

**Before:**
```zsh
while IFS=$'\t' read -r volume_name bundle_id display_name; do
    if [[ "$bundle_id" == "$PLAYCOVER_BUNDLE_ID" ]]; then
        continue  # PlayCover was skipped
    fi
    # ... process volume
done
```

**After:**
```zsh
while IFS=$'\t' read -r volume_name bundle_id display_name; do
    # PlayCover is now included in all operations
    # ... process volume
done
```

**Impact:**
- Individual volume control menu now shows PlayCover volume
- "Unmount all volumes" now includes PlayCover volume
- Quick status display now counts PlayCover volume in statistics

#### 2. App Termination Before Unmount (Lines 436-485)

**NEW FUNCTION:** `quit_app_for_bundle()` - Gracefully quit apps before unmounting

**Implementation:**
```zsh
quit_app_for_bundle() {
    local bundle_id=$1
    
    # Skip if bundle_id is empty
    if [[ -z "$bundle_id" ]]; then
        return 0
    fi
    
    # Try to quit the app using osascript
    local app_name=$(get_display_name "$bundle_id")
    if [[ -n "$app_name" ]]; then
        /usr/bin/osascript -e "tell application \"$app_name\" to quit" 2>/dev/null || true
    fi
    
    # Wait a moment for the app to quit
    sleep 0.5
    
    # Force kill if still running
    /usr/bin/pkill -9 -f "$bundle_id" 2>/dev/null || true
}
```

**ENHANCED:** `unmount_volume()` now accepts optional bundle_id parameter

**Modified Signature:**
```zsh
unmount_volume() {
    local volume_name=$1
    local bundle_id=$2  # Optional: if provided, quit the app first
    
    # ... existing code ...
    
    # Quit app before unmounting if bundle_id is provided
    if [[ -n "$bundle_id" ]]; then
        quit_app_for_bundle "$bundle_id"
    fi
    
    # ... continue unmounting ...
}
```

**Impact:**
- Prevents data corruption by quitting apps before unmounting
- Uses graceful quit (osascript) first, then force kill if needed
- All unmount operations now pass bundle_id to quit apps automatically

#### 3. Enhanced Disk Eject with Full Volume Support (Lines 1390-1510)

**NEW FUNCTION:** `get_drive_name()` - Extract readable drive name for display

**COMPLETELY REWRITTEN:** `eject_disk()` - Now handles ALL volumes on the drive

**Key Changes:**
```zsh
# Get all volumes on this disk
local all_volumes=$(/usr/sbin/diskutil list "$disk_id" | /usr/bin/grep "APFS Volume" | /usr/bin/awk '{print $NF}')

if [[ -n "$all_volumes" ]]; then
    local volume_count=0
    while IFS= read -r vol_name; do
        # Try to find bundle_id for this volume from mappings
        local bundle_id=""
        local mappings_content=$(read_mappings)
        if [[ -n "$mappings_content" ]]; then
            while IFS=$'\t' read -r mapped_vol mapped_bundle mapped_display; do
                if [[ "$mapped_vol" == "$vol_name" ]]; then
                    bundle_id="$mapped_bundle"
                    break
                fi
            done <<< "$mappings_content"
        fi
        
        # Quit app if we found a bundle_id
        if [[ -n "$bundle_id" ]]; then
            quit_app_for_bundle "$bundle_id"
        fi
        
        # Unmount the volume
        sudo /usr/sbin/diskutil unmount "/Volumes/$vol_name" >/dev/null 2>&1 || true
        ((volume_count++))
    done <<< "$all_volumes"
fi
```

**Impact:**
- Unmounts ALL volumes on the drive, not just PlayCover-managed ones
- Quits associated apps before unmounting each volume
- Provides clear progress feedback for each volume
- Safe handling of both managed and unmanaged volumes

#### 4. Dynamic Menu Labeling (Lines 2263-2279)

**ENHANCED:** Main menu now shows actual drive name instead of generic label

**Before:**
```
8. ディスク全体を取り外し
```

**After:**
```zsh
# Dynamic eject menu label (v4.7.0)
local eject_label="ディスク全体を取り外し"
if [[ -n "$PLAYCOVER_VOLUME_DEVICE" ]]; then
    local drive_name=$(get_drive_name)
    eject_label="「${drive_name}」の取り外し"
fi

echo "  8. ${eject_label}              9. マッピング情報を表示                0. 終了"
```

**Impact:**
- Users can see which drive will be ejected
- More intuitive and safer operation
- Real-time detection of drive information

#### Updated Call Signatures

All `unmount_volume()` calls now pass bundle_id when available:

1. Line 1205: `unmount_all_volumes()` → `unmount_volume "$volume_name" "$bundle_id"`
2. Line 1367: `individual_volume_control()` → `unmount_volume "$volume_name" "$bundle_id"`
3. Line 1781: Storage switching → `unmount_volume "$volume_name" "$bundle_id"`
4. Line 1878: Rollback operation → `unmount_volume "$volume_name" "$bundle_id"`
5. Line 2147: Cleanup after switching → `unmount_volume "$volume_name" "$bundle_id"`

### Version Number Updates

- **Header comment:** Version 4.6.0 → 4.7.0
- **Menu display:** Version 3.0.1 → 4.7.0
- **Subtitle:** "Streamlined Output Across All Functions" → "Enhanced Volume Management with App Termination"

### Benefits

1. **Data Safety**: Apps are gracefully quit before unmounting, preventing data corruption
2. **Flexibility**: PlayCover volume can now be individually controlled like other volumes
3. **Completeness**: Disk eject now handles all volumes on the drive, not just managed ones
4. **User Experience**: Dynamic menu labels provide clear information about operations
5. **Consistency**: All unmount operations follow the same app termination pattern

### Testing Checklist

- [ ] Individual volume control shows PlayCover volume
- [ ] Unmount all volumes includes PlayCover volume
- [ ] Apps quit gracefully before unmounting
- [ ] Disk eject unmounts all volumes on drive
- [ ] Menu displays correct drive name
- [ ] No data corruption after unmount operations
- [ ] Quick status includes PlayCover in counts

---

## 2025-01-XX - Auto-Mount PlayCover Main Volume Feature

### Changes to `2_playcover-volume-manager.command`

#### New Feature: Automatic PlayCover Main Volume Mounting

When mounting individual IPA volumes through the individual volume control menu, the script now automatically ensures the PlayCover main volume is also mounted.

#### Implementation Details

1. **Added new helper function `ensure_playcover_main_volume()`** (lines 257-294)
   - Checks if PlayCover main volume exists
   - Verifies if it's already mounted at the correct location
   - Automatically mounts it if needed
   - Handles unmounting from incorrect locations
   - Uses `-o nobrowse` flag to hide from Finder/Desktop
   - Includes proper error handling with `|| true` to prevent script exit

2. **Updated individual volume control - Remount option** (lines 591-600)
   - When user selects option "2" (再マウント - Remount)
   - Calls `ensure_playcover_main_volume()` before mounting the IPA volume
   - Displays appropriate status messages

3. **Updated individual volume control - Initial mount option** (lines 611-617)
   - When user selects "Y" to mount an unmounted volume
   - Calls `ensure_playcover_main_volume()` before mounting the IPA volume
   - Displays appropriate status messages

#### Benefits

- **Prevents errors**: Ensures PlayCover main volume is available before mounting app volumes
- **Better user experience**: Users don't need to manually mount PlayCover volume first
- **Consistent behavior**: Both mount and remount operations follow the same pattern
- **Clean code**: Reusable helper function eliminates code duplication

#### User Experience Flow

Before:
```
1. User selects individual app volume to mount
2. App volume mounts (may fail if PlayCover not mounted)
```

After:
```
1. User selects individual app volume to mount
2. Script checks PlayCover main volume status
3. If not mounted: "PlayCover メインボリュームをマウント中..."
4. If already mounted: "PlayCover メインボリュームは既にマウント済みです"
5. Then mounts the app volume
```

#### Technical Notes

- The helper function uses `|| true` to allow graceful continuation even if PlayCover mount fails
- Function returns 0 on success, 1 on failure
- Properly handles cases where PlayCover volume is:
  - Already mounted at correct location (skips)
  - Mounted at wrong location (remounts)
  - Not mounted at all (mounts)
  - Missing entirely (displays warning)

#### Testing Checklist

- [ ] Test mounting unmounted IPA volume (PlayCover already mounted)
- [ ] Test mounting unmounted IPA volume (PlayCover not mounted)
- [ ] Test remounting IPA volume (PlayCover already mounted)
- [ ] Test remounting IPA volume (PlayCover not mounted)
- [ ] Verify volumes are hidden from Finder/Desktop
- [ ] Verify proper error messages when PlayCover volume missing
- [ ] Test with multiple different IPA volumes

---

## Previous Changes

### Phase 1-6: Core Functionality
- Mount/unmount operations with `-o nobrowse` flag
- Volume detection and status checking
- Japanese name display support
- Unified UI with consistent colors
- Bug fixes for zsh compatibility
- Error handling improvements

### Phase 7: Automatic Main Volume Mounting
- Automatic PlayCover main volume mounting when mounting individual IPA volumes

### Phase 8: Storage Location Switching
- **New Feature**: Switch between internal and external storage for individual apps
- **Menu Option 6**: ストレージ切り替え（内蔵⇄外部）
- **Bidirectional Migration**: Internal ⇄ External storage with automatic data copy
- **Safety Features**: Automatic backup, error rollback, confirmation prompts
- **Storage Detection**: Automatic detection of current storage type (internal/external)
- **Visual Indicators**: 💾 (internal), 🔌 (external), ❓ (unknown), ❌ (no data)
- **Bug Fix v1.3.1**: Fixed "command not found" errors by using absolute paths for all external commands
- **Bug Fix v1.3.2**: Improved storage type detection logic - prioritizes mount state check
- **Bug Fix v1.3.3**: Fixed incorrect external detection after successful migration - now properly checks path existence and mount state first
- **Improvement v1.3.4**: Terminal now auto-closes when selecting "Exit" option or pressing Ctrl+C
- **Bug Fix v1.4.1**: Fixed mount protection logic that incorrectly blocked remounting after unmount - now checks for actual data content instead of just directory existence

### Phase 9: Mount Protection Feature (v1.4.0)
- **New Feature**: Prevent accidental data loss when mounting external volumes over internal storage
- **Protection Logic**: Blocks external volume mounting if internal storage data exists
- **User Guidance**: Provides clear instructions to use storage switching feature instead
- **Manual Override**: Option to manually backup and remove internal data if needed

### Phase 10: Bug Fix - Mount Protection Logic (v1.4.1)
- **Fixed Issue**: Mount protection was incorrectly blocking all remount attempts after unmounting
- **Root Cause**: Empty mount point directories were mistakenly identified as internal storage data
- **Solution**: Added content check with `ls -A` to distinguish empty directories from actual data
- **Behavior Change**: Empty directories are now automatically removed before mounting
- **Impact**: Normal mount/unmount/remount operations now work correctly while still protecting real internal data

### Phase 11: Bug Fix - Empty Directory Storage Detection (v1.4.2)
- **Fixed Issue**: Empty directories were still being detected as "internal storage" in status display and storage switching
- **Root Cause**: `get_storage_type()` function was not updated in v1.4.1, only `mount_volume()` was fixed
- **Solution**: Added empty directory check to `get_storage_type()` function to return new state "none"
- **New State**: `none` - indicates unmounted state with empty directory (⚪ icon)
- **UI Improvements**: 
  - Option 4: Correct status display for unmounted volumes
  - Option 6: Prevents inappropriate storage switching attempts, shows helpful guidance
- **Impact**: All storage type detection now accurately distinguishes between empty directories and real internal data

### Phase 12: Quick Status Display on Main Menu (v1.5.0)
- **New Feature**: Display current mount status on main menu screen before showing options
- **Quick Status Display**:
  - Shows mounted vs unmounted volume counts (e.g., "🔌 マウント中: 2/4")
  - Displays compact list of all volumes with status icons
  - Visual indicators: 🔌 (mounted), 💾 (internal), ⚪ (unmounted)
- **New Function**: `show_quick_status()` - generates compact status overview
- **Benefits**:
  - Users can see volume status at a glance without entering Option 4
  - Faster workflow - immediate visibility of current state
  - Better situational awareness before selecting an action
- **UI Layout**: Status display appears between title and menu options

### Phase 13: Critical Bug Fix - Storage Switching Data Copy (v1.5.1)
- **Fixed Critical Issue**: Storage switching (Option 6) was failing to copy data correctly
- **Bug 1**: `mv: cannot rename a mount point` error when trying to backup mounted directories
- **Bug 2**: rsync showing `speedup is 22043.92` indicated data was not actually transferred
- **Bug 3**: Result was empty internal storage (0 bytes) despite 1GB source data
- **Root Cause**: 
  - Attempting to move mount point directory without unmounting first
  - rsync copying from same path to itself ($target_path → $target_path)
  - No mount point detection before backup operation
- **Solution**:
  - Added mount point detection with `mount | grep` check
  - Unmount before attempting directory operations
  - Added 1-second wait after unmount for system to catch up
  - Improved rsync with `--progress` for better progress display (macOS compatible)
  - Added debug info showing file counts and sizes before/after copy
  - Added data verification after copy completion
- **Impact**: 
  - Critical data loss risk eliminated
  - Storage switching now works correctly in all scenarios
  - Users can see actual data being transferred
  - Verification confirms successful copy
- **New Feature v1.4.0**: Mount Protection - blocks external volume mounting when internal storage data exists to prevent data loss

### Phase 14: Documentation Fix - rsync Compatibility (v1.5.2)
- **Fixed Documentation Issue**: v1.5.1 documentation incorrectly referenced `--info=progress2` option
- **Clarification**: Actual code already uses `--progress` (compatible with macOS rsync 2.6.9)
- **Issue**: `--info=progress2` requires rsync 3.1.0+ (not available in macOS by default)
- **Verification**: 
  - Line 1110: Uses `rsync -avH --progress` (Internal → External)
  - Line 1239: Uses `rsync -avH --progress` (External → Internal)
- **User Impact**: If users see `rsync: unrecognized option '--info=progress2'` error, they are running an older cached version
- **Failsafe Confirmation**: User confirmed failsafe mechanisms work correctly - errors are caught and backups restored
- **Documentation**: 
  - Updated `BUGFIX_SUMMARY_V1.5.1.md` to reflect correct rsync options
  - Created `BUGFIX_SUMMARY_V1.5.2.md` with compatibility details
- **Note**: No code changes needed - implementation was already correct

### Phase 15: Storage Detection Display Fix (v1.5.3)
- **Fixed Critical Display Bug**: Internal storage incorrectly shown as "unmounted" (アンマウント済み)
- **User Report**: Directory with subdirectory content detected as empty
  - Example: `/Users/user/Library/Containers/com.HoYoverse.hkrpgoversea/com.HoYoverse.hkrpgoversea/`
  - `ls` shows content, but script displayed as "⚪ アンマウント済み"
  - Expected: "💾 内蔵ストレージ"
- **Root Cause**: `show_quick_status()` counted internal storage as unmounted
- **Solution**:
  - Fixed counting logic in `show_quick_status()` to treat internal storage as "has data"
  - Added debug option to `get_storage_type()` for troubleshooting
  - Improved display labels: "データあり / データなし" instead of "マウント / アンマウント"
- **Debug Tool**: Created `debug_storage_detection.sh` for user environment diagnosis
- **Impact**: 
  - Correct display of internal storage status in main menu
  - Better understanding of data location for users
  - Mount protection still works correctly (verified by user)

### Phase 16: macOS Metadata Files Filtering (v1.5.4)
- **Fixed Critical Bug**: Mount protection incorrectly triggered by macOS metadata files
- **User Report**: 
  - Empty directory (confirmed with `ls`) but mount blocked
  - Script detected `.DS_Store` as "internal storage data"
  - Mount protection blocked mounting unnecessarily
- **Root Cause**: 
  - `ls` (without -A) hides `.DS_Store` and other dot files
  - `ls -A` (used in script) shows `.DS_Store`
  - Script treated `.DS_Store` as user data
- **Solution**:
  - Filter out macOS metadata files in `mount_volume()` (Line 198-223)
  - Filter out macOS metadata files in `get_storage_type()` (Line 319-334)
  - Excluded files: `.DS_Store`, `.Spotlight-V100`, `.Trashes`, `.fseventsd`
  - Display detected files when mount protection triggers
- **Benefits**:
  - Directories with only `.DS_Store` can now be mounted
  - More accurate storage type detection
  - Users can see what files triggered protection
- **Impact**:
  - Mount protection now only blocks for actual user data
  - False positives eliminated for metadata-only directories
  - Improved user experience with clear feedback

### Phase 17: Absolute Path for grep Command (v1.5.5)
- **Fixed Critical Bug**: `grep: command not found` error in v1.5.4
- **User Report**: 
  - `get_storage_type:24: command not found: grep`
  - Error appears multiple times in menu display
  - Confirmed `.DS_Store` exists with `ls -A`
- **Root Cause**: 
  - Used `grep` without absolute path in metadata filtering
  - zsh scripts require absolute paths for all external commands
  - Line 325 and Line 200 used relative `grep`
- **Solution**:
  - Changed `grep` to `/usr/bin/grep` in both locations
  - Line 325: `get_storage_type()` function
  - Line 200: `mount_volume()` function
- **Verification**:
  - User confirmed `.DS_Store` presence with `ls -A`
  - User manually deleted duplicate subdirectory
  - Now only `.DS_Store` remains (should be filtered)
- **Impact**:
  - Error messages eliminated
  - Metadata filtering now works correctly
  - Script can properly detect storage types
