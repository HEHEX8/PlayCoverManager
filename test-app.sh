#!/bin/bash
#######################################################
# Test the built application
# Run this on macOS after building
#######################################################

APP_PATH="build/PlayCover Manager.app"

echo "🧪 Testing PlayCover Manager.app..."
echo ""

# Check if app exists
if [ ! -d "$APP_PATH" ]; then
    echo "❌ App not found: $APP_PATH"
    echo "   Run ./build-app.sh first"
    exit 1
fi

echo "✅ App bundle exists"
echo ""

# Check structure
echo "📁 Checking bundle structure..."
if [ -f "$APP_PATH/Contents/Info.plist" ]; then
    echo "  ✅ Info.plist"
else
    echo "  ❌ Info.plist missing"
fi

if [ -f "$APP_PATH/Contents/MacOS/PlayCoverManager" ]; then
    echo "  ✅ Executable"
    
    # Check if executable
    if [ -x "$APP_PATH/Contents/MacOS/PlayCoverManager" ]; then
        echo "     ✅ Has execute permission"
    else
        echo "     ❌ No execute permission"
    fi
else
    echo "  ❌ Executable missing"
fi

if [ -f "$APP_PATH/Contents/Resources/main-script.sh" ]; then
    echo "  ✅ Main script"
else
    echo "  ❌ Main script missing"
fi

if [ -d "$APP_PATH/Contents/Resources/lib" ]; then
    echo "  ✅ Library modules"
    MODULE_COUNT=$(ls -1 "$APP_PATH/Contents/Resources/lib"/*.sh 2>/dev/null | wc -l)
    echo "     📚 $MODULE_COUNT modules found"
else
    echo "  ❌ Library modules missing"
fi

if [ -f "$APP_PATH/Contents/Resources/AppIcon.icns" ]; then
    echo "  ✅ App icon"
else
    echo "  ⚠️  No app icon (optional)"
fi

echo ""
echo "🔍 Info.plist details:"
/usr/libexec/PlistBuddy -c "Print :CFBundleName" "$APP_PATH/Contents/Info.plist" 2>/dev/null && echo "  Bundle Name: $(defaults read "$PWD/$APP_PATH/Contents/Info" CFBundleName 2>/dev/null)"
/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP_PATH/Contents/Info.plist" 2>/dev/null && echo "  Version: $(defaults read "$PWD/$APP_PATH/Contents/Info" CFBundleVersion 2>/dev/null)"
/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP_PATH/Contents/Info.plist" 2>/dev/null && echo "  Bundle ID: $(defaults read "$PWD/$APP_PATH/Contents/Info" CFBundleIdentifier 2>/dev/null)"

echo ""
echo "🚀 Launch test..."
echo "   Option 1: open '$APP_PATH'"
echo "   Option 2: Double-click the app in Finder"
echo ""
echo "Would you like to launch the app now? (y/n)"
read -r response

if [[ "$response" =~ ^[Yy]$ ]]; then
    echo "🚀 Launching app..."
    open "$APP_PATH"
    echo "✅ App launched"
    echo "   Check if Terminal window opens"
else
    echo "ℹ️  Skipped launch test"
fi

echo ""
echo "✨ Testing complete!"
