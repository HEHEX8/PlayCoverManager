#!/bin/bash
#######################################################
# AppleScriptを使用した高精度DMG作成
# プロフェッショナルなDMGレイアウトに最適な方法
#######################################################

set -e

APP_NAME="PlayCover Manager"
APP_VERSION="5.0.0"
SOURCE_APP="build/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-${APP_VERSION}.dmg"
VOLUME_NAME="${APP_NAME}"
DMG_TEMP_DIR="build/dmg_temp"
DMG_SIZE="100m"

echo "🚀 AppleScriptでDMGを作成中..."
echo ""

# アプリの存在確認
if [ ! -d "$SOURCE_APP" ]; then
    echo "❌ アプリが見つかりません: $SOURCE_APP"
    echo "   先に ./build-app.sh を実行してください"
    exit 1
fi

# 以前のビルドをクリーンアップ
rm -rf "${DMG_TEMP_DIR}"
rm -f "build/${DMG_NAME}"

# 一時ディレクトリを作成
mkdir -p "${DMG_TEMP_DIR}"

# アプリをコピー
echo "📦 一時ディレクトリにアプリをコピー中..."
cp -R "$SOURCE_APP" "${DMG_TEMP_DIR}/"

# Applicationsシンボリックリンクを作成
echo "🔗 Applicationsシンボリックリンクを作成中..."
ln -s /Applications "${DMG_TEMP_DIR}/Applications"

# アプリアイコンをボリュームアイコンとしてコピー
if [ -f "${SOURCE_APP}/Contents/Resources/AppIcon.icns" ]; then
    cp "${SOURCE_APP}/Contents/Resources/AppIcon.icns" "${DMG_TEMP_DIR}/.VolumeIcon.icns"
fi

# 初期DMGを作成
echo "🔨 初期DMGを作成中..."
hdiutil create -volname "${VOLUME_NAME}" \
    -srcfolder "${DMG_TEMP_DIR}" \
    -ov -format UDRW \
    -size ${DMG_SIZE} \
    "build/temp.dmg"

# DMGをマウント
echo "💾 DMGをマウント中..."

# マウントポイント取得のため複数の方法を試行
MOUNT_OUTPUT=$(hdiutil attach -readwrite -noverify -noautoopen "build/temp.dmg" 2>&1)
echo "🔍 マウント出力:"
echo "$MOUNT_OUTPUT"
echo ""

# 方法1: 出力から /Volumes パスを抽出
MOUNT_DIR=$(echo "$MOUNT_OUTPUT" | grep -o '/Volumes/[^[:space:]]*' | head -1)

# 方法2: 見つからない場合、ボリューム名を直接使用
if [ -z "$MOUNT_DIR" ]; then
    MOUNT_DIR="/Volumes/${VOLUME_NAME}"
    echo "⚠️  デフォルトパスを使用: $MOUNT_DIR"
fi

