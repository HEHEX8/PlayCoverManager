#!/bin/zsh

echo "=== PlayCover 詳細ログ取得 ==="
echo ""
echo "このスクリプトは以下を実行します:"
echo "1. PlayCoverの詳細ログをキャプチャ"
echo "2. 原神アプリ起動"
echo "3. クラッシュログを収集"
echo ""
echo "※ 原神を起動してクラッシュさせます。準備ができたらEnterキーを押してください。"
read

LOG_FILE="${HOME}/Desktop/playcover_debug_$(date +%Y%m%d_%H%M%S).log"

echo "ログ収集を開始します..."
echo "ログファイル: $LOG_FILE"
echo ""

{
    echo "=== PlayCover 詳細ログ ==="
    echo "収集日時: $(date)"
    echo ""
    
    echo "【システム情報】"
    sw_vers
    echo ""
    
    echo "【PlayCover プロセス起動前】"
    ps aux | grep -i playcover | grep -v grep
    echo ""
    
    echo "【Console ログ (PlayCover 関連)】"
    log show --predicate 'process == "PlayCover" OR process CONTAINS "GenshinImpact"' --last 5m --info --debug --style compact
    echo ""
    
    echo "【System ログ (UIKit, Scene 関連エラー)】"
    log show --predicate 'eventMessage CONTAINS "UIKit" OR eventMessage CONTAINS "scene" OR eventMessage CONTAINS "assertion"' --last 5m --info --debug --style compact
    echo ""
    
    echo "【最新のクラッシュレポート (原神)】"
    CRASH_DIR="${HOME}/Library/Logs/DiagnosticReports"
    if [[ -d "$CRASH_DIR" ]]; then
        LATEST_CRASH=$(ls -t "$CRASH_DIR"/GenshinImpact*.crash 2>/dev/null | head -1)
        if [[ -n "$LATEST_CRASH" ]]; then
            echo "ファイル: $LATEST_CRASH"
            echo "---"
            head -100 "$LATEST_CRASH"
        else
            echo "原神のクラッシュレポートが見つかりません"
        fi
    fi
    
} > "$LOG_FILE" 2>&1

echo "✅ ログ収集完了: $LOG_FILE"
echo ""
echo "次に原神を起動してクラッシュさせてください。"
echo "クラッシュ後、再度Enterキーを押してください。"
read

# クラッシュ後のログを追加収集
{
    echo ""
    echo "=== クラッシュ後の追加ログ ==="
    echo "収集日時: $(date)"
    echo ""
    
    echo "【最新のクラッシュレポート】"
    LATEST_CRASH=$(ls -t "$CRASH_DIR"/GenshinImpact*.crash 2>/dev/null | head -1)
    if [[ -n "$LATEST_CRASH" ]]; then
        echo "ファイル: $LATEST_CRASH"
        echo "更新日時: $(stat -f %Sm "$LATEST_CRASH")"
        echo "---"
        cat "$LATEST_CRASH"
    fi
    
    echo ""
    echo "【Console ログ (クラッシュ直後)】"
    log show --predicate 'process == "PlayCover" OR process CONTAINS "GenshinImpact"' --last 2m --info --debug --style compact
    
} >> "$LOG_FILE" 2>&1

echo "✅ 完全なログ収集完了"
echo "📄 ログファイル: $LOG_FILE"
echo ""
echo "このファイルを確認して、エラーメッセージを探してください。"
