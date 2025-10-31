#!/bin/bash
#######################################################
# PlayCover Manager - アプリケーションビルダー
# 配布可能なmacOS .appバンドルを作成
#######################################################

set -e

APP_NAME="PlayCover Manager"
APP_VERSION="5.2.0"
BUNDLE_ID="com.playcover.manager"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"

echo "🚀 ${APP_NAME} v${APP_VERSION} をビルド中..."
echo ""

# 以前のビルドをクリーンアップ
if [ -d "${BUILD_DIR}" ]; then
    echo "🧹 以前のビルドをクリーンアップ中..."
    rm -rf "${BUILD_DIR}"
fi

# .appバンドル構造を作成
echo "📦 .appバンドル構造を作成中..."
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"
mkdir -p "${APP_BUNDLE}/Contents/Resources/lib"

# メインスクリプトをResourcesにコピー
echo "📝 メインスクリプトをコピー中..."
cp main.sh "${APP_BUNDLE}/Contents/Resources/main-script.sh"
chmod +x "${APP_BUNDLE}/Contents/Resources/main-script.sh"

# 全てのライブラリモジュールをコピー
echo "📚 ライブラリモジュールをコピー中..."
cp -r lib/* "${APP_BUNDLE}/Contents/Resources/lib/"

# メインスクリプトのSCRIPT_DIRをResourcesを使うように更新
echo "🔧 スクリプトパスを更新中..."
# SCRIPT_DIRのみ更新（zsh shebangは保持）
sed -i.bak 's|SCRIPT_DIR="${0:A:h}"|SCRIPT_DIR="$(cd "$(dirname "$0")" \&\& pwd)"|' "${APP_BUNDLE}/Contents/Resources/main-script.sh"
rm -f "${APP_BUNDLE}/Contents/Resources/main-script.sh.bak"

# MacOSディレクトリにランチャースクリプトを作成
echo "🚀 ランチャースクリプトを作成中..."
cat > "${APP_BUNDLE}/Contents/MacOS/PlayCoverManager" << 'LAUNCHER_EOF'
#!/bin/bash
#######################################################
# PlayCover Manager - App Launcher
# Opens a NEW Terminal window (never reuses existing windows)
#######################################################

# エラーログ設定
LOG_FILE="${TMPDIR:-/tmp}/playcover-manager-launcher.log"
exec 2>> "$LOG_FILE"

# デバッグ情報をログに記録
echo "=== PlayCover Manager Launcher ===" >> "$LOG_FILE"
echo "Date: $(date)" >> "$LOG_FILE"
echo "PWD: $(pwd)" >> "$LOG_FILE"
echo "Launcher: $0" >> "$LOG_FILE"

# Resourcesディレクトリを取得
RESOURCES_DIR="$(cd "$(dirname "$0")/../Resources" && pwd)"
MAIN_SCRIPT="${RESOURCES_DIR}/main-script.sh"

echo "Resources: $RESOURCES_DIR" >> "$LOG_FILE"
echo "Main Script: $MAIN_SCRIPT" >> "$LOG_FILE"

# メインスクリプトの存在確認
if [ ! -f "$MAIN_SCRIPT" ]; then
    echo "ERROR: Main script not found!" >> "$LOG_FILE"
    osascript -e 'display dialog "PlayCover Managerスクリプトが見つかりません！\n\nログ: '"$LOG_FILE"'" buttons {"OK"} default button 1 with icon stop'
    exit 1
fi

echo "Main script found, launching..." >> "$LOG_FILE"

# Create a wrapper script that sets the window title
WRAPPER_SCRIPT="${TMPDIR:-/tmp}/playcover-manager-wrapper-$$.sh"
cat > "$WRAPPER_SCRIPT" << WRAPPER
#!/bin/zsh
# Set window title
printf '\\033]0;PlayCover Manager\\007'
# Change to resources directory
cd '$RESOURCES_DIR'
# Execute main script
exec /bin/zsh '$MAIN_SCRIPT'
WRAPPER
chmod +x "$WRAPPER_SCRIPT"

echo "Wrapper script created: $WRAPPER_SCRIPT" >> "$LOG_FILE"

# Open in a NEW Terminal window using -n flag (new instance)
# This ALWAYS creates a new window, never reuses existing ones
if /usr/bin/open -n -a Terminal.app "$WRAPPER_SCRIPT" >> "$LOG_FILE" 2>&1; then
    echo "Launch successful" >> "$LOG_FILE"
else
    echo "ERROR: open command failed!" >> "$LOG_FILE"
    osascript -e 'display dialog "Terminalの起動に失敗しました\n\nログ: '"$LOG_FILE"'" buttons {"OK"} default button 1 with icon stop'
    rm -f "$WRAPPER_SCRIPT"
    exit 1
fi

# Clean up wrapper script after a delay (in background)
(sleep 2; rm -f "$WRAPPER_SCRIPT") &

LAUNCHER_EOF

chmod +x "${APP_BUNDLE}/Contents/MacOS/PlayCoverManager"

# アプリアイコンが利用可能な場合はコピー
if [ -f "AppIcon.icns" ]; then
    echo "🎨 アプリアイコンを追加中..."
    cp AppIcon.icns "${APP_BUNDLE}/Contents/Resources/"
    ICON_KEY='    <key>CFBundleIconFile</key>
    <string>AppIcon</string>'
else
    echo "ℹ️  AppIcon.icnsが見つかりません（macOSで ./create-icon.sh を実行して作成してください）"
    ICON_KEY=""
fi

# Info.plistを作成
echo "📄 Info.plistを作成中..."
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

# アプリアイコンを作成（オプション - SF Symbolsをプレースホルダーとして使用）
echo "🎨 アプリアイコンを作成中..."
# これはシンプルなアイコンプレースホルダーを作成します
# 実際のアイコンには、iconutilを使用して.icnsファイルを作成します
cat > "${APP_BUNDLE}/Contents/Resources/AppIcon.iconset.txt" << EOF
# To create a proper icon:
# 1. Create AppIcon.iconset directory with PNG files
# 2. Run: iconutil -c icns AppIcon.iconset
# 3. Move AppIcon.icns to Contents/Resources/
EOF

# アプリ内にREADMEを作成
echo "📖 バンドルされたREADMEを作成中..."
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

# ドキュメントをコピー
echo "📚 ドキュメントをコピー中..."
if [ -f "README.md" ]; then
    cp README.md "${APP_BUNDLE}/Contents/Resources/"
fi
if [ -f "README-EN.md" ]; then
    cp README-EN.md "${APP_BUNDLE}/Contents/Resources/"
fi
if [ -f "RELEASE_NOTES_5.0.0.md" ]; then
    cp RELEASE_NOTES_5.0.0.md "${APP_BUNDLE}/Contents/Resources/"
fi

# DMG作成についての注意
echo ""
echo "ℹ️  基本的なアプリバンドルを作成しました"
echo "   カスタムレイアウトのプロフェッショナルなDMGには、macOSで以下を実行:"
echo "   ./create-installer-dmg.sh"

# 配布用のZIPを作成
echo ""
echo "📦 配布用のZIPを作成中..."
ZIP_NAME="${APP_NAME}-${APP_VERSION}.zip"
cd "${BUILD_DIR}"
zip -r -q "${ZIP_NAME}" "${APP_NAME}.app"
cd ..

echo ""
echo "✅ ビルド完了！"
echo ""
echo "📁 出力ファイル:"
echo "   • アプリバンドル: ${APP_BUNDLE}"
if [ -f "${DMG_PATH}" ]; then
    echo "   • DMG: ${DMG_PATH}"
fi
echo "   • ZIP: ${BUILD_DIR}/${ZIP_NAME}"
echo ""
echo "🚀 配布準備完了！"
echo ""
echo "📦 配布方法:"
echo "   1. 簡単なダウンロードには.zipファイルを共有"
echo "   2. または従来のインストーラーには.dmgファイルを共有"
echo "   3. ユーザーはアプリをApplicationsフォルダにドラッグできます"
echo ""
echo "🔐 注意：初回起動時、ユーザーは以下が必要な場合があります:"
echo "   • 右クリック → 開く（Gatekeeperをバイパス）"
echo "   • システム設定でTerminal権限を付与"
echo ""
