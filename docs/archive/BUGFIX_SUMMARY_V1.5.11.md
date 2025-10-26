# Bug Fix Summary - Version 1.5.11

## Date
2025-10-25

## Critical Bug: ls command without absolute path causing storage detection failure

### Symptom
- Internal storage (with actual Data directory) incorrectly detected as "unmounted"
- Unable to switch from internal to external storage
- Storage type shows "⚪ (アンマウント済み)" instead of "💾 (内蔵ストレージ)"

### Root Cause
The `ls` command in `get_storage_type()` and `mount_volume()` functions was called without absolute path:
```bash
# BROKEN (v1.5.10):
local content_check=$(ls -A1 "$path" 2>/dev/null | /usr/bin/grep ...)
```

In user's shell environment, `ls` might be:
- Aliased (e.g., `alias ls='ls -G'` for colored output)
- Pointing to a different binary via PATH
- Causing unexpected output format or behavior

### Evidence
**Debug script (working correctly):**
```bash
/bin/ls -A1 "$path" | while read line; do
```
Output: Correctly shows "Data" and detects as internal storage

**Main script (broken):**
```bash
ls -A1 "$path" | /usr/bin/grep ...
```
When executed via `get_storage_type()`:
```
[DEBUG] Content check (filtered): ''
[DEBUG] Content length: 0
[DEBUG] Directory is empty or only has metadata (none)
none
```

But when executed directly in shell:
```bash
$ ls -A1 "/Users/hehex/Library/Containers/com.miHoYo.GenshinImpact" | /usr/bin/grep ...
Data
```

This proves the issue is environment-dependent (shell aliases/functions).

### Fix Applied

**File: `2_playcover-volume-manager.command`**

**1. Line 327 (get_storage_type function):**
```bash
# BEFORE:
local content_check=$(ls -A1 "$path" 2>/dev/null | /usr/bin/grep -v -x -F '.DS_Store' | ...)

# AFTER:
local content_check=$(/bin/ls -A1 "$path" 2>/dev/null | /usr/bin/grep -v -x -F '.DS_Store' | ...)
```

**2. Line 200 (mount_volume function):**
```bash
# BEFORE:
local content_check=$(ls -A1 "$target_path" 2>/dev/null | /usr/bin/grep -v -x -F '.DS_Store' | ...)

# AFTER:
local content_check=$(/bin/ls -A1 "$target_path" 2>/dev/null | /usr/bin/grep -v -x -F '.DS_Store' | ...)
```

### Why This Matters
Using absolute paths (`/bin/ls`) ensures:
1. **Predictable behavior**: Bypasses shell aliases and functions
2. **Consistent output format**: Always gets standard ls output
3. **Environment independence**: Works regardless of user's shell configuration

### Testing
After applying the fix, the storage detection should work correctly:

```bash
# Test in user environment:
source /Volumes/DATA/PlayCoverPortable/2_playcover-volume-manager.command
get_storage_type "/Users/hehex/Library/Containers/com.miHoYo.GenshinImpact" true

# Expected output:
[DEBUG] Content check (filtered): 'Data'
[DEBUG] Content length: 4
[DEBUG] Directory has actual content, checking disk location...
[DEBUG] Device: /dev/disk3s1, Disk ID: disk3
[DEBUG] Disk location: Internal
internal
```

### Related Files Modified
- `2_playcover-volume-manager.command` (v1.5.11)

### Version History
- v1.5.6: Fixed grep pattern matching (regex → fixed-string)
- v1.5.7: Fixed external→internal copy (remount to temp location first)
- v1.5.8: Fixed rsync error handling (accept exit codes 23/24)
- v1.5.10: Fixed ls multi-column output (ls -A → ls -A1)
- v1.5.11: **Fixed ls command path (ls → /bin/ls)** ← Current fix

### Impact
- **Critical**: Without this fix, internal storage detection completely fails
- **Scope**: Affects all storage type detection and switching operations
- **User Impact**: Unable to manage internal storage or switch to external storage

### Next Steps
1. Copy updated v1.5.11 script to user environment
2. Test storage type detection for all games
3. Verify storage switching operations work correctly
