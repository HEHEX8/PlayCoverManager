#!/bin/bash
#######################################################
# DMG作成 v2（正しい座標系）
# create-dmgツールの座標は「左上」基準
#######################################################

set -e

APP_NAME="PlayCover Manager"
APP_VERSION="5.0.0"
SOURCE_APP="build/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-${APP_VERSION}.dmg"
BACKGROUND_IMG="dmg-background.png"

# 画像サイズとアイコン配置（背景画像生成スクリプトと同じ計算）
WIDTH=660
HEIGHT=400
ICON_SIZE=128

# 左アイコン: 左から1/6の位置
LEFT_ICON_X=$((WIDTH / 6))
LEFT_ICON_Y=$(((HEIGHT - ICON_SIZE) / 2 - 20))

# 右アイコン: 右から1/6の位置
RIGHT_ICON_X=$((WIDTH * 5 / 6 - ICON_SIZE))
RIGHT_ICON_Y=$LEFT_ICON_Y

echo "🚀 DMGを作成中（v2）..."
echo ""
echo "📐 設定:"
echo "   ウィンドウサイズ: ${WIDTH}x${HEIGHT}"
echo "   アイコンサイズ: ${ICON_SIZE}x${ICON_SIZE}"
echo "   左アイコン位置: (${LEFT_ICON_X}, ${LEFT_ICON_Y})"
echo "   右アイコン位置: (${RIGHT_ICON_X}, ${RIGHT_ICON_Y})"
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
    echo "   先に ./create-dmg-background-v2.sh を実行してください"
    exit 1
fi

# create-dmgツールがインストールされているか確認
if ! command -v create-dmg &> /dev/null; then
    echo "📦 create-dmgツールをインストール中..."
    if command -v brew &> /dev/null; then
        brew install create-dmg
    elif command -v npm &> /dev/null; then
        npm install -g create-dmg
    else
        echo "❌ npmまたはHomebrewが必要です"
        echo ""
        echo "インストール方法:"
        echo "  Homebrew: brew install create-dmg"
        echo "  npm: npm install -g create-dmg"
        exit 1
    fi
fi

# 以前のDMGを削除
rm -f "build/${DMG_NAME}"

# create-dmgでDMGを作成
echo "📦 DMGを作成中..."
echo ""

if [ -f "AppIcon.icns" ]; then
    create-dmg \
        --volname "${APP_NAME}" \
        --volicon "AppIcon.icns" \
        --background "$BACKGROUND_IMG" \
        --window-pos 200 120 \
        --window-size $WIDTH $HEIGHT \
        --icon-size $ICON_SIZE \
        --icon "${APP_NAME}.app" $LEFT_ICON_X $LEFT_ICON_Y \
        --hide-extension "${APP_NAME}.app" \
        --app-drop-link $RIGHT_ICON_X $RIGHT_ICON_Y \
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
        --window-size $WIDTH $HEIGHT \
        --icon-size $ICON_SIZE \
        --icon "${APP_NAME}.app" $LEFT_ICON_X $LEFT_ICON_Y \
        --hide-extension "${APP_NAME}.app" \
        --app-drop-link $RIGHT_ICON_X $RIGHT_ICON_Y \
        --no-internet-enable \
        "build/${DMG_NAME}" \
        "$SOURCE_APP"
fi

echo ""
echo "✅ DMGの作成に成功しました！"
echo ""
ls -lh "build/${DMG_NAME}"
echo ""
echo "🎉 配布用DMGが準備できました！"
echo ""
echo "📦 テスト方法:"
echo "   open 'build/${DMG_NAME}'"
echo ""
echo "✨ 特徴:"
echo "   - カスタム背景画像（矢印＋説明文）"
echo "   - ボリュームアイコン自動設定"
echo "   - 正確なアイコン配置（左上座標基準）"
