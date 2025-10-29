#!/bin/bash
#######################################################
# Create DMG background image
# This creates a background for the DMG installer
#######################################################

set -e

OUTPUT_FILE="dmg-background.png"
WIDTH=660
HEIGHT=450

echo "🎨 Creating DMG background image..."

# Check if ImageMagick is available
if ! command -v convert >/dev/null 2>&1; then
    echo "❌ ImageMagick not found"
    echo "   Install with: brew install imagemagick"
    exit 1
fi

# Create gradient background with text
convert -size ${WIDTH}x${HEIGHT} \
    gradient:'#E8F4F8-#B8DCE8' \
    -gravity center \
    -pointsize 24 \
    -fill '#2c3e50' \
    -annotate +0-100 'PlayCover Manager' \
    -pointsize 14 \
    -fill '#5a6c7d' \
    -annotate +0-60 'APFSボリューム管理ツール' \
    -annotate +0+150 'アプリを Applications フォルダにドラッグしてください' \
    "${OUTPUT_FILE}"

if [ -f "${OUTPUT_FILE}" ]; then
    echo "✅ Background image created: ${OUTPUT_FILE}"
    ls -lh "${OUTPUT_FILE}"
else
    echo "❌ Failed to create background image"
    exit 1
fi

echo ""
echo "📦 This image will be used in the DMG installer"
