#!/bin/zsh

echo "=== PlayCover macOS 26 Tahoe 既知の問題確認 ==="
echo ""

echo "【重要な情報】"
echo ""
echo "環境:"
echo "  - macOS: 26.0.1 (25A362) Tahoe"
echo "  - PlayCover: 3.1.0 (Build 856)"
echo "  - M4 MacBook Air"
echo ""
echo "症状:"
echo "  - すべてのiOSアプリが即座にクラッシュ"
echo "  - クラッシュ場所: UIKitMacHelper シーン作成"
echo "  - 以前は正常動作していた"
echo ""

echo "【PlayCover GitHubでの関連Issue検索推奨】"
echo ""
echo "検索キーワード:"
echo "  1. 'macOS 26' OR 'Tahoe'"
echo "  2. 'UIKitMacHelper'"
echo "  3. 'scene creation'"
echo "  4. 'UINSApplicationDelegate'"
echo ""
echo "GitHub Issues URL:"
echo "  https://github.com/PlayCover/PlayCover/issues"
echo ""

echo "【一時的な回避策の試行】"
echo ""

echo "方法1: PlayCoverの環境変数設定"
echo "--------------------------------------"
echo ""
echo "以下のコマンドを試してください:"
echo ""
cat << 'EOF'
# PlayCoverアプリに環境変数を設定
defaults write io.playcover.PlayCover NSApplicationCrashOnExceptions -bool NO
EOF
echo ""

echo "方法2: システム整合性保護(SIP)の一時的な調整"
echo "--------------------------------------"
echo "※これは推奨しません。セキュリティリスクがあります"
echo ""

echo "方法3: macOS 26固有の問題を回避"
echo "--------------------------------------"
echo ""
echo "以下の診断スクリプトを実行:"
echo ""

# macOS 26でのUIKitMacHelper問題を診断
cat << 'EOF'
# UIKitMacHelperのバージョン確認
otool -L /System/Library/PrivateFrameworks/UIKitMacHelper.framework/Versions/A/UIKitMacHelper | head -5

# システムログでUIKitMacHelper関連のエラーを確認
log show --predicate 'subsystem == "com.apple.UIKit" OR subsystem == "com.apple.UIKitMacHelper"' --last 5m --info --debug | grep -i error
EOF
echo ""

echo "【PlayCover互換性確認】"
echo ""

# PlayCoverの設定を確認
echo "現在のPlayCover設定:"
if [[ -f ~/Library/Preferences/io.playcover.PlayCover.plist ]]; then
    plutil -p ~/Library/Preferences/io.playcover.PlayCover.plist 2>/dev/null | head -20
else
    echo "  設定ファイルが見つかりません"
fi
echo ""

echo "【推奨される対応】"
echo ""
echo "1. ⭐ PlayCoverのGitHubで macOS 26 Tahoe の既知の問題を確認"
echo "   https://github.com/PlayCover/PlayCover/issues"
echo ""
echo "2. 問題が報告されていない場合は、新しいIssueを作成:"
echo "   - タイトル: 'All apps crash immediately on macOS 26 Tahoe'"
echo "   - 詳細: UIKitMacHelper scene creation failure"
echo "   - 添付: クラッシュログ"
echo ""
echo "3. PlayCoverの開発版(nightly build)を試す:"
echo "   https://github.com/PlayCover/PlayCover/actions"
echo ""
echo "4. PlayCoverコミュニティDiscordで相談:"
echo "   https://discord.gg/playcover"
echo ""

echo "【緊急回避策: macOS Sonomaへのダウングレード】"
echo ""
echo "⚠️  最終手段として、macOS 25 (Sonoma) へのダウングレードを検討"
echo "   - Time Machineバックアップから復元"
echo "   - または、macOS再インストール"
echo ""

echo "=== 診断完了 ==="
