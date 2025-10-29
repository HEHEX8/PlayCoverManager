#!/bin/bash
#######################################################
# create-dmg ツールを使用した最新のDMG作成方法
# 業界標準のNode.jsツールを使用
#######################################################

set -e

APP_NAME="PlayCover Manager"
APP_VERSION="5.0.0"
SOURCE_APP="build/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-${APP_VERSION}.dmg"

echo "🚀 create-dmgツールでDMGを作成中..."
echo ""

# アプリの存在確認
if [ ! -d "$SOURCE_APP" ]; then
    echo "❌ アプリが見つかりません: $SOURCE_APP"
    echo "   先に ./build-app.sh を実行してください"
    exit 1
fi

# create-dmgツールがインストールされているか確認
if ! command -v create-dmg &> /dev/null; then
    echo "📦 create-dmgツールをインストール中..."
    if command -v npm &> /dev/null; then
        npm install -g create-dmg
    elif command -v brew &> /dev/null; then
        brew install create-dmg
    else
        echo "❌ npmまたはHomebrewが必要です"
        echo ""
        echo "インストール方法:"
        echo "  Homebrew: brew install node"
        echo "  または: brew install create-dmg"
        exit 1
    fi
fi

# GraphicsMagickがインストールされているか確認（ボリュームアイコン自動生成用）
if ! command -v gm &> /dev/null; then
    echo "⚠️  GraphicsMagickが見つかりません"
    echo "   ボリュームアイコンの自動生成には必要です"
    echo "   インストール: brew install graphicsmagick"
    echo ""
    echo "   スキップして続行します..."
fi

# 以前のDMGを削除
rm -f "build/${DMG_NAME}"

# create-dmgで作成
echo "📦 DMGを作成中..."
echo ""

# アプリアイコンをコピー（ボリュームアイコンとして使用）
if [ -f "AppIcon.icns" ]; then
    # create-dmgは --icon-size, --window-size, --icon-pos, --app-drop-link などのオプションをサポート
    create-dmg \
        --volname "${APP_NAME}" \
        --volicon "AppIcon.icns" \
        --window-pos 200 120 \
        --window-size 660 400 \
        --icon-size 128 \
        --icon "${APP_NAME}.app" 160 185 \
        --hide-extension "${APP_NAME}.app" \
        --app-drop-link 500 185 \
        --no-internet-enable \
        "build/${DMG_NAME}" \
        "$SOURCE_APP"
else
    echo "⚠️  AppIcon.icnsが見つかりません"
    echo "   ./create-icon.sh を実行してアイコンを作成してください"
    echo ""
    
    # アイコンなしで作成
    create-dmg \
        --volname "${APP_NAME}" \
        --window-pos 200 120 \
        --window-size 660 400 \
        --icon-size 128 \
        --icon "${APP_NAME}.app" 160 185 \
        --hide-extension "${APP_NAME}.app" \
        --app-drop-link 500 185 \
        --no-internet-enable \
        "build/${DMG_NAME}" \
        "$SOURCE_APP"
fi

echo ""
echo "✅ DMGの作成に成功しました！"
echo ""
ls -lh "build/${DMG_NAME}"
echo ""
echo "🎉 配布用の完璧なDMGが準備できました！"
echo ""
echo "📦 テスト方法:"
echo "   open 'build/${DMG_NAME}'"
echo ""
echo "📝 注意:"
echo "   - ボリュームアイコンは自動的に設定されます"
echo "   - 背景画像を追加する場合は --background オプションを使用"
echo "   - コード署名する場合は --codesign オプションを使用"
