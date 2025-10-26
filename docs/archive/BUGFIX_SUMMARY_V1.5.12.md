# Bug Fix Summary - Version 1.5.12

## Date
2025-10-25

## CRITICAL Bug: zsh `path` variable conflict breaking all commands

### Symptom
When sourcing the script and calling `get_storage_type()`:
```bash
source /Volumes/DATA/PlayCoverPortable/2_playcover-volume-manager.command
get_storage_type "/Users/hehex/Library/Containers/com.miHoYo.GenshinImpact" true

# Results in:
[DEBUG] Content check (filtered): ''
[DEBUG] Content length: 0
none
```

Even though direct command execution works:
```bash
$ ls -A1 "/Users/hehex/Library/Containers/com.miHoYo.GenshinImpact" | grep ...
Data
```

And even `ls` command itself stops working:
```bash
$ ls -ld "/Users/hehex/..."
zsh: command not found: ls
```

### Root Cause
**zsh has a special built-in array variable called `path`** that is automatically synchronized with the `PATH` environment variable:

- `PATH` (string): `/usr/bin:/bin:/usr/sbin:/sbin`
- `path` (array): `(/usr/bin /bin /usr/sbin /sbin)`

When the script uses `local path=$1` to store a container path like `/Users/hehex/Library/Containers/...`, it **overwrites the special `path` array**, which in turn **corrupts the `PATH` environment variable**.

Result: All commands become unavailable because the shell can't find them.

### Evidence
```bash
# After sourcing script with path=$1:
$ echo $PATH
/Users/hehex/Library/Containers/com.miHoYo.GenshinImpact  # ← Wrong!

# Should be:
$ echo $PATH
/usr/bin:/bin:/usr/sbin:/sbin  # ← Correct
```

This is why:
1. `ls` command fails → "command not found"
2. All filtering logic returns empty → no commands available
3. Storage detection fails → returns "none" instead of "internal"

### Why This Wasn't Caught Earlier
- The script works fine when executed directly (not sourced)
- bash doesn't have this special `path` variable behavior
- Only affects zsh users who source the script for testing

### Fix Applied

**File: `2_playcover-volume-manager.command`**

Renamed all `path` variables to `container_path` to avoid conflict:

**1. is_on_external_volume() function (Line 296):**
```bash
# BEFORE:
is_on_external_volume() {
    local path=$1
    local storage_type=$(get_storage_type "$path")
    [[ "$storage_type" == "external" ]]
}

# AFTER:
is_on_external_volume() {
    local container_path=$1
    local storage_type=$(get_storage_type "$container_path")
    [[ "$storage_type" == "external" ]]
}
```

**2. get_storage_type() function (Line 303-368):**
```bash
# BEFORE:
get_storage_type() {
    local path=$1
    local debug=${2:-false}
    
    if [[ ! -e "$path" ]]; then
        ...
    fi
    
    local mount_check=$(/sbin/mount | /usr/bin/grep " on ${path} ")
    ...
    
    if [[ -d "$path" ]]; then
        local content_check=$(/bin/ls -A1 "$path" 2>/dev/null | ...)
        ...
    fi
    
    local device=$(/bin/df "$path" | ...)
    ...
}

# AFTER:
get_storage_type() {
    local container_path=$1
    local debug=${2:-false}
    
    if [[ ! -e "$container_path" ]]; then
        ...
    fi
    
    local mount_check=$(/sbin/mount | /usr/bin/grep " on ${container_path} ")
    ...
    
    if [[ -d "$container_path" ]]; then
        local content_check=$(/bin/ls -A1 "$container_path" 2>/dev/null | ...)
        ...
    fi
    
    local device=$(/bin/df "$container_path" | ...)
    ...
}
```

All instances of `$path` within these functions replaced with `$container_path`.

### Testing

After applying the fix:

```bash
# Source script without breaking PATH
source /Volumes/DATA/PlayCoverPortable/2_playcover-volume-manager.command

# Verify PATH is intact
echo $PATH
# Should show: /usr/bin:/bin:/usr/sbin:/sbin (not container path)

# Test storage detection
get_storage_type "/Users/hehex/Library/Containers/com.miHoYo.GenshinImpact" true

# Expected output:
[DEBUG] Content check (filtered): 'Data'
[DEBUG] Content length: 4
[DEBUG] Directory has actual content, checking disk location...
[DEBUG] Device: /dev/disk3s1, Disk ID: disk3
[DEBUG] Disk location: Internal
internal
```

### Impact
- **Critical**: Without this fix, storage detection completely fails in zsh
- **Scope**: Affects all zsh users when sourcing script for testing/debugging
- **User Impact**: 
  - Unable to detect internal storage
  - Shows "unmounted" instead of "internal storage"
  - Cannot switch from internal to external storage

### Related Files Modified
- `2_playcover-volume-manager.command` (v1.5.12)

### Version History
- v1.5.6: Fixed grep pattern matching (regex → fixed-string)
- v1.5.7: Fixed external→internal copy (remount to temp location first)
- v1.5.8: Fixed rsync error handling (accept exit codes 23/24)
- v1.5.10: Fixed ls multi-column output (ls -A → ls -A1)
- v1.5.11: Fixed ls command path (ls → /bin/ls)
- v1.5.12: **Fixed zsh path variable conflict (path → container_path)** ← Current fix

### Best Practices Learned
1. **Avoid using shell-reserved variable names**: `path`, `PATH`, `IFS`, `PS1`, etc.
2. **Use descriptive variable names**: `container_path`, `mount_point`, etc.
3. **Test in multiple shells**: bash, zsh, sh
4. **Test both execution modes**: direct execution and sourcing

### Next Steps
1. Deploy v1.5.12 to user environment
2. Verify storage detection works correctly
3. Test all storage switching operations
