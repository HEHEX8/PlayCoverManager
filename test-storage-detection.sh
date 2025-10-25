#!/bin/bash

# Test script for storage type detection
# Usage: ./test-storage-detection.sh <path>

test_path="${1:-$HOME/Library/Containers/com.HoYoverse.Nap}"

echo "=== Storage Type Detection Test ==="
echo "Testing path: $test_path"
echo ""

# Check if path exists
if [[ ! -e "$test_path" ]]; then
    echo "❌ Path does not exist"
    exit 1
fi

echo "✅ Path exists"
echo ""

# Check if it's a mount point
echo "--- Mount Check ---"
mount_check=$(/sbin/mount | /usr/bin/grep " on ${test_path} ")
if [[ -n "$mount_check" ]]; then
    echo "✅ IS A MOUNT POINT"
    echo "$mount_check"
    if [[ "$mount_check" =~ "apfs" ]]; then
        echo "→ APFS volume detected"
        echo "→ Result: EXTERNAL STORAGE"
    fi
else
    echo "⭕ NOT A MOUNT POINT (regular directory)"
    echo "→ Checking parent filesystem..."
fi

echo ""
echo "--- Device Info ---"
device=$(/bin/df "$test_path" | /usr/bin/tail -1 | /usr/bin/awk '{print $1}')
echo "Device: $device"

disk_id=$(echo "$device" | /usr/bin/sed -E 's|/dev/(disk[0-9]+).*|\1|')
echo "Disk ID: $disk_id"

echo ""
echo "--- Disk Location ---"
disk_location=$(diskutil info "/dev/$disk_id" 2>/dev/null | /usr/bin/grep "Device Location:" | /usr/bin/awk -F: '{print $2}' | /usr/bin/sed 's/^ *//')
echo "Device Location: $disk_location"

if [[ "$disk_location" == "Internal" ]]; then
    echo "→ Result: INTERNAL STORAGE"
elif [[ "$disk_location" == "External" ]]; then
    echo "→ Result: EXTERNAL STORAGE"
else
    echo "Device Location not found, using fallback..."
    if [[ "$disk_id" == "disk0" ]] || [[ "$disk_id" == "disk1" ]] || [[ "$disk_id" == "disk3" ]]; then
        echo "→ Result: INTERNAL STORAGE (fallback: $disk_id)"
    else
        echo "→ Result: EXTERNAL STORAGE (fallback: $disk_id)"
    fi
fi

echo ""
echo "=== Summary ==="
if [[ -n "$mount_check" ]] && [[ "$mount_check" =~ "apfs" ]]; then
    echo "Final Result: 🔌 EXTERNAL (mounted APFS volume)"
elif [[ "$disk_location" == "Internal" ]] || [[ "$disk_id" == "disk0" ]] || [[ "$disk_id" == "disk1" ]] || [[ "$disk_id" == "disk3" ]]; then
    echo "Final Result: 💾 INTERNAL (regular directory on internal disk)"
else
    echo "Final Result: 🔌 EXTERNAL"
fi
