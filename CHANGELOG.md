# PlayCover Scripts Changelog

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
