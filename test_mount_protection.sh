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
    echo "Step 4: Filter macOS metadata files (v1.5.6 logic)"
    echo "  Using: grep -v -x -F '.DS_Store' | grep -v -x -F '.Spotlight-V100' ..."
    
    # Apply the same filtering as mount_volume() v1.5.6
    content_filtered=$(echo "$content" | /usr/bin/grep -v -x -F '.DS_Store' | /usr/bin/grep -v -x -F '.Spotlight-V100' | /usr/bin/grep -v -x -F '.Trashes' | /usr/bin/grep -v -x -F '.fseventsd')
    
    echo "  Filtered output: '$content_filtered'"
    echo "  Filtered length: ${#content_filtered} characters"
    
    echo ""
    echo "Step 5: Protection decision (based on filtered content)"
    if [[ -n "$content_filtered" ]]; then
        echo "  ✗ BLOCKED: Directory has actual user data"
        echo "  → Mount protection will BLOCK mounting"
        echo ""
        echo "Actual user data detected (after filtering metadata):"
        echo "$content_filtered" | while read line; do
            echo "    - $line"
        done
    else
        echo "  ✓ ALLOWED: Directory is empty or contains only metadata"
        echo "  → Mount protection will ALLOW mounting"
        echo "  → Empty directory (or metadata-only) will be deleted first"
        
        if [[ -n "$content" ]]; then
            echo ""
            echo "Metadata files that will be ignored:"
            echo "$content" | while read line; do
                echo "    - $line (filtered out)"
            done
        fi
    fi
else
    echo "  ✓ IS a mount point (external storage)"
    echo "  Mount info: $mount_check"
    echo ""
    echo "Result: No protection needed (already mounted as external)"
fi

echo ""
echo "========================================="
