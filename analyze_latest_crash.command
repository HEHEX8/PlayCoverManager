#!/bin/zsh

echo "=== 最新クラッシュログ分析 ==="
echo ""

CRASH_DIR="${HOME}/Library/Logs/DiagnosticReports"
LATEST_CRASH=$(ls -t "$CRASH_DIR"/GenshinImpact-*.ips 2>/dev/null | head -1)

if [[ -z "$LATEST_CRASH" ]]; then
    echo "❌ クラッシュログが見つかりません"
    exit 1
fi

echo "📄 最新クラッシュログ: $(basename "$LATEST_CRASH")"
echo "作成日時: $(stat -f %Sm -t "%Y-%m-%d %H:%M:%S" "$LATEST_CRASH")"
echo ""

echo "【1. 基本情報】"
echo ""
grep -A 5 "^Process:" "$LATEST_CRASH" | sed 's/^/  /'
echo ""

echo "【2. Exception情報】"
echo ""
grep -A 5 "^Exception Type:" "$LATEST_CRASH" | sed 's/^/  /'
echo ""

echo "【3. Termination Reason】"
echo ""
grep -A 3 "^Termination Reason:" "$LATEST_CRASH" | sed 's/^/  /'
echo ""

echo "【4. Application Specific Information】"
echo ""
grep -A 20 "^Application Specific Information:" "$LATEST_CRASH" | sed 's/^/  /'
echo ""

echo "【5. クラッシュスレッド (Thread 0)】"
echo ""
awk '/^Thread 0 Crashed:/,/^$/' "$LATEST_CRASH" | head -30 | sed 's/^/  /'
echo ""

echo "【6. Binary Images - PlayTools関連】"
echo ""
grep -i "playtools" "$LATEST_CRASH" | sed 's/^/  /'
echo ""

echo "【7. Binary Images - UIKit関連】"
echo ""
grep -i "uikit" "$LATEST_CRASH" | head -5 | sed 's/^/  /'
echo ""

echo "【8. 実行ファイルの詳細確認】"
echo ""
GENSHIN_EXE="${HOME}/Library/Containers/io.playcover.PlayCover/Applications/com.miHoYo.GenshinImpact.app/GenshinImpact"

if [[ -f "$GENSHIN_EXE" ]]; then
    echo "実行ファイル: $GENSHIN_EXE"
    echo ""
    
    echo "  ファイル情報:"
    file "$GENSHIN_EXE" | sed 's/^/    /'
    echo ""
    
    echo "  権限:"
    ls -l "$GENSHIN_EXE" | sed 's/^/    /'
    echo ""
    
    echo "  コード署名詳細:"
    codesign -dvvv "$GENSHIN_EXE" 2>&1 | grep -E "Identifier|Authority|TeamIdentifier|Signature|CodeDirectory" | sed 's/^/    /'
    echo ""
    
    echo "  Entitlements:"
    codesign -d --entitlements :- "$GENSHIN_EXE" 2>/dev/null | sed 's/^/    /'
    echo ""
    
    echo "  埋め込まれたフレームワーク:"
    otool -L "$GENSHIN_EXE" 2>/dev/null | grep -i "playtools\|framework" | head -10 | sed 's/^/    /'
else
    echo "❌ 実行ファイルが見つかりません"
fi

echo ""
echo "【9. PlayCoverインストールプロセスの確認】"
echo ""

# PlayCoverがインストール時に使用するスクリプトやツール
PLAYCOVER_APP="/Applications/PlayCover.app"

if [[ -d "$PLAYCOVER_APP" ]]; then
    echo "PlayCover内のリソース:"
    find "$PLAYCOVER_APP/Contents/Resources" -type f -name "*.sh" -o -name "*install*" -o -name "*sign*" 2>/dev/null | sed 's/^/  /'
    echo ""
    
    echo "PlayCover実行ファイル:"
    PLAYCOVER_EXE="$PLAYCOVER_APP/Contents/MacOS/PlayCover"
    if [[ -f "$PLAYCOVER_EXE" ]]; then
        echo "  バージョン:"
        "$PLAYCOVER_EXE" --version 2>&1 | sed 's/^/    /' || echo "    バージョン情報なし"
    fi
fi

echo ""
echo "【10. Frameworks比較】"
echo ""

GENSHIN_FRAMEWORKS="${HOME}/Library/Containers/io.playcover.PlayCover/Applications/com.miHoYo.GenshinImpact.app/Frameworks"
PLAYCOVER_PLAYTOOLS="/Applications/PlayCover.app/Contents/Frameworks/PlayTools.framework"

echo "原神アプリ内のFrameworks:"
if [[ -d "$GENSHIN_FRAMEWORKS" ]]; then
    ls -lh "$GENSHIN_FRAMEWORKS" | sed 's/^/  /'
else
    echo "  ❌ Frameworksディレクトリが見つかりません"
fi

echo ""
echo "PlayCover内のPlayTools.framework:"
if [[ -d "$PLAYCOVER_PLAYTOOLS" ]]; then
    echo "  ✅ 存在: $PLAYCOVER_PLAYTOOLS"
    echo "  バージョン:"
    plutil -p "$PLAYCOVER_PLAYTOOLS/Versions/A/Resources/Info.plist" 2>/dev/null | grep -E "CFBundleShortVersionString" | sed 's/^/    /'
else
    echo "  ❌ PlayTools.frameworkが見つかりません"
fi

echo ""
echo "=== 分析完了 ==="
echo ""
echo "【重要な確認ポイント】"
echo "1. PlayTools.framework が原神アプリ内に埋め込まれているか？"
echo "2. 実行ファイルのEntitlementsが正しく設定されているか？"
echo "3. クラッシュの具体的なエラーメッセージは何か？"
