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

# Try multiple methods to get mount point
MOUNT_OUTPUT=$(hdiutil attach -readwrite -noverify -noautoopen "build/temp.dmg" 2>&1)
echo "🔍 Mount output:"
echo "$MOUNT_OUTPUT"
echo ""

# Method 1: Look for /Volumes path in output
MOUNT_DIR=$(echo "$MOUNT_OUTPUT" | grep -o '/Volumes/[^[:space:]]*' | head -1)

# Method 2: If not found, use volume name directly
if [ -z "$MOUNT_DIR" ]; then
    MOUNT_DIR="/Volumes/${VOLUME_NAME}"
    echo "⚠️  Using default path: $MOUNT_DIR"
fi

# Method 3: If still not found, check all mounted volumes
if [ ! -d "$MOUNT_DIR" ]; then
    echo "⚠️  Checking all mounted volumes..."
    ls -la /Volumes/
    
    # Try to find the volume
    for vol in /Volumes/*; do
        if [[ "$vol" == *"PlayCover"* ]]; then
            MOUNT_DIR="$vol"
            echo "✅ Found volume: $MOUNT_DIR"
            break
        fi
    done
fi

echo "📍 Mounted at: $MOUNT_DIR"

# Validate mount point
if [ -z "$MOUNT_DIR" ]; then
    echo "❌ Failed to find mount point"
    echo "   Please check /Volumes/ manually"
    ls -la /Volumes/
    exit 1
fi

if [ ! -d "$MOUNT_DIR" ]; then
    echo "❌ Mount directory does not exist: $MOUNT_DIR"
    echo "   Available volumes:"
    ls -la /Volumes/
    exit 1
fi

echo "✅ Mount point validated"
echo "📂 Contents:"
ls -la "$MOUNT_DIR/"
echo ""

# Verify Applications symlink exists
if [ ! -e "$MOUNT_DIR/Applications" ]; then
    echo "❌ Applications symlink not found in mounted volume"
    echo "   Creating it now..."
    ln -sf /Applications "$MOUNT_DIR/Applications"
fi

# Wait for Finder to recognize the mount
sleep 3

# Set custom icon for volume (MUST be done before Finder opens the window)
if [ -f "$MOUNT_DIR/.VolumeIcon.icns" ]; then
    echo "🎨 Setting volume icon..."
    /usr/bin/SetFile -a C "$MOUNT_DIR"
    # Also ensure the icon file itself is hidden
    /usr/bin/SetFile -a V "$MOUNT_DIR/.VolumeIcon.icns"
fi

# Hide .fseventsd immediately after mount
if [ -d "$MOUNT_DIR/.fseventsd" ]; then
    echo "🧹 Hiding .fseventsd..."
    chflags hidden "$MOUNT_DIR/.fseventsd" 2>/dev/null || \
    /usr/bin/SetFile -a V "$MOUNT_DIR/.fseventsd" 2>/dev/null || \
    echo "⚠️  Could not hide .fseventsd"
fi

# Configure Finder view with AppleScript
echo "🎨 Configuring Finder view..."

# First, ensure Finder sees the volume
osascript -e "tell application \"Finder\" to update disk \"${VOLUME_NAME}\" without registering applications"
sleep 2

# Now configure the view
osascript <<EOF
tell application "Finder"
    tell disk "${VOLUME_NAME}"
        open
        delay 3
        
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 860, 520}
        
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        -- Light gray background (easier to read)
        set background color of viewOptions to {52428, 54227, 55769}
        set text size of viewOptions to 12
        set label position of viewOptions to bottom
        
        delay 2
        
        -- Position items (centered in 660px width window)
        try
            set position of item "${APP_NAME}.app" of container window to {160, 200}
        on error errMsg
            log "Warning: Could not position app - " & errMsg
        end try
        
        try
            set position of item "Applications" of container window to {500, 200}
        on error errMsg
            log "Warning: Could not position Applications - " & errMsg
        end try
        
        delay 2
        close
        delay 1
        open
        
        update without registering applications
        delay 3
    end tell
end tell
EOF

echo "✅ Finder view configured"

# Final cleanup - hide all system files
echo "🧹 Final cleanup..."
# .VolumeIcon.icns should already be hidden, but double-check
[ -f "$MOUNT_DIR/.VolumeIcon.icns" ] && /usr/bin/SetFile -a V "$MOUNT_DIR/.VolumeIcon.icns" 2>/dev/null
# Hide .DS_Store if it exists
[ -f "$MOUNT_DIR/.DS_Store" ] && /usr/bin/SetFile -a V "$MOUNT_DIR/.DS_Store" 2>/dev/null
# Hide .fseventsd using both methods
if [ -d "$MOUNT_DIR/.fseventsd" ]; then
    chflags hidden "$MOUNT_DIR/.fseventsd" 2>/dev/null
    /usr/bin/SetFile -a V "$MOUNT_DIR/.fseventsd" 2>/dev/null
fi
# Hide .Trashes if it exists
[ -d "$MOUNT_DIR/.Trashes" ] && /usr/bin/SetFile -a V "$MOUNT_DIR/.Trashes" 2>/dev/null

echo "✅ All system files hidden"

# Sync changes
echo "💾 Syncing changes..."
sync
sync

# Wait for changes to be written
sleep 3

# Unmount (WITHOUT -force to avoid ejecting other volumes)
echo "💿 Unmounting..."
if [ -n "$MOUNT_DIR" ] && [ -d "$MOUNT_DIR" ]; then
    # Close any Finder windows for this volume
    osascript -e "tell application \"Finder\" to close window \"${VOLUME_NAME}\"" 2>/dev/null || true
    sleep 1
    
    # Unmount gracefully (no -force flag)
    hdiutil detach "$MOUNT_DIR" || {
        echo "⚠️  First unmount attempt failed, trying with -force..."
        sleep 2
        # Only use -force as last resort and be more specific
        DEVICE=$(hdiutil info | grep "$MOUNT_DIR" | awk '{print $1}')
        if [ -n "$DEVICE" ]; then
            hdiutil detach "$DEVICE" -force || echo "⚠️  Could not unmount, may need manual intervention"
        fi
    }
else
    echo "⚠️  No valid mount point to unmount"
fi

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
