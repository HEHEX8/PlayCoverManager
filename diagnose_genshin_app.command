#!/bin/zsh

echo "=== 原神アプリ詳細診断 ==="
echo ""

GENSHIN_APP="${HOME}/Library/Containers/io.playcover.PlayCover/Applications/com.miHoYo.GenshinImpact.app"

echo "【1. アプリの完全な構造】"
echo ""
echo "アプリパス: $GENSHIN_APP"
echo ""

if [[ ! -d "$GENSHIN_APP" ]]; then
    echo "❌ アプリが見つかりません"
    exit 1
fi

echo "ディレクトリ構造:"
tree -L 3 "$GENSHIN_APP" 2>/dev/null || find "$GENSHIN_APP" -maxdepth 3 -print | sed 's/^/  /'

echo ""
echo "【2. Contents ディレクトリの詳細】"
echo ""
ls -lah "$GENSHIN_APP/Contents" 2>/dev/null | sed 's/^/  /'

echo ""
echo "【3. Info.plist の確認】"
echo ""

INFO_PLIST="$GENSHIN_APP/Contents/Info.plist"
if [[ -f "$INFO_PLIST" ]]; then
    echo "✅ Info.plist 存在: $INFO_PLIST"
    echo "   サイズ: $(du -h "$INFO_PLIST" | cut -f1)"
    echo "   権限: $(ls -l "$INFO_PLIST" | awk '{print $1}')"
    echo ""
    echo "   内容:"
    plutil -p "$INFO_PLIST" 2>&1 | sed 's/^/     /'
    echo ""
    echo "   生のXML (最初の50行):"
    head -50 "$INFO_PLIST" | sed 's/^/     /'
else
    echo "❌ Info.plist が見つかりません"
fi

echo ""
echo "【4. MacOS ディレクトリの確認】"
echo ""
if [[ -d "$GENSHIN_APP/Contents/MacOS" ]]; then
    echo "✅ MacOS ディレクトリ存在"
    echo ""
    echo "   内容:"
    ls -lah "$GENSHIN_APP/Contents/MacOS" | sed 's/^/     /'
    echo ""
    
    # 実行ファイルの詳細
    for file in "$GENSHIN_APP/Contents/MacOS"/*; do
        if [[ -f "$file" ]] && [[ -x "$file" ]]; then
            echo "   実行ファイル: $(basename "$file")"
            echo "     タイプ: $(file "$file")"
            echo "     署名: $(codesign -dv "$file" 2>&1 | head -5 | sed 's/^/       /')"
        fi
    done
else
    echo "❌ MacOS ディレクトリが見つかりません"
fi

echo ""
echo "【5. Frameworks ディレクトリの確認】"
echo ""
if [[ -d "$GENSHIN_APP/Contents/Frameworks" ]]; then
    echo "✅ Frameworks ディレクトリ存在"
    ls -lah "$GENSHIN_APP/Contents/Frameworks" | sed 's/^/  /'
else
    echo "❌ Frameworks ディレクトリが存在しません"
    echo "   これはPlayCoverのインストール失敗を示しています"
fi

echo ""
echo "【6. _CodeSignature の確認】"
echo ""
if [[ -d "$GENSHIN_APP/Contents/_CodeSignature" ]]; then
    echo "✅ _CodeSignature ディレクトリ存在"
    ls -lah "$GENSHIN_APP/Contents/_CodeSignature" | sed 's/^/  /'
else
    echo "❌ _CodeSignature ディレクトリが存在しません"
    echo "   これはアプリが署名されていないことを示しています"
fi

echo ""
echo "【7. アプリ全体のコード署名確認】"
echo ""
codesign -dv --verbose=4 "$GENSHIN_APP" 2>&1 | sed 's/^/  /'

echo ""
echo "【8. クラッシュログの検索】"
echo ""
CRASH_DIR="${HOME}/Library/Logs/DiagnosticReports"
echo "検索場所: $CRASH_DIR"
echo ""
echo "最近のクラッシュログ (すべて):"
ls -lt "$CRASH_DIR" 2>/dev/null | head -20 | grep -E "\.(crash|ips)$" | sed 's/^/  /'

echo ""
echo "原神関連のクラッシュログ:"
ls -lt "$CRASH_DIR" 2>/dev/null | grep -i genshin | sed 's/^/  /'

echo ""
echo "【9. PlayCoverのログ確認】"
echo ""
PLAYCOVER_LOG_DIR="${HOME}/Library/Logs/PlayCover"
if [[ -d "$PLAYCOVER_LOG_DIR" ]]; then
    echo "PlayCoverログディレクトリ: $PLAYCOVER_LOG_DIR"
    ls -lt "$PLAYCOVER_LOG_DIR" | head -10 | sed 's/^/  /'
    echo ""
    
    # 最新のログファイル
    LATEST_LOG=$(ls -t "$PLAYCOVER_LOG_DIR"/*.log 2>/dev/null | head -1)
    if [[ -n "$LATEST_LOG" ]]; then
        echo "最新ログファイルの最後の50行:"
        tail -50 "$LATEST_LOG" | sed 's/^/  /'
    fi
else
    echo "PlayCoverログディレクトリが見つかりません"
fi

echo ""
echo "【10. PlayCoverの install.sh 実行ログ】"
echo ""
# PlayCoverがアプリインストール時に使用するスクリプト
INSTALL_SCRIPT="/Applications/PlayCover.app/Contents/Resources/install.sh"
if [[ -f "$INSTALL_SCRIPT" ]]; then
    echo "✅ install.sh スクリプト存在: $INSTALL_SCRIPT"
    echo "   内容の一部:"
    head -30 "$INSTALL_SCRIPT" | sed 's/^/     /'
else
    echo "❌ install.sh が見つかりません"
fi

echo ""
echo "=== 完了 ==="
echo ""
echo "【診断結果サマリー】"
echo ""

# サマリーを生成
ISSUES=0

if [[ ! -d "$GENSHIN_APP/Contents/Frameworks" ]]; then
    echo "❌ 重大: Frameworksディレクトリが欠落"
    ((ISSUES++))
fi

if [[ ! -d "$GENSHIN_APP/Contents/_CodeSignature" ]]; then
    echo "❌ 重大: コード署名が欠落"
    ((ISSUES++))
fi

if [[ ! -f "$GENSHIN_APP/Contents/Info.plist" ]]; then
    echo "❌ 重大: Info.plistが欠落"
    ((ISSUES++))
fi

if [[ $ISSUES -eq 0 ]]; then
    echo "✅ アプリ構造は正常です"
else
    echo ""
    echo "発見された問題: $ISSUES 件"
    echo ""
    echo "推奨対応: 原神アプリを PlayCover から削除して再インストール"
fi
