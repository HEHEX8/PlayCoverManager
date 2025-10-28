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

sips -z 16 16     "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_16x16.png" > /dev/null 2>&1
sips -z 32 32     "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_16x16@2x.png" > /dev/null 2>&1
sips -z 32 32     "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_32x32.png" > /dev/null 2>&1
sips -z 64 64     "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_32x32@2x.png" > /dev/null 2>&1
sips -z 128 128   "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_128x128.png" > /dev/null 2>&1
sips -z 256 256   "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_128x128@2x.png" > /dev/null 2>&1
sips -z 256 256   "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_256x256.png" > /dev/null 2>&1
sips -z 512 512   "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_256x256@2x.png" > /dev/null 2>&1
sips -z 512 512   "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_512x512.png" > /dev/null 2>&1
sips -z 1024 1024 "$SOURCE_IMAGE" --out "$ICONSET_DIR/icon_512x512@2x.png" > /dev/null 2>&1

echo "✅ Generated 10 icon sizes"

# Convert to .icns
echo "🎨 Converting to .icns format..."
iconutil -c icns "$ICONSET_DIR" -o AppIcon.icns

if [ -f "AppIcon.icns" ]; then
    echo "✅ AppIcon.icns created successfully!"
    echo ""
    echo "📦 Next steps:"
    echo "   1. Run ./build-app.sh to rebuild the app with the new icon"
    echo "   2. The icon will be automatically included in the app bundle"
    echo ""
    ls -lh AppIcon.icns
else
    echo "❌ Failed to create AppIcon.icns"
    exit 1
fi

# Clean up iconset directory (optional)
# rm -rf "$ICONSET_DIR"

echo ""
echo "✨ Done!"
