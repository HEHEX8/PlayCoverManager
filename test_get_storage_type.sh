#!/bin/zsh

##########################################################
# Test get_storage_type function directly
# get_storage_type 関数を直接テスト
##########################################################

# Source the main script to get the function
source /Volumes/DATA/PlayCoverPortable/2_playcover-volume-manager.command

echo "=========================================="
echo "  get_storage_type() 関数テスト"
echo "=========================================="
echo ""

# Test paths
test_paths=(
    "/Users/hehex/Library/Containers/com.miHoYo.GenshinImpact"
    "/Users/hehex/Library/Containers/com.HoYoverse.hkrpgoversea"
    "/Users/hehex/Library/Containers/com.HoYoverse.zzz"
)

display_names=(
    "原神"
    "崩壊：スターレイル"
    "ゼンレスゾーンゼロ"
)

for i in {1..3}; do
    local path="${test_paths[$i]}"
    local name="${display_names[$i]}"
    
    echo "【テスト $i】$name"
    echo "  パス: $path"
    
    if [[ ! -e "$path" ]]; then
        echo "  結果: パスが存在しません"
        echo ""
        continue
    fi
    
    # Call get_storage_type with debug flag
    echo "  get_storage_type 実行中（デバッグモード）..."
    local result=$(get_storage_type "$path" true 2>&1)
    
    echo "$result" | while read line; do
        echo "    $line"
    done
    
    # Get final result
    local storage_type=$(get_storage_type "$path")
    echo ""
    echo "  最終結果: $storage_type"
    
    case "$storage_type" in
        "external")
            echo "  表示: 🔌 外部ストレージ"
            ;;
        "internal")
            echo "  表示: 💾 内蔵ストレージ"
            ;;
        "none")
            echo "  表示: ⚪ アンマウント済み"
            ;;
        *)
            echo "  表示: ❓ 不明 ($storage_type)"
            ;;
    esac
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
done

echo "テスト完了"
echo "=========================================="
