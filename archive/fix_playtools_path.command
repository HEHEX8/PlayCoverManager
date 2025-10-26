#!/bin/zsh

echo "=== PlayTools.framework パス修正 ==="
echo ""

# PlayCover内のPlayTools.frameworkのパス
SOURCE_PLAYTOOLS="/Applications/PlayCover.app/Contents/Frameworks/PlayTools.framework"

# ユーザーのLibrary/Frameworksにコピーする先
TARGET_FRAMEWORKS="${HOME}/Library/Frameworks"
TARGET_PLAYTOOLS="${TARGET_FRAMEWORKS}/PlayTools.framework"

echo "【1. PlayTools.frameworkの存在確認】"
echo ""

if [[ ! -d "$SOURCE_PLAYTOOLS" ]]; then
    echo "❌ ソースのPlayTools.frameworkが見つかりません: $SOURCE_PLAYTOOLS"
    exit 1
fi

echo "✅ ソース発見: $SOURCE_PLAYTOOLS"
echo "   バージョン:"
plutil -p "$SOURCE_PLAYTOOLS/Versions/A/Resources/Info.plist" 2>/dev/null | grep CFBundleShortVersionString | sed 's/^/     /'
echo ""

echo "【2. 既存のPlayTools.frameworkを確認】"
echo ""

if [[ -d "$TARGET_PLAYTOOLS" ]]; then
    echo "⚠️  既存のPlayTools.frameworkが見つかりました: $TARGET_PLAYTOOLS"
    echo "   削除して再インストールします"
    rm -rf "$TARGET_PLAYTOOLS"
fi

echo "【3. Frameworksディレクトリの作成】"
echo ""

if [[ ! -d "$TARGET_FRAMEWORKS" ]]; then
    echo "Frameworksディレクトリを作成: $TARGET_FRAMEWORKS"
    mkdir -p "$TARGET_FRAMEWORKS"
else
    echo "✅ Frameworksディレクトリ存在: $TARGET_FRAMEWORKS"
fi

echo ""
echo "【4. PlayTools.frameworkのコピー】"
echo ""

echo "コピー中..."
echo "  ソース: $SOURCE_PLAYTOOLS"
echo "  宛先:   $TARGET_PLAYTOOLS"
echo ""

cp -R "$SOURCE_PLAYTOOLS" "$TARGET_PLAYTOOLS"

if [[ $? -eq 0 ]]; then
    echo "✅ コピー完了"
else
    echo "❌ コピー失敗"
    exit 1
fi

echo ""
echo "【5. コピーしたフレームワークの確認】"
echo ""

if [[ -d "$TARGET_PLAYTOOLS" ]]; then
    echo "✅ PlayTools.framework正常にインストール: $TARGET_PLAYTOOLS"
    echo ""
    echo "   詳細:"
    ls -lh "$TARGET_PLAYTOOLS" | head -10 | sed 's/^/     /'
    echo ""
    echo "   バージョン:"
    plutil -p "$TARGET_PLAYTOOLS/Versions/A/Resources/Info.plist" 2>/dev/null | grep -E "CFBundleShortVersionString|CFBundleVersion" | sed 's/^/     /'
else
    echo "❌ インストール失敗"
    exit 1
fi

echo ""
echo "【6. 原神アプリで確認】"
echo ""

GENSHIN_EXE="${HOME}/Library/Containers/io.playcover.PlayCover/Applications/com.miHoYo.GenshinImpact.app/GenshinImpact"

if [[ -f "$GENSHIN_EXE" ]]; then
    echo "原神実行ファイルが参照するPlayTools:"
    otool -L "$GENSHIN_EXE" 2>/dev/null | grep -i playtools | sed 's/^/  /'
    echo ""
    
    # Entitlementsの確認
    echo "Entitlements内のPlayToolsパス:"
    codesign -d --entitlements :- "$GENSHIN_EXE" 2>/dev/null | grep "PlayTools" | sed 's/^/  /'
fi

echo ""
echo "=== 完了 ==="
echo ""
echo "次のステップ:"
echo "1. 原神を起動してクラッシュが解決したか確認"
echo "2. まだクラッシュする場合は、他のアプリも同様に確認"
echo "3. すべてのアプリで問題が解決しない場合は、PlayCoverの再インストールを検討"
