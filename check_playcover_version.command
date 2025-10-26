#!/bin/zsh

echo "=== PlayCover バージョン情報 ==="
echo ""

# PlayCoverのバージョン
echo "【PlayCover バージョン】"
if [[ -f "/Applications/PlayCover.app/Contents/Info.plist" ]]; then
    plutil -p /Applications/PlayCover.app/Contents/Info.plist | grep -E "CFBundleShortVersionString|CFBundleVersion"
else
    echo "❌ PlayCover.app が見つかりません"
fi

echo ""
echo "【PlayTools Framework】"
if [[ -f "/Applications/PlayCover.app/Contents/Frameworks/PlayTools.framework/Versions/A/Resources/Info.plist" ]]; then
    plutil -p /Applications/PlayCover.app/Contents/Frameworks/PlayTools.framework/Versions/A/Resources/Info.plist | grep -E "CFBundleShortVersionString|CFBundleVersion"
else
    echo "❌ PlayTools.framework が見つかりません"
fi

echo ""
echo "【macOS バージョン】"
sw_vers

echo ""
echo "【原神アプリの状態】"
GENSHIN_APP="${HOME}/Library/Containers/io.playcover.PlayCover/Applications/原神.app"
if [[ -d "$GENSHIN_APP" ]]; then
    echo "✅ アプリ存在: $GENSHIN_APP"
    echo "   Info.plist:"
    if [[ -f "$GENSHIN_APP/Contents/Info.plist" ]]; then
        plutil -p "$GENSHIN_APP/Contents/Info.plist" | grep -E "CFBundleIdentifier|CFBundleShortVersionString"
    fi
else
    echo "❌ 原神アプリが見つかりません"
fi

echo ""
echo "=== 完了 ==="
