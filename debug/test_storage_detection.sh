#!/bin/bash

# Test the storage detection logic
test_path="/Users/hehex/Library/Containers/com.HoYoverse.hkrpgoversea"

echo "Testing storage detection for: $test_path"
echo ""

# Simulate the get_storage_type function logic
echo "1. Check if path exists:"
if [[ -e "$test_path" ]]; then
    echo "   ✓ Path exists"
else
    echo "   ✗ Path does not exist"
    exit 1
fi

echo ""
echo "2. Check if path is a mount point:"
mount_check=$(mount | grep " on ${test_path} ")
if [[ -n "$mount_check" ]]; then
    echo "   ✓ Is a mount point (external)"
    echo "   Mount info: $mount_check"
else
    echo "   ✗ Not a mount point"
fi

echo ""
echo "3. Check if directory has content:"
if [[ -d "$test_path" ]]; then
    content=$(ls -A "$test_path" 2>/dev/null)
    if [[ -z "$content" ]]; then
        echo "   ✗ Directory is EMPTY"
        echo "   Result: none (アンマウント済み)"
    else
        echo "   ✓ Directory has content:"
        ls -la "$test_path" 2>/dev/null | head -5
        echo "   Result: Should be 'internal' (内蔵ストレージ)"
    fi
else
    echo "   ✗ Not a directory"
fi

echo ""
echo "4. Check actual content:"
if [[ -d "$test_path/com.HoYoverse.hkrpgoversea" ]]; then
    echo "   ✓ Found subdirectory: com.HoYoverse.hkrpgoversea"
    echo "   This indicates internal storage data exists"
fi
