#!/bin/bash
#######################################################
# Create professional DMG installer with custom layout
# Based on create-dmg tool
#######################################################

set -e

APP_NAME="PlayCover Manager"
APP_VERSION="5.0.0"
SOURCE_APP="build/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-${APP_VERSION}.dmg"
VOLUME_NAME="${APP_NAME}"

echo "🚀 Creating professional DMG installer..."
echo ""

# Check if app exists
if [ ! -d "$SOURCE_APP" ]; then
    echo "❌ App not found: $SOURCE_APP"
    echo "   Run ./build-app.sh first"
    exit 1
fi

# Check for create-dmg tool
if ! command -v create-dmg >/dev/null 2>&1; then
    echo "📦 Installing create-dmg..."
    if command -v brew >/dev/null 2>&1; then
        brew install create-dmg
    else
        echo "❌ Homebrew not found. Install create-dmg manually:"
        echo "   brew install create-dmg"
        exit 1
    fi
fi

# Clean previous DMG
rm -f "build/${DMG_NAME}"

# Create DMG with custom layout
echo "🎨 Creating DMG with custom layout..."
create-dmg \
  --volname "${VOLUME_NAME}" \
  --volicon "${SOURCE_APP}/Contents/Resources/AppIcon.icns" \
  --window-pos 200 120 \
  --window-size 660 450 \
  --icon-size 128 \
  --icon "${APP_NAME}.app" 180 200 \
  --hide-extension "${APP_NAME}.app" \
  --app-drop-link 480 200 \
  --no-internet-enable \
  --skip-jenkins \
  "build/${DMG_NAME}" \
  "$SOURCE_APP"

echo ""
echo "🧹 Cleaning up temporary files in DMG..."
# Mount the DMG to clean up
hdiutil attach "build/${DMG_NAME}" -mountpoint /Volumes/temp_mount 2>/dev/null
if [ -d "/Volumes/temp_mount" ]; then
    # Hide .VolumeIcon.icns and other dot files
    /usr/bin/SetFile -a V /Volumes/temp_mount/.VolumeIcon.icns 2>/dev/null || true
    /usr/bin/SetFile -a V /Volumes/temp_mount/.fseventsd 2>/dev/null || true
    /usr/bin/SetFile -a V /Volumes/temp_mount/.DS_Store 2>/dev/null || true
    
    # Detach
    hdiutil detach /Volumes/temp_mount 2>/dev/null
fi

if [ -f "build/${DMG_NAME}" ]; then
    echo ""
    echo "✅ DMG created successfully!"
    echo ""
    ls -lh "build/${DMG_NAME}"
    echo ""
    echo "🎉 Professional installer ready for distribution!"
else
    echo ""
    echo "❌ Failed to create DMG"
    exit 1
fi
