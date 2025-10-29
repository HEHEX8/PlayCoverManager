#!/bin/zsh

# 設定
LOG_FILE=~/playcover_verification_logs/filesystem_trace_$(date +%Y%m%d_%H%M%S).log
MONITOR_DIR=~/Library/Containers/io.playcover.PlayCover

mkdir -p ~/playcover_verification_logs

echo "=== PlayCover Filesystem Trace ===" | tee $LOG_FILE
echo "Start time: $(date)" | tee -a $LOG_FILE
echo "Monitoring: $MONITOR_DIR" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

# fswatch起動（バックグラウンド）
fswatch -r $MONITOR_DIR \
    --format-time "%F %T" \
    --timestamp-format "%F %T" \
    --event Created \
    --event Updated \
    --event Removed \
    --event Renamed \
    2>&1 | while IFS= read -r line; do
        echo "[$(date +%T)] $line" | tee -a $LOG_FILE
    done &

FSWATCH_PID=$!

echo "fswatch started (PID: $FSWATCH_PID)" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
echo "👉 今すぐPlayCoverでIPAをインストールしてください" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE
echo "インストール完了後、Enterキーを押してください..."
read

# fswatch停止
kill $FSWATCH_PID 2>/dev/null
echo "" | tee -a $LOG_FILE
echo "End time: $(date)" | tee -a $LOG_FILE
echo "Log saved: $LOG_FILE" | tee -a $LOG_FILE

# ログ解析
echo "" | tee -a $LOG_FILE
echo "=== Analysis ===" | tee -a $LOG_FILE
grep "\.app" $LOG_FILE | tail -10 | tee -a $LOG_FILE
