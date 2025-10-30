#!/bin/zsh
# PlayCover Manager Transfer Method Benchmark

print_header() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "$1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

print_result() {
    printf "%-20s: %s\n" "$1" "$2"
}

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <source_dir> <dest_base_dir>"
    exit 1
fi

SOURCE_DIR="$1"
DEST_BASE="$2"

if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "Error: Source directory does not exist: $SOURCE_DIR"
    exit 1
fi

# Clean dest
if [[ -d "$DEST_BASE" ]]; then
    echo "既存のベンチマークディレクトリを削除中..."
    rm -rf "$DEST_BASE" 2>/dev/null || sudo rm -rf "$DEST_BASE"
fi
mkdir -p "$DEST_BASE"

# Count files
print_header "ソースディレクトリ分析"
FILE_COUNT=$(find "$SOURCE_DIR" -type f \
    ! -path "*/.DS_Store" \
    ! -path "*/.Spotlight-V100/*" \
    ! -path "*/.fseventsd/*" \
    ! -path "*/.Trashes/*" \
    ! -path "*/.TemporaryItems/*" \
    2>/dev/null | wc -l | xargs)
SOURCE_SIZE=$(du -sh "$SOURCE_DIR" 2>/dev/null | awk '{print $1}')
print_result "ファイル数" "$FILE_COUNT"
print_result "データサイズ" "$SOURCE_SIZE"

declare -A results
declare -A file_counts
methods=("rsync" "ditto" "parallel")

for method in "${methods[@]}"; do
    dest_dir="$DEST_BASE/test_$method"
    
    print_header "テスト: $method"
    
    rm -rf "$dest_dir" 2>/dev/null || sudo rm -rf "$dest_dir"
    mkdir -p "$dest_dir"
    
    echo "転送開始..."
    start_time=$(date +%s)
    
    case "$method" in
        "rsync")
            /usr/bin/rsync -aH --quiet \
                --exclude='.DS_Store' \
                --exclude='.Spotlight-V100' \
                --exclude='.fseventsd' \
                --exclude='.Trashes' \
                --exclude='.TemporaryItems' \
                "$SOURCE_DIR/" "$dest_dir/"
            ;;
            
        "ditto")
            # dittoは特殊ファイルも含めてコピーするのでファイル数が多くなる
            /usr/bin/ditto "$SOURCE_DIR/" "$dest_dir/" 2>&1 | grep -i error || true
            ;;
            
        "parallel")
            num_workers=$(sysctl -n hw.logicalcpu 2>/dev/null || echo 4)
            echo "並列ワーカー数: $num_workers"
            
            # Create file list and split into chunks for workers
            temp_list="/tmp/benchmark_list_$$.txt"
            find "$SOURCE_DIR" -type f \
                ! -path "*/.DS_Store" \
                ! -path "*/.Spotlight-V100/*" \
                ! -path "*/.fseventsd/*" \
                ! -path "*/.Trashes/*" \
                ! -path "*/.TemporaryItems/*" \
                2>/dev/null > "$temp_list"
            
            total_files=$(wc -l < "$temp_list" | xargs)
            files_per_worker=$(( (total_files + num_workers - 1) / num_workers ))
            
            # Split file list and process in parallel
            split -l "$files_per_worker" "$temp_list" "/tmp/benchmark_split_$$_"
            
            for split_file in /tmp/benchmark_split_$$_*; do
                (
                    while IFS= read -r src; do
                        rel="${src#$SOURCE_DIR/}"
                        dst="$dest_dir/$rel"
                        dstdir=$(dirname "$dst")
                        mkdir -p "$dstdir" 2>/dev/null && cp -p "$src" "$dst" 2>/dev/null
                    done < "$split_file"
                ) &
            done
            
            # Wait for all workers to complete
            wait
            
            # Cleanup
            rm -f "$temp_list" /tmp/benchmark_split_$$_*
            ;;
    esac
    
    end_time=$(date +%s)
    elapsed=$((end_time - start_time))
    
    # Verify (dittoは特殊ファイルも含むので除外してカウント)
    if [[ "$method" == "ditto" ]]; then
        copied_files=$(find "$dest_dir" -type f \
            ! -path "*/.DS_Store" \
            ! -path "*/.Spotlight-V100/*" \
            ! -path "*/.fseventsd/*" \
            ! -path "*/.Trashes/*" \
            ! -path "*/.TemporaryItems/*" \
            2>/dev/null | wc -l | xargs)
    else
        copied_files=$(find "$dest_dir" -type f 2>/dev/null | wc -l | xargs)
    fi
    
    results[$method]=$elapsed
    file_counts[$method]=$copied_files
    
    print_result "処理時間" "${elapsed}秒"
    print_result "コピーファイル数" "$copied_files / $FILE_COUNT"
    
    if (( copied_files == FILE_COUNT )); then
        echo "✅ 転送成功"
    else
        diff=$((FILE_COUNT - copied_files))
        echo "⚠️  警告: ファイル数が一致しません（差分: $diff）"
    fi
done

# Summary
print_header "ベンチマーク結果サマリー"

echo "転送方法別の処理時間:"
echo ""

for method in "${methods[@]}"; do
    time=${results[$method]}
    files=${file_counts[$method]}
    success_rate=$(( files * 100 / FILE_COUNT ))
    printf "  %-10s: %3d秒 (%d/%d ファイル = %d%%)\n" \
        "$method" "$time" "$files" "$FILE_COUNT" "$success_rate"
done

echo ""

# Find fastest
fastest_method=""
fastest_time=999999
for method in "${methods[@]}"; do
    files=${file_counts[$method]}
    if (( files == FILE_COUNT )); then
        time=${results[$method]}
        if (( time < fastest_time )); then
            fastest_time=$time
            fastest_method=$method
        fi
    fi
done

if [[ -n "$fastest_method" ]]; then
    echo "🏆 最速: $fastest_method (${fastest_time}秒)"
else
    echo "⚠️  完全成功した方法がありません"
fi

# Cleanup
echo ""
read "cleanup?テストデータを削除しますか？ (y/n): "
if [[ "$cleanup" == "y" ]]; then
    echo "クリーンアップ中..."
    rm -rf "$DEST_BASE" 2>/dev/null || sudo rm -rf "$DEST_BASE"
    echo "✅ 完了"
fi
