#!/bin/bash
#######################################################
# PlayCover Manager - Application Builder
# Creates a distributable macOS .app bundle
#######################################################

set -e

APP_NAME="PlayCover Manager"
APP_VERSION="5.0.0"
BUNDLE_ID="com.playcover.manager"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"

echo "🚀 Building ${APP_NAME} v${APP_VERSION}..."
echo ""

# Clean previous build
if [ -d "${BUILD_DIR}" ]; then
    echo "🧹 Cleaning previous build..."
    rm -rf "${BUILD_DIR}"
fi

# Create .app bundle structure
echo "📦 Creating .app bundle structure..."
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"
mkdir -p "${APP_BUNDLE}/Contents/Resources/lib"

# Copy main script to Resources
echo "📝 Copying main script..."
cp main.sh "${APP_BUNDLE}/Contents/Resources/main-script.sh"
chmod +x "${APP_BUNDLE}/Contents/Resources/main-script.sh"

# Copy all library modules
echo "📚 Copying library modules..."
cp -r lib/* "${APP_BUNDLE}/Contents/Resources/lib/"

# Update SCRIPT_DIR in main script to use Resources
echo "🔧 Updating script paths..."
# Update SCRIPT_DIR only (keep zsh shebang)
sed -i.bak 's|SCRIPT_DIR="${0:A:h}"|SCRIPT_DIR="$(cd "$(dirname "$0")" \&\& pwd)"|' "${APP_BUNDLE}/Contents/Resources/main-script.sh"
rm -f "${APP_BUNDLE}/Contents/Resources/main-script.sh.bak"

# Create launcher script in MacOS directory
echo "🚀 Creating launcher script..."
cat > "${APP_BUNDLE}/Contents/MacOS/PlayCoverManager" << 'LAUNCHER_EOF'
#!/bin/zsh
#######################################################
# PlayCover Manager - Launcher
# Opens Terminal and runs the main script with zsh
#######################################################

# Get the Resources directory
RESOURCES_DIR="$(cd "$(dirname "$0")/../Resources" && pwd)"
MAIN_SCRIPT="${RESOURCES_DIR}/main-script.sh"

# Check if main script exists
if [ ! -f "$MAIN_SCRIPT" ]; then
    osascript -e 'display dialog "PlayCover Manager script not found!" buttons {"OK"} default button 1 with icon stop'
    exit 1
fi

# Launch in Terminal with zsh
osascript <<EOF
tell application "Terminal"
    activate
    do script "clear && cd '$RESOURCES_DIR' && /bin/zsh '$MAIN_SCRIPT'"
end tell
EOF

LAUNCHER_EOF

chmod +x "${APP_BUNDLE}/Contents/MacOS/PlayCoverManager"

# Copy app icon if available
if [ -f "AppIcon.icns" ]; then
    echo "🎨 Adding app icon..."
    cp AppIcon.icns "${APP_BUNDLE}/Contents/Resources/"
    ICON_KEY='    <key>CFBundleIconFile</key>
    <string>AppIcon</string>'
else
    echo "ℹ️  No AppIcon.icns found (run ./create-icon.sh on macOS to create)"
    ICON_KEY=""
fi

# Create Info.plist
echo "📄 Creating Info.plist..."
cat > "${APP_BUNDLE}/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>ja_JP</string>
    <key>CFBundleExecutable</key>
    <string>PlayCoverManager</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${APP_VERSION}</string>
${ICON_KEY}
    <key>LSMinimumSystemVersion</key>
    <string>15.1</string>
    <key>LSArchitecturePriority</key>
    <array>
        <string>arm64</string>
    </array>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2024. All rights reserved.</string>
    <key>LSUIElement</key>
    <false/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

# Create app icon (optional - using SF Symbols as placeholder)
echo "🎨 Creating app icon..."
# This creates a simple icon placeholder
# For a real icon, you would use iconutil to create an .icns file
cat > "${APP_BUNDLE}/Contents/Resources/AppIcon.iconset.txt" << EOF
# To create a proper icon:
# 1. Create AppIcon.iconset directory with PNG files
# 2. Run: iconutil -c icns AppIcon.iconset
# 3. Move AppIcon.icns to Contents/Resources/
EOF

# Create README inside the app
echo "📖 Creating bundled README..."
cat > "${APP_BUNDLE}/Contents/Resources/README.txt" << EOF
PlayCover Manager v${APP_VERSION}
================================

APFS Volume Management Tool for PlayCover

Features:
- App volume management (create, mount, unmount)
- Batch operations for multiple apps
- Storage location switching (internal/external)
- Disk eject with safety checks
- Automatic mapping file management

Requirements:
- macOS Sequoia 15.1 or later
- Apple Silicon Mac
- PlayCover installed

Usage:
Double-click "PlayCover Manager.app" to launch the tool.

License: MIT
Repository: https://github.com/HEHEX8/PlayCoverManager
EOF

# Copy documentation
echo "📚 Copying documentation..."
if [ -f "README.md" ]; then
    cp README.md "${APP_BUNDLE}/Contents/Resources/"
fi
if [ -f "README-EN.md" ]; then
    cp README-EN.md "${APP_BUNDLE}/Contents/Resources/"
fi
if [ -f "RELEASE_NOTES_5.0.0.md" ]; then
    cp RELEASE_NOTES_5.0.0.md "${APP_BUNDLE}/Contents/Resources/"
fi

# Note about DMG creation
echo ""
echo "ℹ️  Basic app bundle created"
echo "   For professional DMG with custom layout, run on macOS:"
echo "   ./create-installer-dmg.sh"

# Create ZIP for distribution
echo ""
echo "📦 Creating distributable ZIP..."
ZIP_NAME="${APP_NAME}-${APP_VERSION}.zip"
cd "${BUILD_DIR}"
zip -r -q "${ZIP_NAME}" "${APP_NAME}.app"
cd ..

echo ""
echo "✅ Build complete!"
echo ""
echo "📁 Output files:"
echo "   • App Bundle: ${APP_BUNDLE}"
if [ -f "${DMG_PATH}" ]; then
    echo "   • DMG: ${DMG_PATH}"
fi
echo "   • ZIP: ${BUILD_DIR}/${ZIP_NAME}"
echo ""
echo "🚀 Distribution ready!"
echo ""
echo "📦 To distribute:"
echo "   1. Share the .zip file for easy download"
echo "   2. Or share the .dmg file for traditional installer"
echo "   3. Users can drag the app to Applications folder"
echo ""
echo "🔐 Note: On first launch, users may need to:"
echo "   • Right-click → Open (to bypass Gatekeeper)"
echo "   • Grant Terminal permissions in System Settings"
echo ""
