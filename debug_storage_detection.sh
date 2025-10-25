#!/bin/zsh

# Debug script for storage detection issue
# Usage: ./debug_storage_detection.sh "/Users/hehex/Library/Containers/com.HoYoverse.hkrpgoversea"

test_path="$1"

if [[ -z "$test_path" ]]; then
    echo "Usage: $0 <path>"
    echo "Example: $0 \"/Users/hehex/Library/Containers/com.HoYoverse.hkrpgoversea\""
    exit 1
fi

echo "========================================="
echo "Storage Detection Debug Script"
echo "========================================="
echo ""
echo "Testing path: $test_path"
echo ""

# Test 1: Path existence
echo "Test 1: Path existence"
if [[ -e "$test_path" ]]; then
    echo "  ✓ Path exists"
else
    echo "  ✗ Path does NOT exist"
    exit 1
fi
echo ""

# Test 2: Is it a directory?
echo "Test 2: Directory check"
if [[ -d "$test_path" ]]; then
    echo "  ✓ Is a directory"
else
    echo "  ✗ NOT a directory"
    exit 1
fi
echo ""

# Test 3: Mount point check
echo "Test 3: Mount point check"
mount_check=$(/sbin/mount | /usr/bin/grep " on ${test_path} ")
if [[ -n "$mount_check" ]]; then
    echo "  ✓ IS a mount point (external storage)"
    echo "  Mount info: $mount_check"
    if [[ "$mount_check" =~ "apfs" ]]; then
        echo "  ✓ APFS volume detected"
        echo ""
        echo "Result: EXTERNAL STORAGE 🔌"
        exit 0
    fi
else
    echo "  ✗ NOT a mount point"
fi
echo ""

# Test 4: Content check with ls -A
echo "Test 4: Content check (ls -A)"
content=$(ls -A "$test_path" 2>/dev/null)
echo "  Raw output: '$content'"
echo "  Length: ${#content}"

if [[ -z "$content" ]]; then
    echo "  ✗ Directory is EMPTY"
    echo ""
    echo "Result: NONE (アンマウント済み) ⚪"
    exit 0
else
    echo "  ✓ Directory has content"
    echo ""
    echo "  Content list:"
    ls -la "$test_path" | head -10
fi
echo ""

# Test 5: Device and disk location
echo "Test 5: Device and disk location"
device=$(/bin/df "$test_path" | /usr/bin/tail -1 | /usr/bin/awk '{print $1}')
echo "  Device: $device"

disk_id=$(echo "$device" | /usr/bin/sed -E 's|/dev/(disk[0-9]+).*|\1|')
echo "  Disk ID: $disk_id"

disk_location=$(diskutil info "/dev/$disk_id" 2>/dev/null | /usr/bin/grep "Device Location:" | /usr/bin/awk -F: '{print $2}' | /usr/bin/sed 's/^ *//')
echo "  Disk Location: $disk_location"
echo ""

# Final result
if [[ "$disk_location" == "Internal" ]]; then
    echo "Result: INTERNAL STORAGE 💾"
elif [[ "$disk_location" == "External" ]]; then
    echo "Result: EXTERNAL STORAGE 🔌"
else
    echo "Fallback check..."
    if [[ "$disk_id" == "disk0" ]] || [[ "$disk_id" == "disk1" ]] || [[ "$disk_id" == "disk3" ]]; then
        echo "Result: INTERNAL STORAGE 💾 (fallback - system disk)"
    else
        echo "Result: EXTERNAL STORAGE 🔌 (fallback - non-system disk)"
    fi
fi
echo ""
echo "========================================="
