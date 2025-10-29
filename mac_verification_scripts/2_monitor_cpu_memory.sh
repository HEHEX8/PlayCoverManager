#!/bin/zsh

# 設定
LOG_FILE=~/playcover_verification_logs/cpu_memory_$(date +%Y%m%d_%H%M%S).log
INTERVAL=1  # 1秒間隔

mkdir -p ~/playcover_verification_logs

echo "=== PlayCover CPU & Memory Monitor ===" | tee $LOG_FILE
echo "Start time: $(date)" | tee -a $LOG_FILE
echo "Interval: ${INTERVAL}s" | tee -a $LOG_FILE
echo "" | tee -a $LOG_FILE

# ヘッダー
echo "TIME,CPU%,MEM_MB,THREADS" | tee -a $LOG_FILE

# 監視開始
echo "👉 今すぐPlayCoverでIPAをインストールしてください" | tee -a $LOG_FILE
echo "Ctrl+C で停止"
echo ""

while true; do
    # PlayCoverのプロセス情報取得
    ps_output=$(ps aux | grep "[P]layCover.app/Contents/MacOS/PlayCover" | head -1)
    
    if [[ -n "$ps_output" ]]; then
        cpu=$(echo $ps_output | awk '{print $3}')
        mem_kb=$(echo $ps_output | awk '{print $6}')
        mem_mb=$(echo "scale=2; $mem_kb / 1024" | bc)
        
        # スレッド数取得
        pid=$(echo $ps_output | awk '{print $2}')
        threads=$(ps -M $pid 2>/dev/null | wc -l)
        
        timestamp=$(date +%T)
        echo "$timestamp,$cpu,$mem_mb,$threads" | tee -a $LOG_FILE
    else
        echo "$(date +%T),0,0,0" | tee -a $LOG_FILE
    fi
    
    sleep $INTERVAL
done

# Ctrl+Cで停止後、グラフ生成用のデータ確認
trap 'echo ""; echo "Log saved: $LOG_FILE"; echo ""; echo "Peak CPU usage:"; sort -t, -k2 -n -r $LOG_FILE | head -5; exit' INT

wait
