#!/bin/bash
#######################################################
# Create DMG with AppleScript for precise control
# Most reliable method for custom DMG layout
#######################################################

set -e

APP_NAME="PlayCover Manager"
APP_VERSION="5.0.0"
SOURCE_APP="build/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-${APP_VERSION}.dmg"
VOLUME_NAME="${APP_NAME}"
DMG_TEMP_DIR="build/dmg_temp"
DMG_SIZE="100m"

echo "🚀 Creating DMG with AppleScript..."
echo ""

# Check if app exists
if [ ! -d "$SOURCE_APP" ]; then
    echo "❌ App not found: $SOURCE_APP"
    echo "   Run ./build-app.sh first"
    exit 1
fi

# Clean previous builds
rm -rf "${DMG_TEMP_DIR}"
rm -f "build/${DMG_NAME}"

# Create temporary directory
mkdir -p "${DMG_TEMP_DIR}"

# Copy app
echo "📦 Copying app to temporary directory..."
cp -R "$SOURCE_APP" "${DMG_TEMP_DIR}/"

# Create Applications symlink
echo "🔗 Creating Applications symlink..."
ln -s /Applications "${DMG_TEMP_DIR}/Applications"

# Copy app icon as volume icon
if [ -f "${SOURCE_APP}/Contents/Resources/AppIcon.icns" ]; then
    cp "${SOURCE_APP}/Contents/Resources/AppIcon.icns" "${DMG_TEMP_DIR}/.VolumeIcon.icns"
fi

# Create initial DMG
echo "🔨 Creating initial DMG..."
hdiutil create -volname "${VOLUME_NAME}" \
    -srcfolder "${DMG_TEMP_DIR}" \
    -ov -format UDRW \
    -size ${DMG_SIZE} \
    "build/temp.dmg"

# Mount DMG
echo "💾 Mounting DMG..."
MOUNT_DIR=$(hdiutil attach -readwrite -noverify -noautoopen "build/temp.dmg" | egrep '^/dev/' | sed 1q | awk '{print $3}')

echo "📍 Mounted at: $MOUNT_DIR"

# Wait for mount
sleep 2

# Set custom icon for volume
if [ -f "$MOUNT_DIR/.VolumeIcon.icns" ]; then
    /usr/bin/SetFile -a C "$MOUNT_DIR"
fi

# Configure Finder view with AppleScript
echo "🎨 Configuring Finder view..."
osascript <<EOF
tell application "Finder"
    tell disk "${VOLUME_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 860, 520}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set background color of viewOptions to {11264, 15872, 20480}
        set position of item "${APP_NAME}.app" of container window to {180, 180}
        set position of item "Applications" of container window to {480, 180}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF

# Hide invisible files
echo "🧹 Hiding invisible files..."
/usr/bin/SetFile -a V "$MOUNT_DIR/.VolumeIcon.icns" 2>/dev/null || true
/usr/bin/SetFile -a V "$MOUNT_DIR/.DS_Store" 2>/dev/null || true
/usr/bin/SetFile -a V "$MOUNT_DIR/.fseventsd" 2>/dev/null || true
/usr/bin/SetFile -a V "$MOUNT_DIR/.Trashes" 2>/dev/null || true

# Sync
sync

# Wait before unmounting
sleep 2

# Unmount
echo "💿 Unmounting..."
hdiutil detach "$MOUNT_DIR"

# Convert to compressed final DMG
echo "📦 Creating final compressed DMG..."
hdiutil convert "build/temp.dmg" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "build/${DMG_NAME}"

# Clean up
rm -f "build/temp.dmg"
rm -rf "${DMG_TEMP_DIR}"

echo ""
echo "✅ DMG created successfully!"
echo ""
ls -lh "build/${DMG_NAME}"
echo ""
echo "🎉 Perfect DMG ready for distribution!"
echo ""
echo "📦 To test:"
echo "   open 'build/${DMG_NAME}'"
