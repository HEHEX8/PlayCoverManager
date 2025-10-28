#!/bin/bash
#######################################################
# Create macOS .icns icon from source image
# This script should be run on macOS
#######################################################

set -e

SOURCE_IMAGE="app-icon.png"
ICONSET_DIR="AppIcon.iconset"

if [ ! -f "$SOURCE_IMAGE" ]; then
    echo "❌ Error: $SOURCE_IMAGE not found"
    exit 1
fi

echo "🎨 Creating macOS icon from $SOURCE_IMAGE..."
echo ""

# Check source image format
IMAGE_FORMAT=$(file "$SOURCE_IMAGE" | grep -o "PNG\|JPEG")
echo "📋 Detected format: $IMAGE_FORMAT"

# If JPEG, convert to PNG first
if [[ "$IMAGE_FORMAT" == "JPEG" ]]; then
    echo "🔄 Converting JPEG to PNG format..."
    TEMP_PNG="app-icon-converted.png"
    sips -s format png "$SOURCE_IMAGE" --out "$TEMP_PNG" > /dev/null 2>&1
    if [ -f "$TEMP_PNG" ]; then
        SOURCE_IMAGE="$TEMP_PNG"
        echo "✅ Converted to PNG: $SOURCE_IMAGE"
    else
        echo "❌ Failed to convert to PNG"
        exit 1
    fi
fi

echo ""

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "⚠️  Warning: This script should be run on macOS"
    echo "   The icon will be added to the build, but .icns conversion requires macOS"
    echo ""
    echo "📋 To create .icns on macOS:"
    echo "   1. Create AppIcon.iconset directory"
    echo "   2. Generate required sizes with sips:"
    echo "      sips -z 16 16     $SOURCE_IMAGE --out AppIcon.iconset/icon_16x16.png"
    echo "      sips -z 32 32     $SOURCE_IMAGE --out AppIcon.iconset/icon_16x16@2x.png"
    echo "      sips -z 32 32     $SOURCE_IMAGE --out AppIcon.iconset/icon_32x32.png"
    echo "      sips -z 64 64     $SOURCE_IMAGE --out AppIcon.iconset/icon_32x32@2x.png"
    echo "      sips -z 128 128   $SOURCE_IMAGE --out AppIcon.iconset/icon_128x128.png"
    echo "      sips -z 256 256   $SOURCE_IMAGE --out AppIcon.iconset/icon_128x128@2x.png"
    echo "      sips -z 256 256   $SOURCE_IMAGE --out AppIcon.iconset/icon_256x256.png"
    echo "      sips -z 512 512   $SOURCE_IMAGE --out AppIcon.iconset/icon_256x256@2x.png"
    echo "      sips -z 512 512   $SOURCE_IMAGE --out AppIcon.iconset/icon_512x512.png"
    echo "      sips -z 1024 1024 $SOURCE_IMAGE --out AppIcon.iconset/icon_512x512@2x.png"
    echo "   3. Convert to .icns:"
    echo "      iconutil -c icns AppIcon.iconset"
    echo ""
    exit 0
fi

# Create iconset directory
echo "📁 Creating $ICONSET_DIR directory..."
rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

# Generate all required icon sizes
echo "🔧 Generating icon sizes..."

# Array of sizes to generate
declare -a SIZES=(
    "16:icon_16x16.png"
    "32:icon_16x16@2x.png"
    "32:icon_32x32.png"
    "64:icon_32x32@2x.png"
    "128:icon_128x128.png"
    "256:icon_128x128@2x.png"
    "256:icon_256x256.png"
    "512:icon_256x256@2x.png"
    "512:icon_512x512.png"
    "1024:icon_512x512@2x.png"
)

FAILED=0
for size_info in "${SIZES[@]}"; do
    SIZE="${size_info%%:*}"
    NAME="${size_info##*:}"
    
    if ! sips -z "$SIZE" "$SIZE" "$SOURCE_IMAGE" --out "$ICONSET_DIR/$NAME" > /dev/null 2>&1; then
        echo "⚠️  Failed to generate $NAME"
        FAILED=$((FAILED + 1))
    fi
done

if [ $FAILED -gt 0 ]; then
    echo "❌ Failed to generate $FAILED icon sizes"
    echo "🔍 Run ./debug-icon.sh for more details"
    exit 1
fi

echo "✅ Generated 10 icon sizes"

# Verify all files exist and are valid PNGs
echo "🔍 Verifying generated icons..."
for size_info in "${SIZES[@]}"; do
    NAME="${size_info##*:}"
    if [ ! -f "$ICONSET_DIR/$NAME" ]; then
        echo "❌ Missing: $NAME"
        exit 1
    fi
    if ! file "$ICONSET_DIR/$NAME" | grep -q "PNG image data"; then
        echo "❌ Invalid PNG: $NAME"
        exit 1
    fi
done
echo "✅ All icons verified"

# Convert to .icns
echo "🎨 Converting to .icns format..."
if iconutil -c icns "$ICONSET_DIR" -o AppIcon.icns 2>&1; then
    if [ -f "AppIcon.icns" ]; then
        echo "✅ AppIcon.icns created successfully!"
        echo ""
        echo "📦 Next steps:"
        echo "   1. Run ./build-app.sh to rebuild the app with the new icon"
        echo "   2. The icon will be automatically included in the app bundle"
        echo ""
        ls -lh AppIcon.icns
        file AppIcon.icns
    else
        echo "❌ Failed to create AppIcon.icns (file not found)"
        echo "🔍 Run ./debug-icon.sh for more details"
        exit 1
    fi
else
    echo "❌ iconutil command failed"
    echo "🔍 Checking AppIcon.iconset contents..."
    ls -la "$ICONSET_DIR/"
    echo ""
    echo "💡 Possible issues:"
    echo "   1. One or more PNG files may be corrupted"
    echo "   2. Incorrect file naming in iconset"
    echo "   3. Run ./debug-icon.sh for detailed diagnostics"
    exit 1
fi

# Clean up iconset directory (optional)
# rm -rf "$ICONSET_DIR"

# Clean up temporary converted PNG if it was created
if [ -f "app-icon-converted.png" ]; then
    rm -f "app-icon-converted.png"
    echo "🧹 Cleaned up temporary files"
fi

echo ""
echo "✨ Done!"
