#!/bin/zsh
# PlayCover Manager Transfer Method Benchmark
# Compares rsync, cp, ditto, and parallel transfer methods

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

# Check arguments
if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <source_dir> <dest_base_dir>"
    echo ""
    echo "Example: $0 /Volumes/External/data /tmp/benchmark"
    exit 1
fi

SOURCE_DIR="$1"
DEST_BASE="$2"

# Validate source
if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "Error: Source directory does not exist: $SOURCE_DIR"
    exit 1
fi

# Clean dest base
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

# Test methods
declare -A results
declare -A file_counts
methods=("rsync" "ditto" "parallel")

for method in "${methods[@]}"; do
    dest_dir="$DEST_BASE/test_$method"
    
    print_header "テスト: $method"
    
    # Clean previous test
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
            /usr/bin/ditto "$SOURCE_DIR/" "$dest_dir/" 2>&1 | grep -i error || true
            ;;
            
        "parallel")
            num_workers=$(sysctl -n hw.logicalcpu 2>/dev/null || echo 4)
            echo "並列ワーカー数: $num_workers"
            
            # Create file list without special directories
            temp_list="/tmp/benchmark_list_$$.txt"
            find "$SOURCE_DIR" -type f \
                ! -path "*/.DS_Store" \
                ! -path "*/.Spotlight-V100/*" \
                ! -path "*/.fseventsd/*" \
                ! -path "*/.Trashes/*" \
                ! -path "*/.TemporaryItems/*" \
                2>/dev/null > "$temp_list"
            
            # Use xargs for parallel copy
            cat "$temp_list" | xargs -P "$num_workers" -I SRCFILE sh -c '
                src="SRCFILE"
                rel="${src#'"$SOURCE_DIR"'/}"
                dst="'"$dest_dir"'/$rel"
                dstdir=$(dirname "$dst")
                mkdir -p "$dstdir" && cp -p "$src" "$dst"
            ' 2>&1 | head -20 || true
            
            rm -f "$temp_list"
            ;;
    esac
    
    end_time=$(date +%s)
    elapsed=$((end_time - start_time))
    
    # Verify results
    copied_files=$(find "$dest_dir" -type f 2>/dev/null | wc -l | xargs)
    
    results[$method]=$elapsed
    file_counts[$method]=$copied_files
    
    print_result "処理時間" "${elapsed}秒"
    print_result "コピーファイル数" "$copied_files / $FILE_COUNT"
    
    if (( copied_files == FILE_COUNT )); then
        echo "✅ 転送成功"
    else
        echo "⚠️  警告: ファイル数が一致しません（差分: $((FILE_COUNT - copied_files))）"
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

# Find fastest among successful methods
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
    echo "⚠️  全ての方法で失敗しました"
fi

# Cleanup
echo ""
read "cleanup?テストデータを削除しますか？ (y/n): "
if [[ "$cleanup" == "y" ]]; then
    echo "クリーンアップ中..."
    rm -rf "$DEST_BASE" 2>/dev/null || sudo rm -rf "$DEST_BASE"
    echo "✅ 完了"
fi
