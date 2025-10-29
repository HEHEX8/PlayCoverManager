#!/bin/zsh

# 設定
LOG_DIR=~/playcover_verification_logs/comprehensive_$(date +%Y%m%d_%H%M%S)
mkdir -p $LOG_DIR

echo "=== Comprehensive PlayCover Installation Monitor ==="
echo "Log directory: $LOG_DIR"
echo ""

echo "👉 IPAファイルのBundle IDを入力してください:"
read BUNDLE_ID

echo "👉 IPAファイルサイズ（MB）を入力してください:"
read IPA_SIZE

# ログファイル
FS_LOG="$LOG_DIR/filesystem.log"
CPU_LOG="$LOG_DIR/cpu_memory.log"
LSOF_LOG="$LOG_DIR/file_access.log"
MTIME_LOG="$LOG_DIR/mtime_changes.log"
SUMMARY_LOG="$LOG_DIR/summary.txt"

# サマリー記録
cat > $SUMMARY_LOG << EOF
=== Installation Summary ===
Date: $(date)
Bundle ID: $BUNDLE_ID
IPA Size: ${IPA_SIZE}MB
Settings File: ~/Library/Containers/io.playcover.PlayCover/App Settings/${BUNDLE_ID}.plist
App Bundle: ~/Library/Containers/io.playcover.PlayCover/Apps/${BUNDLE_ID}.app
EOF

echo "Starting comprehensive monitoring..."
echo ""

# 1. Filesystem monitoring
fswatch -r ~/Library/Containers/io.playcover.PlayCover \
    --format-time "%T" > $FS_LOG 2>&1 &
FS_PID=$!

# 2. CPU/Memory monitoring
{
    echo "TIME,CPU%,MEM_MB"
    while true; do
        ps_output=$(ps aux | grep "[P]layCover.app/Contents/MacOS/PlayCover" | head -1)
        if [[ -n "$ps_output" ]]; then
            cpu=$(echo $ps_output | awk '{print $3}')
            mem_kb=$(echo $ps_output | awk '{print $6}')
            mem_mb=$(echo "scale=2; $mem_kb / 1024" | bc)
            echo "$(date +%T),$cpu,$mem_mb"
        fi
        sleep 1
    done
} > $CPU_LOG 2>&1 &
CPU_PID=$!

# 3. lsof monitoring
{
    while true; do
        lsof ~/Library/Containers/io.playcover.PlayCover/App\ Settings/*.plist 2>/dev/null \
            | grep -i playcover | awk -v t="$(date +%T)" '{print t","$0}'
        sleep 0.5
    done
} > $LSOF_LOG 2>&1 &
LSOF_PID=$!

# 4. mtime monitoring
SETTINGS_FILE=~/Library/Containers/io.playcover.PlayCover/App\ Settings/${BUNDLE_ID}.plist
{
    echo "TIME,MTIME,CHANGE_COUNT"
    LAST_MTIME=0
    CHANGE_COUNT=0
    while true; do
        if [[ -f "$SETTINGS_FILE" ]]; then
            CURRENT_MTIME=$(stat -f %m "$SETTINGS_FILE" 2>/dev/null || echo 0)
            if [[ $CURRENT_MTIME -ne $LAST_MTIME ]]; then
                ((CHANGE_COUNT++))
                echo "$(date +%T),$(date -r $CURRENT_MTIME +%T),$CHANGE_COUNT"
                LAST_MTIME=$CURRENT_MTIME
            fi
        fi
        sleep 0.5
    done
} > $MTIME_LOG 2>&1 &
MTIME_PID=$!

echo "✅ All monitors started"
echo ""
echo "Monitor PIDs:"
echo "  - Filesystem: $FS_PID"
echo "  - CPU/Memory: $CPU_PID"
echo "  - lsof: $LSOF_PID"
echo "  - mtime: $MTIME_PID"
echo ""
echo "👉 今すぐPlayCoverでIPAをインストールしてください"
echo ""
echo "完了したらEnterキーを押してください..."
read

# 停止
kill $FS_PID $CPU_PID $LSOF_PID $MTIME_PID 2>/dev/null
sleep 1

echo ""
echo "=== Monitoring Complete ==="
echo "Logs saved to: $LOG_DIR"
echo ""
echo "Quick analysis:"
echo "- Filesystem events: $(wc -l < $FS_LOG) events"
echo "- CPU samples: $(tail -n +2 $CPU_LOG | wc -l) samples"
echo "- File accesses: $(wc -l < $LSOF_LOG) accesses"
echo "- mtime changes: $(tail -n +2 $MTIME_LOG | wc -l) changes"
echo ""
echo "Peak CPU usage:"
tail -n +2 $CPU_LOG | sort -t, -k2 -n -r | head -3
echo ""
echo "📊 送付してください: $LOG_DIR/* (全ファイル)"
