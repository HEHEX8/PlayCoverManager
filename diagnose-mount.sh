#!/bin/bash

# Diagnosis Script for Mount Issues

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  マウント診断スクリプト"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

BUNDLE_ID="com.HoYoverse.hkrpgoversea"
VOLUME_NAME="HonkaiStarRail"
CONTAINER_PATH="${HOME}/Library/Containers/${BUNDLE_ID}"

echo "▼ 1. コンテナディレクトリの状態確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ -e "$CONTAINER_PATH" ]]; then
    echo "✓ コンテナパスが存在します: $CONTAINER_PATH"
    echo ""
    echo "  タイプ:"
    ls -ld "$CONTAINER_PATH"
    echo ""
    echo "  内容:"
    ls -la "$CONTAINER_PATH" 2>/dev/null | head -20
    echo ""
    echo "  マウント状態:"
    mount | grep "$CONTAINER_PATH" || echo "  (マウントされていません)"
else
    echo "✗ コンテナパスが存在しません: $CONTAINER_PATH"
fi
echo ""

echo "▼ 2. ボリュームの状態確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ボリューム名: $VOLUME_NAME"
echo ""
diskutil list | grep -A 2 -B 2 "$VOLUME_NAME" || echo "  (diskutil list で見つかりません)"
echo ""

echo "▼ 3. ボリュームデバイスの特定"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
VOLUME_DEVICE=$(diskutil list 2>/dev/null | grep -E "${VOLUME_NAME}.*APFS" | head -n 1 | awk '{print $NF}')
if [[ -n "$VOLUME_DEVICE" ]]; then
    echo "✓ ボリュームデバイス: /dev/$VOLUME_DEVICE"
    echo ""
    echo "  詳細情報:"
    diskutil info "/dev/$VOLUME_DEVICE" 2>/dev/null | grep -E "(Volume Name|Mount Point|File System|Bootable|Encrypted)" || echo "  (情報取得失敗)"
else
    echo "✗ ボリュームデバイスが見つかりません"
fi
echo ""

echo "▼ 4. 現在のマウント状態"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
mount | grep -i "$VOLUME_NAME" || echo "  (ボリュームはマウントされていません)"
echo ""

echo "▼ 5. 全ディスクの APFS 構成"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
diskutil apfs list | grep -A 10 "$VOLUME_NAME" || echo "  (APFS リストで見つかりません)"
echo ""

echo "▼ 6. テストマウントの試行"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ -n "$VOLUME_DEVICE" ]]; then
    TEST_MOUNT=$(mktemp -d)
    echo "  テストマウント先: $TEST_MOUNT"
    echo ""
    
    echo "  [試行 1] sudo mount -t apfs /dev/$VOLUME_DEVICE $TEST_MOUNT"
    if sudo mount -t apfs "/dev/$VOLUME_DEVICE" "$TEST_MOUNT" 2>&1; then
        echo "  ✓ マウント成功"
        echo ""
        echo "  内容:"
        ls -la "$TEST_MOUNT" 2>/dev/null | head -10
        echo ""
        sudo umount "$TEST_MOUNT" 2>/dev/null
        echo "  ✓ アンマウント成功"
    else
        echo "  ✗ マウント失敗"
    fi
    echo ""
    
    rmdir "$TEST_MOUNT" 2>/dev/null || true
else
    echo "  (ボリュームデバイスが不明なためスキップ)"
fi

echo "▼ 7. 推奨される対処法"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ -e "$CONTAINER_PATH" ]] && [[ ! $(mount | grep "$CONTAINER_PATH") ]]; then
    echo "⚠ 内蔵コンテナディレクトリが既に存在しています"
    echo ""
    echo "  対処法:"
    echo "  1. 内蔵コンテナを削除してから外部ボリュームをマウント"
    echo "     $ sudo rm -rf \"$CONTAINER_PATH\""
    echo "     $ sudo mount -t apfs /dev/$VOLUME_DEVICE \"$CONTAINER_PATH\""
    echo ""
    echo "  2. または、内蔵コンテナをリネームしてバックアップ"
    echo "     $ sudo mv \"$CONTAINER_PATH\" \"${CONTAINER_PATH}.backup\""
    echo "     $ sudo mount -t apfs /dev/$VOLUME_DEVICE \"$CONTAINER_PATH\""
fi

if [[ -n "$VOLUME_DEVICE" ]]; then
    MOUNT_POINT=$(diskutil info "/dev/$VOLUME_DEVICE" 2>/dev/null | grep "Mount Point:" | awk -F: '{print $2}' | xargs)
    if [[ -n "$MOUNT_POINT" ]]; then
        echo "⚠ ボリュームが既に他の場所にマウントされています: $MOUNT_POINT"
        echo ""
        echo "  対処法:"
        echo "  1. 現在のマウントをアンマウント"
        echo "     $ sudo umount \"$MOUNT_POINT\""
        echo "     $ sudo mount -t apfs /dev/$VOLUME_DEVICE \"$CONTAINER_PATH\""
    fi
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  診断完了"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
