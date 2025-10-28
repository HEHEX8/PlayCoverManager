#!/bin/bash
#######################################################
# Debug icon generation issues
# Run this on macOS to diagnose the problem
#######################################################

echo "🔍 Debugging icon generation..."
echo ""

# Check source image
if [ -f "app-icon.png" ]; then
    echo "✅ Source image exists: app-icon.png"
    file app-icon.png
    ls -lh app-icon.png
    
    # Check if it's actually a JPEG
    if file app-icon.png | grep -q "JPEG"; then
        echo "⚠️  WARNING: File is JPEG but has .png extension"
        echo "   Converting to proper PNG..."
        sips -s format png app-icon.png --out app-icon-fixed.png
        if [ -f "app-icon-fixed.png" ]; then
            echo "✅ Created app-icon-fixed.png (proper PNG format)"
            mv app-icon.png app-icon.png.bak
            mv app-icon-fixed.png app-icon.png
            echo "✅ Replaced app-icon.png with proper PNG"
        fi
    fi
else
    echo "❌ Source image not found: app-icon.png"
    exit 1
fi

echo ""

# Check if AppIcon.iconset exists
if [ -d "AppIcon.iconset" ]; then
    echo "✅ AppIcon.iconset directory exists"
    echo ""
    echo "📁 Contents of AppIcon.iconset:"
    ls -lh AppIcon.iconset/
    echo ""
    echo "🔍 Checking each icon file:"
    CORRUPT_COUNT=0
    for icon in AppIcon.iconset/*.png; do
        if [ -f "$icon" ]; then
            FILE_INFO=$(file "$icon")
            echo "  $(basename "$icon"):"
            echo "    $FILE_INFO"
            
            # Check if it's a valid PNG
            if ! echo "$FILE_INFO" | grep -q "PNG image data"; then
                echo "    ❌ NOT A VALID PNG!"
                CORRUPT_COUNT=$((CORRUPT_COUNT + 1))
            fi
            
            # Check dimensions
            DIMS=$(sips -g pixelWidth -g pixelHeight "$icon" 2>/dev/null | tail -2 | awk '{print $2}' | tr '\n' 'x' | sed 's/x$//')
            if [ -n "$DIMS" ]; then
                echo "    📐 Dimensions: $DIMS"
            fi
        fi
    done
    
    if [ $CORRUPT_COUNT -gt 0 ]; then
        echo ""
        echo "❌ Found $CORRUPT_COUNT corrupted/invalid PNG files"
        echo "   These need to be regenerated"
    fi
else
    echo "❌ AppIcon.iconset directory not found"
    echo "   Run ./create-icon.sh first"
    exit 1
fi

echo ""
echo "🧪 Testing iconutil..."
iconutil --version 2>&1 || echo "iconutil command available"

echo ""
echo "🔧 Attempting manual conversion..."
OUTPUT=$(iconutil -c icns AppIcon.iconset -o AppIcon-test.icns 2>&1)
EXIT_CODE=$?

echo "$OUTPUT"

if [ $EXIT_CODE -eq 0 ] && [ -f "AppIcon-test.icns" ]; then
    echo ""
    echo "✅ AppIcon-test.icns created successfully!"
    ls -lh AppIcon-test.icns
    file AppIcon-test.icns
    echo ""
    echo "💡 The iconset is valid. You can use AppIcon-test.icns"
    echo "   Or rename it: mv AppIcon-test.icns AppIcon.icns"
else
    echo ""
    echo "❌ Failed to create .icns"
    echo ""
    echo "💡 Troubleshooting steps:"
    echo "   1. Check if all PNG files are valid (see above)"
    echo "   2. Ensure file names match exactly (case-sensitive):"
    echo "      icon_16x16.png, icon_16x16@2x.png, etc."
    echo "   3. Try deleting AppIcon.iconset and running ./create-icon.sh again"
    echo "   4. Make sure app-icon.png is a proper PNG (not JPEG with .png extension)"
fi
