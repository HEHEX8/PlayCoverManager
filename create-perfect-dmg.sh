#!/bin/bash
#######################################################
# Create perfect DMG installer with clean layout
# No visible dot files, perfect icon placement
#######################################################

set -e

APP_NAME="PlayCover Manager"
APP_VERSION="5.0.0"
SOURCE_APP="build/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-${APP_VERSION}.dmg"
VOLUME_NAME="${APP_NAME}"
TEMP_DMG="build/temp.dmg"

echo "🚀 Creating perfect DMG installer..."
echo ""

# Check if app exists
if [ ! -d "$SOURCE_APP" ]; then
    echo "❌ App not found: $SOURCE_APP"
    echo "   Run ./build-app.sh first"
    exit 1
fi

# Clean previous DMG
rm -f "build/${DMG_NAME}" "${TEMP_DMG}"

# Check for required tools
if ! command -v create-dmg >/dev/null 2>&1; then
    echo "❌ create-dmg not found"
    echo "   Install with: brew install create-dmg"
    exit 1
fi

# Create DMG with perfect layout
echo "🎨 Creating DMG with optimized layout..."
create-dmg \
  --volname "${VOLUME_NAME}" \
  --volicon "${SOURCE_APP}/Contents/Resources/AppIcon.icns" \
  --background-color "#2c3e50" \
  --window-pos 200 120 \
  --window-size 660 400 \
  --icon-size 128 \
  --icon "${APP_NAME}.app" 180 180 \
  --hide-extension "${APP_NAME}.app" \
  --app-drop-link 480 180 \
  --no-internet-enable \
  --skip-jenkins \
  --hdiutil-quiet \
  "build/${DMG_NAME}" \
  "$SOURCE_APP" 2>&1 | grep -v ".*deprecated.*" || true

if [ ! -f "build/${DMG_NAME}" ]; then
    echo ""
    echo "❌ Failed to create DMG"
    exit 1
fi

echo ""
echo "🧹 Cleaning up and finalizing..."

# Mount DMG to clean up
MOUNT_POINT=$(hdiutil attach "build/${DMG_NAME}" -nobrowse -noverify | grep "/Volumes/${VOLUME_NAME}" | awk '{print $3}')

if [ -n "$MOUNT_POINT" ]; then
    echo "📝 Mounted at: $MOUNT_POINT"
    
    # Wait a moment for mount to complete
    sleep 2
    
    # Hide all invisible files
    for file in "$MOUNT_POINT"/.* ; do
        if [ -f "$file" ]; then
            /usr/bin/SetFile -a V "$file" 2>/dev/null || true
        fi
    done
    
    # Set custom icon
    if [ -f "$MOUNT_POINT/.VolumeIcon.icns" ]; then
        /usr/bin/SetFile -a C "$MOUNT_POINT" 2>/dev/null || true
    fi
    
    # Force sync
    sync
    
    # Wait before unmounting
    sleep 1
    
    # Unmount
    hdiutil detach "$MOUNT_POINT" -force 2>/dev/null || true
    
    echo "✅ Cleanup complete"
fi

echo ""
echo "✅ Perfect DMG created successfully!"
echo ""
ls -lh "build/${DMG_NAME}"
echo ""
echo "🎉 Ready for distribution!"
echo ""
echo "📦 To test:"
echo "   open build/${DMG_NAME}"
