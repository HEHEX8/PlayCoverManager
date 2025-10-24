#!/bin/zsh

# Debug version to check disk detection

echo "=== ディスク検出デバッグ ==="
echo ""

# Get root volume's physical disk identifier
root_device=$(diskutil info / | grep "Device Node:" | awk '{print $3}')
internal_disk=$(echo "$root_device" | sed -E 's/disk([0-9]+).*/disk\1/')

echo "ルートデバイス: $root_device"
echo "内蔵ディスク識別子: $internal_disk"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get unique physical disk identifiers from diskutil list
declare -a seen_disks
disk_count=0

while IFS= read -r line; do
    # Match lines like "/dev/disk0 (internal, physical):"
    if [[ "$line" =~ ^/dev/disk[0-9]+ ]]; then
        disk_id=$(echo "$line" | sed -E 's|^/dev/(disk[0-9]+).*|\1|')
        full_line="$line"
        
        echo "検出: /dev/$disk_id"
        echo "  フルライン: $full_line"
        
        # Skip if already processed (avoid duplicates)
        already_seen=false
        for seen in "${seen_disks[@]}"; do
            if [[ "$seen" == "$disk_id" ]]; then
                already_seen=true
                break
            fi
        done
        
        if $already_seen; then
            echo "  → スキップ: 重複"
            echo ""
            continue
        fi
        
        seen_disks+=("$disk_id")
        
        # Check if this is internal storage
        if [[ "$disk_id" == "$internal_disk" ]]; then
            echo "  → スキップ: 内蔵ストレージ ($internal_disk と一致)"
            echo ""
            continue
        fi
        
        # Skip if marked as internal
        if [[ "$full_line" =~ "internal" ]]; then
            echo "  → スキップ: 'internal' フラグ検出"
            echo ""
            continue
        fi
        
        # Get disk information
        echo "  詳細情報を取得中..."
        device_name=$(diskutil info "/dev/$disk_id" | grep "Device / Media Name:" | sed 's/.*: *//')
        total_size=$(diskutil info "/dev/$disk_id" | grep "Disk Size:" | sed 's/.*: *//' | awk '{print $1, $2}')
        is_removable=$(diskutil info "/dev/$disk_id" | grep "Removable Media:" | grep "Yes")
        protocol=$(diskutil info "/dev/$disk_id" | grep "Protocol:" | sed 's/.*: *//')
        location=$(diskutil info "/dev/$disk_id" | grep "Device Location:" | sed 's/.*: *//')
        
        echo "    デバイス名: ${device_name:-なし}"
        echo "    サイズ: ${total_size:-なし}"
        echo "    リムーバブル: ${is_removable:-No}"
        echo "    プロトコル: ${protocol:-なし}"
        echo "    ロケーション: ${location:-なし}"
        
        # Skip if couldn't get device name or size
        if [[ -z "$device_name" ]] || [[ -z "$total_size" ]]; then
            echo "  → スキップ: デバイス名またはサイズが取得できません"
            echo ""
            continue
        fi
        
        # Check conditions
        echo "  判定条件:"
        echo "    - リムーバブルメディア: $([ -n "$is_removable" ] && echo 'Yes' || echo 'No')"
        echo "    - プロトコル一致: $([ -n "$protocol" ] && [[ "$protocol" =~ (USB|Thunderbolt|PCI-Express) ]] && echo 'Yes' || echo 'No')"
        echo "    - 外部ロケーション: $([ -n "$location" ] && [[ "$location" =~ External ]] && echo 'Yes' || echo 'No')"
        
        # Include disk if:
        if [[ -n "$is_removable" ]] || \
           [[ "$protocol" =~ (USB|Thunderbolt|PCI-Express) ]] || \
           [[ "$location" =~ External ]]; then
            echo "  ✓ 外部ストレージとして認識"
            ((disk_count++))
        else
            echo "  → スキップ: 外部ストレージの条件に合致しません"
        fi
        
        echo ""
    fi
done < <(diskutil list)

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "検出された外部ストレージ数: $disk_count"
echo ""

if [[ $disk_count -eq 0 ]]; then
    echo "=== diskutil info の完全出力 (全ディスク) ==="
    echo ""
    for disk in disk{0..9}; do
        if diskutil info "/dev/$disk" >/dev/null 2>&1; then
            echo "--- /dev/$disk ---"
            diskutil info "/dev/$disk" | grep -E "(Device|Protocol|Location|Removable|Media|Size)"
            echo ""
        fi
    done
fi
