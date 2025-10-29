#!/bin/zsh

# 設定
LOG_FILE=~/playcover_verification_logs/file_access_$(date +%Y%m%d_%H%M%S).log
SETTINGS_DIR=~/Library/Containers/io.playcover.PlayCover/App\ Settings

mkdir -p ~/playcover_verification_logs

echo "=== PlayCover File Access Monitor (lsof) ===" | tee $LOG_FILE
echo "Start time: $(date)" | tee -a $LOG_FILE
echo "Monitoring: $SETTINGS_DIR" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

echo "👉 今すぐPlayCoverでIPAをインストールしてください" | tee -a $LOG_FILE
echo "Ctrl+C で停止"
echo ""

# ヘッダー
echo "TIMESTAMP,PROCESS,PID,FILE,MODE" | tee -a $LOG_FILE

while true; do
    lsof "$SETTINGS_DIR"/*.plist 2>/dev/null | grep -i playcover | while read line; do
        timestamp=$(date +%T.%N)
        process=$(echo $line | awk '{print $1}')
        pid=$(echo $line | awk '{print $2}')
        mode=$(echo $line | awk '{print $4}')
        file=$(echo $line | awk '{print $NF}')
        
        echo "$timestamp,$process,$pid,$file,$mode" | tee -a $LOG_FILE
    done
    
    sleep 0.5
done

trap 'echo ""; echo "Log saved: $LOG_FILE"; exit' INT

wait
