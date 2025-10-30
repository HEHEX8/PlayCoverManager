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
    echo ""
    echo "This script will:"
    echo "  1. Test rsync transfer"
    echo "  2. Test cp transfer"
    echo "  3. Test ditto transfer"
    echo "  4. Test parallel cp transfer (xargs -P)"
    echo "  5. Compare results"
    exit 1
fi

SOURCE_DIR="$1"
DEST_BASE="$2"

# Validate source
if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "Error: Source directory does not exist: $SOURCE_DIR"
    exit 1
fi

# Create dest base
mkdir -p "$DEST_BASE"

# Count files
print_header "ソースディレクトリ分析"
FILE_COUNT=$(find "$SOURCE_DIR" -type f 2>/dev/null | wc -l | xargs)
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
        rm -rf "$dest_dir"
    fi
    
    mkdir -p "$dest_dir"
    
    # Run test
    echo "転送開始..."
    start_time=$(date +%s)
    
    case "$method" in
        "rsync")
            /usr/bin/rsync -avH --progress \
                --exclude='.DS_Store' \
                --exclude='.Spotlight-V100' \
                "$SOURCE_DIR/" "$dest_dir/" > /dev/null 2>&1
            ;;
        "cp")
            # Sequential cp
            find "$SOURCE_DIR" -type f ! -name '.DS_Store' 2>/dev/null | while IFS= read -r file; do
                rel_path="${file#$SOURCE_DIR/}"
                dest_file="$dest_dir/$rel_path"
                dest_subdir=$(dirname "$dest_file")
                mkdir -p "$dest_subdir" 2>/dev/null
                cp -p "$file" "$dest_file" 2>/dev/null
            done
            ;;
        "ditto")
            /usr/bin/ditto "$SOURCE_DIR/" "$dest_dir/" > /dev/null 2>&1
            ;;
        "parallel")
            # Parallel cp with xargs -P
            num_workers=$(sysctl -n hw.logicalcpu 2>/dev/null || echo 4)
            export SOURCE_DIR
            export dest_dir
            
            find "$SOURCE_DIR" -type f ! -name '.DS_Store' 2>/dev/null | \
                xargs -P "$num_workers" -I {} sh -c '
                    file="{}"
                    rel_path="${file#$SOURCE_DIR/}"
                    dest_file="$dest_dir/$rel_path"
                    dest_subdir=$(dirname "$dest_file")
                    mkdir -p "$dest_subdir" 2>/dev/null
                    cp -p "$file" "$dest_file" 2>/dev/null
                '
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

# Sort by time
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
    rm -rf "$DEST_BASE"
    echo "✅ 完了"
fi
