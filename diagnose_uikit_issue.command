#!/bin/zsh

echo "=== UIKitMacHelper 詳細診断 ==="
echo ""

echo "【1. UIKitMacHelperのバージョン確認】"
echo ""
UIKIT_HELPER="/System/Library/PrivateFrameworks/UIKitMacHelper.framework/Versions/A/UIKitMacHelper"

if [[ -f "$UIKIT_HELPER" ]]; then
    echo "UIKitMacHelper: $UIKIT_HELPER"
    echo ""
    echo "依存関係:"
    otool -L "$UIKIT_HELPER" | head -10 | sed 's/^/  /'
    echo ""
    echo "Info.plist:"
    INFO_PLIST="/System/Library/PrivateFrameworks/UIKitMacHelper.framework/Versions/A/Resources/Info.plist"
    if [[ -f "$INFO_PLIST" ]]; then
        plutil -p "$INFO_PLIST" | grep -E "CFBundleShortVersionString|CFBundleVersion|BuildMachineOSBuild" | sed 's/^/  /'
    fi
else
    echo "❌ UIKitMacHelperが見つかりません"
fi

echo ""
echo "【2. システムログの確認】"
echo ""
echo "UIKitMacHelper関連のエラー (最近5分間):"
log show --predicate 'process == "GenshinImpact" AND messageType == "Error"' --last 5m --style compact 2>/dev/null | grep -i "uikit\|scene\|assertion" | tail -20 | sed 's/^/  /'

echo ""
echo "【3. クラッシュの詳細分析】"
echo ""
LATEST_CRASH=$(ls -t ~/Library/Logs/DiagnosticReports/GenshinImpact-*.ips 2>/dev/null | head -1)

if [[ -n "$LATEST_CRASH" ]]; then
    echo "最新クラッシュログ: $(basename "$LATEST_CRASH")"
    echo ""
    
    # Application Specific Informationを抽出
    echo "Application Specific Information:"
    awk '/Application Specific Information/,/^$/' "$LATEST_CRASH" | head -15 | sed 's/^/  /'
    echo ""
    
    # Assertion failureの詳細
    echo "Assertionの詳細:"
    grep -A 5 "Assertion failure" "$LATEST_CRASH" | sed 's/^/  /'
    echo ""
    
    # Exception messageの詳細
    echo "Exception Message:"
    grep -A 3 "Exception Message:" "$LATEST_CRASH" | sed 's/^/  /'
fi

echo ""
echo "【4. PlayCover起動オプションの確認】"
echo ""
echo "現在のPlayCover設定:"
defaults read io.playcover.PlayCover 2>/dev/null | grep -E "NSApplicationCrashOnExceptions|debug|verbose" | sed 's/^/  /'

echo ""
echo "【5. 試行可能な回避策】"
echo ""

cat << 'EOF'
以下のコマンドを順番に試してください:

1. PlayCoverのクラッシュ処理を無効化:
   defaults write io.playcover.PlayCover NSApplicationCrashOnExceptions -bool NO

2. PlayCoverのキャッシュをクリア:
   rm -rf ~/Library/Caches/io.playcover.PlayCover
   rm -rf ~/Library/Saved\ Application\ State/io.playcover.PlayCover.savedState

3. PlayCoverを再起動して、再度アプリを起動

4. それでもクラッシュする場合は、PlayCoverの開発版を試す:
   https://github.com/PlayCover/PlayCover/actions

5. または、PlayCover Community Discordで相談:
   https://discord.gg/playcover
EOF

echo ""
echo "【6. macOS 26 Tahoeでの既知の問題】"
echo ""

cat << 'EOF'
macOS 26 Tahoe (25A362) は最新のメジャーリリースです。
PlayCover 3.1.0 (2024年9月リリース) は、リリース時点で
macOS 26 Tahoeの最終版が存在しなかったため、
完全な互換性テストが行われていない可能性があります。

推奨事項:
1. PlayCoverのGitHubで「macOS 26」または「Tahoe」で検索
2. 同様の問題が報告されているか確認
3. 報告がない場合は、新しいIssueを作成

GitHub Issues:
https://github.com/PlayCover/PlayCover/issues

Discord Community:
https://discord.gg/playcover
EOF

echo ""
echo "=== 診断完了 ==="
