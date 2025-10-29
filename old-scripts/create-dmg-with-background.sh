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

# アイコン位置を背景画像に合わせて計算
# 背景画像: 660x400
# アイコンサイズ: 128x128
# 
# 計算式（背景画像スクリプトと同じ）:
#   左アイコン: width/4 - icon_size/2 = 660/4 - 64 = 101
#   右アイコン: width*3/4 - icon_size/2 = 495 - 64 = 431
#   Y位置: (height - icon_size)/2 - 30 = 136/2 - 30 = 106
LEFT_ICON_X=101
RIGHT_ICON_X=431
ICON_Y=106

echo "📐 アイコン配置座標:"
echo "   左アイコン: ($LEFT_ICON_X, $ICON_Y)"
echo "   右アイコン: ($RIGHT_ICON_X, $ICON_Y)"
echo ""

if [ -f "AppIcon.icns" ]; then
    create-dmg \
        --volname "${APP_NAME}" \
        --volicon "AppIcon.icns" \
        --background "$BACKGROUND_IMG" \
        --window-pos 200 120 \
        --window-size 660 400 \
        --icon-size 128 \
        --icon "${APP_NAME}.app" $LEFT_ICON_X $ICON_Y \
        --hide-extension "${APP_NAME}.app" \
        --app-drop-link $RIGHT_ICON_X $ICON_Y \
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
        --icon "${APP_NAME}.app" $LEFT_ICON_X $ICON_Y \
        --hide-extension "${APP_NAME}.app" \
        --app-drop-link $RIGHT_ICON_X $ICON_Y \
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
