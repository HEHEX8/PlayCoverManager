#!/bin/zsh
# PlayCover Manager Transfer Method Benchmark
# Compares rsync, cp, ditto, and parallel transfer methods

set -e

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

# Clean and create dest base
if [[ -d "$DEST_BASE" ]]; then
    echo "既存のベンチマークディレクトリを削除中..."
    chflags -R nouchg,nouappnd "$DEST_BASE" 2>/dev/null || true
    chmod -R u+w "$DEST_BASE" 2>/dev/null || true
    rm -rf "$DEST_BASE" 2>/dev/null || sudo rm -rf "$DEST_BASE"
fi

mkdir -p "$DEST_BASE"

# Count files (excluding special directories)
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
methods=("rsync" "cp" "ditto" "parallel")

for method in "${methods[@]}"; do
    dest_dir="$DEST_BASE/test_$method"
    
    print_header "テスト: $method"
    
    # Clean previous test
    if [[ -d "$dest_dir" ]]; then
        echo "前回のテストデータを削除中..."
        chflags -R nouchg,nouappnd "$dest_dir" 2>/dev/null || true
        chmod -R u+w "$dest_dir" 2>/dev/null || true
        rm -rf "$dest_dir" 2>/dev/null || sudo rm -rf "$dest_dir"
    fi
    
    mkdir -p "$dest_dir"
    
    # Run test
    echo "転送開始..."
    start_time=$(date +%s)
    
    case "$method" in
        "rsync")
            /usr/bin/rsync -aH \
                --exclude='.DS_Store' \
                --exclude='.Spotlight-V100' \
                --exclude='.fseventsd' \
                --exclude='.Trashes' \
                --exclude='.TemporaryItems' \
                "$SOURCE_DIR/" "$dest_dir/" >/dev/null 2>&1
            ;;
            
        "cp")
            # Use tar pipe for reliable file copy
            (cd "$SOURCE_DIR" && tar cf - \
                --exclude '.DS_Store' \
                --exclude '.Spotlight-V100' \
                --exclude '.fseventsd' \
                --exclude '.Trashes' \
                --exclude '.TemporaryItems' \
                . ) | (cd "$dest_dir" && tar xf - ) 2>/dev/null
            ;;
            
        "ditto")
            /usr/bin/ditto "$SOURCE_DIR/" "$dest_dir/" >/dev/null 2>&1
            ;;
            
        "parallel")
            # Parallel cp with xargs -P
            num_workers=$(sysctl -n hw.logicalcpu 2>/dev/null || echo 4)
            echo "並列ワーカー数: $num_workers"
            
            find "$SOURCE_DIR" -type f \
                ! -path "*/.DS_Store" \
                ! -path "*/.Spotlight-V100/*" \
                ! -path "*/.fseventsd/*" \
                ! -path "*/.Trashes/*" \
                ! -path "*/.TemporaryItems/*" \
                -print0 2>/dev/null | \
            xargs -0 -P "$num_workers" -I {} sh -c '
                src="$1"
                rel="${src#'"$SOURCE_DIR"'/}"
                dst="'"$dest_dir"'/$rel"
                dir=$(dirname "$dst")
                mkdir -p "$dir" 2>/dev/null && cp -p "$src" "$dst" 2>/dev/null
            ' _ {} >/dev/null 2>&1
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
        echo "⚠️  警告: ファイル数が一致しません"
    fi
done

# Summary
print_header "ベンチマーク結果サマリー"

echo "転送方法別の処理時間:"
echo ""

for method in "${methods[@]}"; do
    time=${results[$method]}
    files=${file_counts[$method]}
    printf "  %-10s: %3d秒 (%d/%d ファイル)\n" "$method" "$time" "$files" "$FILE_COUNT"
done

echo ""

# Find fastest
fastest_method=""
fastest_time=999999
for method in "${methods[@]}"; do
    time=${results[$method]}
    if (( time < fastest_time )); then
        fastest_time=$time
        fastest_method=$method
    fi
done

echo "🏆 最速: $fastest_method (${fastest_time}秒)"

# Cleanup
echo ""
read "cleanup?テストデータを削除しますか？ (y/n): "
if [[ "$cleanup" == "y" ]]; then
    echo "クリーンアップ中..."
    chflags -R nouchg,nouappnd "$DEST_BASE" 2>/dev/null || true
    chmod -R u+w "$DEST_BASE" 2>/dev/null || true
    rm -rf "$DEST_BASE" 2>/dev/null || sudo rm -rf "$DEST_BASE"
    echo "✅ 完了"
fi
