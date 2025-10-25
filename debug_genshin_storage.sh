#!/bin/zsh

##########################################################
# Genshin Impact Storage Type Debug Script
# 原神のストレージタイプ検出をデバッグ
##########################################################

echo "=========================================="
echo "  原神ストレージタイプ診断"
echo "=========================================="
echo ""

path="/Users/hehex/Library/Containers/com.miHoYo.GenshinImpact"

# Step 1: Check if path exists
echo "【Step 1】パスの存在確認"
if [[ ! -e "$path" ]]; then
    echo "  ❌ パスが存在しません: $path"
    exit 1
else
    echo "  ✓ パスが存在します"
fi
echo ""

# Step 2: Check if it's a mount point
echo "【Step 2】マウントポイント確認"
mount_check=$(/sbin/mount | /usr/bin/grep " on ${path} ")
if [[ -n "$mount_check" ]]; then
    echo "  ✓ マウントポイントです（外部ストレージ）"
    echo "  マウント情報: $mount_check"
    echo ""
    echo "🔌 判定結果: 外部ストレージ"
    exit 0
else
    echo "  ✓ マウントポイントではありません"
fi
echo ""

# Step 3: Check directory content
echo "【Step 3】ディレクトリコンテンツ確認"
if [[ ! -d "$path" ]]; then
    echo "  ❌ ディレクトリではありません"
    exit 1
fi

echo "  生のls -A1出力（1行ずつ）:"
/bin/ls -A1 "$path" | while read line; do
    echo "    - $line"
done
echo ""

# Store raw list for later use (use -A1 to ensure one item per line)
raw_list=$(/bin/ls -A1 "$path" 2>/dev/null)
echo "  [DEBUG] Raw list captured: $(echo "$raw_list" | wc -l | xargs) items"
echo ""

echo "  フィルタリング処理:"
echo "    除外対象:"
echo "      - .DS_Store"
echo "      - .Spotlight-V100"
echo "      - .Trashes"
echo "      - .fseventsd"
echo "      - .TemporaryItems"
echo "      - .com.apple.containermanagerd.metadata.plist"
echo ""

content_check=$(echo "$raw_list" | \
    /usr/bin/grep -v -x -F '.DS_Store' | \
    /usr/bin/grep -v -x -F '.Spotlight-V100' | \
    /usr/bin/grep -v -x -F '.Trashes' | \
    /usr/bin/grep -v -x -F '.fseventsd' | \
    /usr/bin/grep -v -x -F '.TemporaryItems' | \
    /usr/bin/grep -v -F '.com.apple.containermanagerd.metadata.plist')

echo "  [DEBUG] After filtering: $(echo "$content_check" | grep -v '^$' | wc -l | xargs) items"
echo ""

echo "  フィルタリング後のコンテンツ:"
if [[ -z "$content_check" ]]; then
    echo "    （空 - メタデータのみ）"
    echo ""
    echo "⚪ 判定結果: アンマウント済み（データなし）"
    echo ""
    echo "【詳細】"
    echo "  生のリスト内容:"
    echo "$raw_list" | while read line; do
        echo "    - '$line'"
    done
    exit 0
else
    echo "$content_check" | while read line; do
        [[ -n "$line" ]] && echo "    - $line"
    done
fi
echo ""

# Step 4: Check disk location
echo "【Step 4】ディスク位置確認"
device=$(/bin/df "$path" | /usr/bin/tail -1 | /usr/bin/awk '{print $1}')
disk_id=$(echo "$device" | /usr/bin/sed -E 's|/dev/(disk[0-9]+).*|\1|')
echo "  デバイス: $device"
echo "  ディスクID: $disk_id"

disk_location=$(diskutil info "/dev/$disk_id" 2>/dev/null | /usr/bin/grep "Device Location:" | /usr/bin/awk -F: '{print $2}' | /usr/bin/sed 's/^ *//')
echo "  ディスク位置: $disk_location"
echo ""

# Final determination
echo "【最終判定】"
if [[ "$disk_location" == "Internal" ]]; then
    echo "  💾 判定結果: 内蔵ストレージ"
elif [[ "$disk_location" == "External" ]]; then
    echo "  🔌 判定結果: 外部ストレージ"
else
    if [[ "$disk_id" == "disk0" ]] || [[ "$disk_id" == "disk1" ]] || [[ "$disk_id" == "disk3" ]]; then
        echo "  💾 判定結果: 内蔵ストレージ（フォールバック）"
    else
        echo "  🔌 判定結果: 外部ストレージ（フォールバック）"
    fi
fi
echo ""
echo "=========================================="
