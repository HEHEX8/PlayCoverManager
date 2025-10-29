# Mac環境での実機検証スクリプト集

PlayCoverのインストール検知ロジック最適化のため、以下の検証を実施してください。

---

## 📋 検証前の準備

```bash
# ログディレクトリ作成
mkdir -p ~/playcover_verification_logs
cd ~/playcover_verification_logs

# PlayCoverのバージョン確認
/Applications/PlayCover.app/Contents/MacOS/PlayCover --version || \
    echo "PlayCover version check not available"

# テスト用IPA準備（180MBの小容量と2-3GBの大容量）
ls -lh ~/Downloads/*.ipa
```

---

## 🔬 検証1: ファイルシステム変更の完全トレース

### スクリプト: `trace_filesystem_changes.sh`

```bash
#!/bin/zsh

# 設定
LOG_FILE=~/playcover_verification_logs/filesystem_trace_$(date +%Y%m%d_%H%M%S).log
MONITOR_DIR=~/Library/Containers/io.playcover.PlayCover

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
```

### 実行方法

```bash
chmod +x trace_filesystem_changes.sh
./trace_filesystem_changes.sh

# PlayCoverでIPAインストール（GUI操作）
# 完了したらEnterキー押下
```

### 期待される情報

- `App Settings/*.plist`の作成/更新タイミング
- `Apps/*.app`バンドルの作成タイミング
- 各ステップでのファイル操作順序

---

## 🔬 検証2: CPU使用率とメモリ使用量の推移

### スクリプト: `monitor_cpu_memory.sh`

```bash
#!/bin/zsh

# 設定
LOG_FILE=~/playcover_verification_logs/cpu_memory_$(date +%Y%m%d_%H%M%S).log
INTERVAL=1  # 1秒間隔

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
```

### 実行方法

```bash
chmod +x monitor_cpu_memory.sh
./monitor_cpu_memory.sh

# PlayCoverでIPAインストール（GUI操作）
# 完了したらCtrl+Cで停止
```

### 期待される情報

- インストール開始時のCPUスパイク
- インストール処理中の平均CPU使用率
- アイドル状態に戻るタイミング
- メモリ使用量の推移

---

## 🔬 検証3: lsofによるファイルアクセス監視

### スクリプト: `monitor_file_access.sh`

```bash
#!/bin/zsh

# 設定
LOG_FILE=~/playcover_verification_logs/file_access_$(date +%Y%m%d_%H%M%S).log
SETTINGS_DIR=~/Library/Containers/io.playcover.PlayCover/App\ Settings

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
```

### 実行方法

```bash
chmod +x monitor_file_access.sh
./monitor_file_access.sh

# PlayCoverでIPAインストール（GUI操作）
# 完了したらCtrl+Cで停止
```

### 期待される情報

- PlayCoverが設定ファイルをいつまでオープンしているか
- ファイルアクセスモード（読み取り/書き込み）
- ファイルクローズのタイミング

---

## 🔬 検証4: mtime変更の詳細トラッキング

### スクリプト: `track_mtime_changes.sh`

```bash
#!/bin/zsh

# 設定
LOG_FILE=~/playcover_verification_logs/mtime_tracking_$(date +%Y%m%d_%H%M%S).log
SETTINGS_DIR=~/Library/Containers/io.playcover.PlayCover/App\ Settings

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
```

### 実行方法

```bash
chmod +x track_mtime_changes.sh
./track_mtime_changes.sh

# Bundle ID入力（例: com.miHoYo.GenshinImpact）
# PlayCoverでIPAインストール（GUI操作）
# 完了したらCtrl+Cで停止
```

### 期待される情報

- 設定ファイルの更新回数
- 各更新間の時間間隔
- ファイルサイズの変化

---

## 🔬 検証5: 統合モニタリング（全情報）

### スクリプト: `comprehensive_monitor.sh`

```bash
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
```

### 実行方法

```bash
chmod +x comprehensive_monitor.sh
./comprehensive_monitor.sh

# Bundle ID入力
# IPA サイズ入力
# PlayCoverでIPAインストール（GUI操作）
# 完了したらEnterキー押下
```

---

## 📊 検証結果の送付

以下のファイルをすべて送付してください：

```bash
cd ~/playcover_verification_logs
tar -czf playcover_logs_$(date +%Y%m%d).tar.gz *.log comprehensive_*/

# アーカイブ作成完了
ls -lh playcover_logs_*.tar.gz
```

送付するもの：
- `playcover_logs_YYYYMMDD.tar.gz`

---

## 🎯 検証の重要性

これらのデータから以下を最適化できます：

1. **check_interval の調整**
   - CPU使用率の推移から最適な監視間隔を決定

2. **stability_threshold の調整**
   - mtime変更パターンから安定判定時間を最適化

3. **追加検知ロジックの必要性判断**
   - CPU監視が有効か
   - fswatch併用が必要か

4. **IPA サイズ別の検知戦略**
   - 小容量IPA（180MB）と大容量IPA（2-3GB）で異なるパラメータが必要か

---

## ✅ 検証チェックリスト

- [ ] fswatch によるファイルシステム変更トレース
- [ ] CPU/メモリ使用率の推移測定
- [ ] lsof によるファイルアクセス監視
- [ ] mtime 変更の詳細トラッキング
- [ ] 統合モニタリング（全情報）
- [ ] 小容量IPA（180MB）での検証
- [ ] 大容量IPA（2-3GB）での検証
- [ ] ログファイルの送付

各検証を**小容量IPA**と**大容量IPA**の両方で実施してください！