# 方法3: それでも見つからない場合、マウント済みボリュームを全て確認
if [ ! -d "$MOUNT_DIR" ]; then
    echo "⚠️  マウント済みボリュームを確認中..."
    ls -la /Volumes/
    
    # ボリュームを検索
    for vol in /Volumes/*; do
        if [[ "$vol" == *"PlayCover"* ]]; then
            MOUNT_DIR="$vol"
            echo "✅ ボリュームを発見: $MOUNT_DIR"
            break
        fi
    done
fi

echo "📍 マウント先: $MOUNT_DIR"

# マウントポイントを検証
if [ -z "$MOUNT_DIR" ]; then
    echo "❌ マウントポイントの取得に失敗しました"
    echo "   /Volumes/ を手動で確認してください"
    ls -la /Volumes/
    exit 1
fi

if [ ! -d "$MOUNT_DIR" ]; then
    echo "❌ マウントディレクトリが存在しません: $MOUNT_DIR"
    echo "   利用可能なボリューム:"
    ls -la /Volumes/
    exit 1
fi

echo "✅ マウントポイントを検証しました"
echo "📂 内容:"
ls -la "$MOUNT_DIR/"
echo ""

# Applicationsシンボリックリンクの存在確認
if [ ! -e "$MOUNT_DIR/Applications" ]; then
    echo "❌ マウントされたボリュームにApplicationsシンボリックリンクが見つかりません"
    echo "   作成中..."
    ln -sf /Applications "$MOUNT_DIR/Applications"
fi

# Finderがマウントを認識するまで待機
sleep 3

# ボリュームアイコンを設定（重要：ファイルを隠す前にCustom Iconビットを設定）
if [ -f "$MOUNT_DIR/.VolumeIcon.icns" ]; then
    echo "🎨 ボリュームアイコンを設定中..."
    # ステップ1：ボリュームにCustom Iconビットを設定（アイコンファイル自体ではない）
    /usr/bin/SetFile -a C "$MOUNT_DIR"
    # ステップ2：アイコンファイルをまだ非表示にしない（Finderが最初に見る必要がある）
    sleep 1
fi

# 画面外配置用の隠しプレースホルダーファイルを作成
# これらは表示ウィンドウ領域外に配置される
echo "📝 隠しファイルプレースホルダーを作成中..."
touch "$MOUNT_DIR/.background" 2>/dev/null || true
touch "$MOUNT_DIR/.VolumeIcon" 2>/dev/null || true

# AppleScriptでFinderビューを設定
echo "🎨 Finderビューを設定中..."

# まず、Finderがボリュームを認識していることを確認
osascript -e "tell application \"Finder\" to update disk \"${VOLUME_NAME}\" without registering applications"
sleep 2

# ビューを設定
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
        -- ライトグレー背景（読みやすい）
        set background color of viewOptions to {52428, 54227, 55769}
        set text size of viewOptions to 12
        set label position of viewOptions to bottom
        
        delay 2
        
        -- 表示アイテムを配置（660pxウィンドウ幅で中央揃え）
        try
            set position of item "${APP_NAME}.app" of container window to {160, 200}
        on error errMsg
            log "警告: アプリの配置に失敗 - " & errMsg
        end try
        
        try
            set position of item "Applications" of container window to {500, 200}
        on error errMsg
            log "警告: Applicationsの配置に失敗 - " & errMsg
        end try
        
        delay 1
        
        -- 隠しファイルを画面外に移動（表示領域の下）
        -- ウィンドウの高さは400pxなので、y=1000は完全に画面外
        try
            set position of item ".VolumeIcon.icns" of container window to {100, 1000}
        on error
            -- ファイルが存在しないか、既に隠されている
        end try
        
        try
            set position of item ".background" of container window to {200, 1000}
        on error
            -- ファイルが存在しない可能性
        end try
        
        try
            set position of item ".fseventsd" of container window to {300, 1000}
        on error
            -- ファイルが存在しない可能性
        end try
        
        try
            set position of item ".VolumeIcon" of container window to {400, 1000}
        on error
            -- ファイルが存在しない可能性
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

echo "✅ Finderビューを設定しました"

# 最終クリーンアップとアイコン確認
echo "🧹 最終クリーンアップ中..."

# 重要：ボリュームアイコンが設定されているか再確認（レイアウト後に必要な場合がある）
if [ -f "$MOUNT_DIR/.VolumeIcon.icns" ]; then
    echo "🎨 ボリュームアイコンを確認中（最終パス）..."
    /usr/bin/SetFile -a C "$MOUNT_DIR"
    # Cフラグを設定した後、アイコンファイルを隠す
    /usr/bin/SetFile -a V "$MOUNT_DIR/.VolumeIcon.icns" 2>/dev/null
fi

# .DS_Storeが存在する場合は隠す
[ -f "$MOUNT_DIR/.DS_Store" ] && /usr/bin/SetFile -a V "$MOUNT_DIR/.DS_Store" 2>/dev/null

# プレースホルダーファイルを隠す
[ -f "$MOUNT_DIR/.background" ] && /usr/bin/SetFile -a V "$MOUNT_DIR/.background" 2>/dev/null
[ -f "$MOUNT_DIR/.VolumeIcon" ] && /usr/bin/SetFile -a V "$MOUNT_DIR/.VolumeIcon" 2>/dev/null

# .fseventsdを隠す（既に画面外に配置済みだが、念のため隠す）
if [ -d "$MOUNT_DIR/.fseventsd" ]; then
    chflags hidden "$MOUNT_DIR/.fseventsd" 2>/dev/null
    /usr/bin/SetFile -a V "$MOUNT_DIR/.fseventsd" 2>/dev/null
fi

# .Trashesが存在する場合は隠す
[ -d "$MOUNT_DIR/.Trashes" ] && /usr/bin/SetFile -a V "$MOUNT_DIR/.Trashes" 2>/dev/null

# ボリュームアイコンが設定されているか検証
echo "🔍 ボリュームアイコンを検証中..."
if /usr/bin/GetFileInfo -aE "$MOUNT_DIR" | grep -q "hasCustomIcon" 2>/dev/null; then
    echo "✅ ボリュームアイコンを確認しました"
else
    echo "⚠️  ボリュームアイコンが正しく設定されていない可能性があります"
fi

echo "✅ 全てのシステムファイルを画面外に配置または非表示にしました"

# 変更を同期
echo "💾 変更を同期中..."
sync
sync

# 変更が書き込まれるまで待機
sleep 3

# アンマウント（他のボリュームを誤って取り出さないよう-forceは使用しない）
echo "💿 アンマウント中..."
if [ -n "$MOUNT_DIR" ] && [ -d "$MOUNT_DIR" ]; then
    # このボリュームのFinderウィンドウを閉じる
    osascript -e "tell application \"Finder\" to close window \"${VOLUME_NAME}\"" 2>/dev/null || true
    sleep 1
    
    # 通常のアンマウント（-forceフラグなし）
    hdiutil detach "$MOUNT_DIR" || {
        echo "⚠️  最初のアンマウント試行が失敗しました。-forceで再試行中..."
        sleep 2
        # 最終手段としてのみ-forceを使用し、より具体的にする
        DEVICE=$(hdiutil info | grep "$MOUNT_DIR" | awk '{print $1}')
        if [ -n "$DEVICE" ]; then
            hdiutil detach "$DEVICE" -force || echo "⚠️  アンマウントできませんでした。手動での対応が必要な可能性があります"
        fi
    }
else
    echo "⚠️  アンマウントする有効なマウントポイントがありません"
fi

# 最終的な圧縮DMGに変換
echo "📦 最終的な圧縮DMGを作成中..."
hdiutil convert "build/temp.dmg" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "build/${DMG_NAME}"

# クリーンアップ
rm -f "build/temp.dmg"
rm -rf "${DMG_TEMP_DIR}"

echo ""
echo "✅ DMGの作成に成功しました！"
echo ""
ls -lh "build/${DMG_NAME}"
echo ""
echo "🎉 配布用の完璧なDMGが準備できました！"
echo ""
echo "📦 テスト方法:"
echo "   open 'build/${DMG_NAME}'"
