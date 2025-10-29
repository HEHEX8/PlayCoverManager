#!/bin/zsh

# 設定
LOG_FILE=~/playcover_verification_logs/mtime_tracking_$(date +%Y%m%d_%H%M%S).log
SETTINGS_DIR=~/Library/Containers/io.playcover.PlayCover/App\ Settings

mkdir -p ~/playcover_verification_logs

echo "=== PlayCover mtime Change Tracker ===" | tee $LOG_FILE
echo "Start time: $(date)" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

echo "👉 IPAファイルのBundle IDを入力してください:"
read BUNDLE_ID

SETTINGS_FILE="$SETTINGS_DIR/${BUNDLE_ID}.plist"
echo "Monitoring: $SETTINGS_FILE" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

# 初期状態
if [[ -f "$SETTINGS_FILE" ]]; then
    INITIAL_MTIME=$(stat -f %m "$SETTINGS_FILE")
    echo "Initial mtime: $INITIAL_MTIME ($(date -r $INITIAL_MTIME))" | tee -a $LOG_FILE
else
    INITIAL_MTIME=0
    echo "File does not exist yet" | tee -a $LOG_FILE
fi

echo "" | tee -a $LOG_FILE
echo "👉 今すぐPlayCoverでIPAをインストールしてください" | tee -a $LOG_FILE
echo "Ctrl+C で停止"
echo ""

# ヘッダー
echo "TIMESTAMP,MTIME,CHANGE_COUNT,DELTA_SEC,FILE_SIZE" | tee -a $LOG_FILE

LAST_MTIME=$INITIAL_MTIME
CHANGE_COUNT=0

while true; do
    if [[ -f "$SETTINGS_FILE" ]]; then
        CURRENT_MTIME=$(stat -f %m "$SETTINGS_FILE")
        FILE_SIZE=$(stat -f %z "$SETTINGS_FILE")
        
        if [[ $CURRENT_MTIME -ne $LAST_MTIME ]]; then
            ((CHANGE_COUNT++))
            DELTA=$((CURRENT_MTIME - LAST_MTIME))
            timestamp=$(date +%T)
            mtime_date=$(date -r $CURRENT_MTIME +%T)
            
            echo "$timestamp,$mtime_date,$CHANGE_COUNT,+${DELTA}s,${FILE_SIZE}B" | tee -a $LOG_FILE
            
            LAST_MTIME=$CURRENT_MTIME
        fi
    fi
    
    sleep 0.5
done

trap 'echo ""; echo "Total changes: $CHANGE_COUNT"; echo "Log saved: $LOG_FILE"; exit' INT

wait
