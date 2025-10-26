#!/bin/zsh

echo "=== PlayCover 詳細確認（修正版）==="
echo ""

echo "【1. PlayCover.app の構造】"
echo ""
echo "PlayCover.app 内の Frameworks:"
find /Applications/PlayCover.app/Contents -name "*.framework" -type d 2>/dev/null | while read framework; do
    echo "  ✅ $(basename $framework)"
    echo "     場所: $framework"
    
    # Info.plistがあれば詳細を表示
    if [[ -f "$framework/Versions/A/Resources/Info.plist" ]]; then
        echo "     バージョン:"
        plutil -p "$framework/Versions/A/Resources/Info.plist" 2>/dev/null | grep -E "CFBundleShortVersionString|CFBundleVersion" | sed 's/^/       /'
    elif [[ -f "$framework/Resources/Info.plist" ]]; then
        echo "     バージョン:"
        plutil -p "$framework/Resources/Info.plist" 2>/dev/null | grep -E "CFBundleShortVersionString|CFBundleVersion" | sed 's/^/       /'
    elif [[ -f "$framework/Info.plist" ]]; then
        echo "     バージョン:"
        plutil -p "$framework/Info.plist" 2>/dev/null | grep -E "CFBundleShortVersionString|CFBundleVersion" | sed 's/^/       /'
    fi
    echo ""
done

echo ""
echo "【2. 原神アプリの詳細】"
echo ""
GENSHIN_APP_PATH="${HOME}/Library/Containers/io.playcover.PlayCover/Applications/com.miHoYo.GenshinImpact.app"

if [[ -d "$GENSHIN_APP_PATH" ]]; then
    echo "✅ 原神アプリ発見: $GENSHIN_APP_PATH"
    echo ""
    
    # Info.plist
    if [[ -f "$GENSHIN_APP_PATH/Contents/Info.plist" ]]; then
        echo "   Info.plist 内容:"
        plutil -p "$GENSHIN_APP_PATH/Contents/Info.plist" | grep -E "CFBundleIdentifier|CFBundleShortVersionString|CFBundleExecutable" | sed 's/^/     /'
    fi
    echo ""
    
    # 実行ファイルの確認
    EXECUTABLE=$(plutil -p "$GENSHIN_APP_PATH/Contents/Info.plist" 2>/dev/null | grep CFBundleExecutable | sed 's/.*=> "//' | sed 's/"//')
    if [[ -n "$EXECUTABLE" ]]; then
        EXEC_PATH="$GENSHIN_APP_PATH/Contents/MacOS/$EXECUTABLE"
        if [[ -f "$EXEC_PATH" ]]; then
            echo "   実行ファイル: $EXEC_PATH"
            echo "     サイズ: $(du -h "$EXEC_PATH" | cut -f1)"
            echo "     権限: $(ls -l "$EXEC_PATH" | awk '{print $1}')"
        else
            echo "   ❌ 実行ファイルが見つかりません: $EXEC_PATH"
        fi
    fi
    echo ""
    
    # 埋め込まれたPlayTools.framework
    echo "   アプリ内の Frameworks:"
    if [[ -d "$GENSHIN_APP_PATH/Contents/Frameworks" ]]; then
        find "$GENSHIN_APP_PATH/Contents/Frameworks" -name "*.framework" -maxdepth 1 -type d | while read framework; do
            echo "     ✅ $(basename $framework)"
        done
    else
        echo "     ❌ Frameworks ディレクトリが存在しません"
    fi
    echo ""
    
    # _CodeSignature
    if [[ -d "$GENSHIN_APP_PATH/Contents/_CodeSignature" ]]; then
        echo "   ✅ コード署名ディレクトリ存在"
    else
        echo "   ❌ コード署名ディレクトリが存在しません"
    fi
    
else
    echo "❌ 原神アプリが見つかりません: $GENSHIN_APP_PATH"
fi

echo ""
echo "【3. 原神コンテナの詳細】"
echo ""
GENSHIN_CONTAINER="${HOME}/Library/Containers/com.miHoYo.GenshinImpact"

if [[ -d "$GENSHIN_CONTAINER" ]]; then
    echo "✅ 原神コンテナ発見: $GENSHIN_CONTAINER"
    echo ""
    echo "   コンテナ内の構造:"
    ls -la "$GENSHIN_CONTAINER" | sed 's/^/     /'
    echo ""
    
    # Data ディレクトリ
    if [[ -d "$GENSHIN_CONTAINER/Data" ]]; then
        echo "   Data ディレクトリのサイズ:"
        du -sh "$GENSHIN_CONTAINER/Data" 2>/dev/null | sed 's/^/     /'
        
        # Library/Preferences
        if [[ -d "$GENSHIN_CONTAINER/Data/Library/Preferences" ]]; then
            echo ""
            echo "   設定ファイル:"
            ls -lh "$GENSHIN_CONTAINER/Data/Library/Preferences" 2>/dev/null | grep ".plist" | sed 's/^/     /'
        fi
    fi
else
    echo "❌ 原神コンテナが見つかりません: $GENSHIN_CONTAINER"
fi

echo ""
echo "【4. 最新のクラッシュログ分析】"
echo ""
CRASH_DIR="${HOME}/Library/Logs/DiagnosticReports"
LATEST_CRASH=$(ls -t "$CRASH_DIR"/*GenshinImpact*.crash "$CRASH_DIR"/*GenshinImpact*.ips 2>/dev/null | head -1)

if [[ -n "$LATEST_CRASH" ]]; then
    echo "✅ 最新のクラッシュログ: $LATEST_CRASH"
    echo "   作成日時: $(stat -f %Sm -t "%Y-%m-%d %H:%M:%S" "$LATEST_CRASH")"
    echo ""
    echo "   重要なセクションを抽出:"
    echo ""
    
    # Exception Type
    echo "   【Exception Type】"
    grep -A 3 "Exception Type:" "$LATEST_CRASH" | sed 's/^/     /'
    echo ""
    
    # Termination Reason
    echo "   【Termination Reason】"
    grep -A 2 "Termination Reason:" "$LATEST_CRASH" | sed 's/^/     /'
    echo ""
    
    # Application Specific Information
    echo "   【Application Specific Information】"
    grep -A 10 "Application Specific Information:" "$LATEST_CRASH" | sed 's/^/     /'
    echo ""
    
    # PlayTools関連のスタックトレース
    echo "   【PlayTools関連のスタック】"
    grep -i "playtools" "$LATEST_CRASH" | head -20 | sed 's/^/     /'
    echo ""
    
    # クラッシュしたスレッド
    echo "   【クラッシュスレッドの最初の20行】"
    awk '/Thread [0-9]+ Crashed/,/^$/' "$LATEST_CRASH" | head -25 | sed 's/^/     /'
    
else
    echo "❌ クラッシュログが見つかりません"
    echo "   検索場所: $CRASH_DIR"
fi

echo ""
echo "【5. システム権限確認】"
echo ""
echo "アクセシビリティ権限:"
if sudo sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db "SELECT service, client, allowed FROM access WHERE service='kTCCServiceAccessibility';" 2>/dev/null | grep -i playcover; then
    echo "  ✅ PlayCoverに権限が付与されています"
else
    echo "  ⚠️  PlayCoverのアクセシビリティ権限を確認してください"
fi

echo ""
echo "=== 完了 ==="
