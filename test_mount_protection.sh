#!/bin/zsh

# Test mount protection logic
# Usage: ./test_mount_protection.sh "/Users/hehex/Library/Containers/com.HoYoverse.hkrpgoversea"

test_path="$1"

if [[ -z "$test_path" ]]; then
    echo "Usage: $0 <path>"
    echo "Example: $0 \"/Users/hehex/Library/Containers/com.HoYoverse.hkrpgoversea\""
    exit 1
fi

echo "========================================="
echo "Mount Protection Logic Debug"
echo "========================================="
echo ""
echo "Testing path: $test_path"
echo ""

# Simulate mount_volume() protection logic
echo "Step 1: Check if directory exists"
if [[ -d "$test_path" ]]; then
    echo "  ✓ Directory exists"
else
    echo "  ✗ Directory does NOT exist"
    echo ""
    echo "Result: No protection needed (directory will be created)"
    exit 0
fi
echo ""

echo "Step 2: Check if it's a mount point"
mount_check=$(/sbin/mount | /usr/bin/grep " on ${test_path} ")
if [[ -z "$mount_check" ]]; then
    echo "  ✓ NOT a mount point"
    echo ""
    echo "Step 3: Check directory content (ls -A)"
    
    # Show exact ls -A output
    echo "  Command: ls -A \"$test_path\""
    content=$(ls -A "$test_path" 2>/dev/null)
    echo "  Raw output: '$content'"
    echo "  Output length: ${#content} characters"
    echo "  Output bytes: $(echo -n "$content" | wc -c | xargs)"
    
    # Show detailed listing
    echo ""
    echo "  Detailed listing (ls -la):"
    ls -la "$test_path" 2>/dev/null
    
    echo ""
    echo "Step 4: Protection decision"
    if [[ -n "$content" ]]; then
        echo "  ✗ BLOCKED: Directory has content"
        echo "  → Mount protection will BLOCK mounting"
        echo ""
        echo "Content detected:"
        echo "$content" | while read line; do
            echo "    - $line"
        done
    else
        echo "  ✓ ALLOWED: Directory is empty"
        echo "  → Mount protection will ALLOW mounting"
        echo "  → Empty directory will be deleted first"
    fi
else
    echo "  ✓ IS a mount point (external storage)"
    echo "  Mount info: $mount_check"
    echo ""
    echo "Result: No protection needed (already mounted as external)"
fi

echo ""
echo "========================================="
