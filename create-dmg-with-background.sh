#!/bin/bash
#######################################################
# 背景画像付きDMG作成（create-dmgツール使用）
# カスタム背景画像で矢印とテキストを表示
#######################################################

set -e

APP_NAME="PlayCover Manager"
APP_VERSION="5.0.0"
SOURCE_APP="build/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-${APP_VERSION}.dmg"
BACKGROUND_IMG="dmg-background.png"

echo "🚀 背景画像付きDMGを作成中..."
echo ""

# アプリの存在確認
if [ ! -d "$SOURCE_APP" ]; then
    echo "❌ アプリが見つかりません: $SOURCE_APP"
    echo "   先に ./build-app.sh を実行してください"
    exit 1
fi

# 背景画像の存在確認
if [ ! -f "$BACKGROUND_IMG" ]; then
    echo "❌ 背景画像が見つかりません: $BACKGROUND_IMG"
    echo "   先に ./create-dmg-background.sh を実行してください"
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
        echo "  npm: npm install -g create-dmg"
        echo "  Homebrew: brew install create-dmg"
        exit 1
    fi
fi

# 以前のDMGを削除
rm -f "build/${DMG_NAME}"

# create-dmgで背景画像付きDMGを作成
echo "📦 DMGを作成中..."
echo ""

# アイコン位置は背景画像に合わせて調整
# 背景画像: 660x400
# アプリアイコン: x=160 (左側)
# Applicationsフォルダ: x=500 (右側)
# y=185 (両方とも中央より少し上)

if [ -f "AppIcon.icns" ]; then
    create-dmg \
        --volname "${APP_NAME}" \
        --volicon "AppIcon.icns" \
        --background "$BACKGROUND_IMG" \
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
    echo "   ボリュームアイコンは設定されません"
    echo ""
    
    create-dmg \
        --volname "${APP_NAME}" \
        --background "$BACKGROUND_IMG" \
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
echo "✅ 背景画像付きDMGの作成に成功しました！"
echo ""
ls -lh "build/${DMG_NAME}"
echo ""
echo "🎉 配布用の完璧なDMGが準備できました！"
echo ""
echo "📦 テスト方法:"
echo "   open 'build/${DMG_NAME}'"
echo ""
echo "✨ 特徴:"
echo "   - カスタム背景画像（矢印＋説明文）"
echo "   - ボリュームアイコン自動設定"
echo "   - ドラッグ&ドロップレイアウト"
