#!/bin/bash

#######################################################
# Quick Remount Script
# Remount existing volume from /Volumes/ to container path
#######################################################

set -e

# Color definitions
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

print_success() {
    echo "${GREEN}✓ $1${NC}"
}

print_error() {
    echo "${RED}✗ $1${NC}"
}

print_warning() {
    echo "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo "${BLUE}ℹ $1${NC}"
}

# Check arguments
if [[ $# -lt 2 ]]; then
    echo "使用方法: $0 <ボリューム名> <Bundle ID>"
    echo ""
    echo "例:"
    echo "  $0 ZenlessZoneZero com.HoYoverse.Nap"
    echo "  $0 HonkaiStarRail com.HoYoverse.hkrpgoversea"
    echo ""
    exit 1
fi

VOLUME_NAME="$1"
BUNDLE_ID="$2"
CONTAINER_PATH="${HOME}/Library/Containers/${BUNDLE_ID}"

echo ""
echo "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "${BLUE}  ボリューム再マウントスクリプト${NC}"
echo "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

print_info "ボリューム名: ${VOLUME_NAME}"
print_info "Bundle ID: ${BUNDLE_ID}"
print_info "マウント先: ${CONTAINER_PATH}"
echo ""

# Step 1: Check if volume exists at /Volumes/
if [[ ! -d "/Volumes/${VOLUME_NAME}" ]]; then
    print_error "ボリュームが見つかりません: /Volumes/${VOLUME_NAME}"
    exit 1
fi

print_success "ボリュームを発見: /Volumes/${VOLUME_NAME}"

# Step 2: Get device node
DEVICE=$(diskutil info "/Volumes/${VOLUME_NAME}" 2>/dev/null | grep "Device Node:" | awk '{print $NF}')

if [[ -z "$DEVICE" ]]; then
    print_error "デバイスノードの取得に失敗しました"
    exit 1
fi

print_info "デバイスノード: ${DEVICE}"

# Step 3: Unmount from /Volumes/
print_info "既存のマウントをアンマウント中..."
if sudo diskutil unmount "$DEVICE" 2>/dev/null; then
    print_success "アンマウント成功"
else
    print_warning "通常のアンマウントに失敗（強制アンマウントを試行）"
    if sudo umount -f "/Volumes/${VOLUME_NAME}" 2>/dev/null; then
        print_success "強制アンマウント成功"
    else
        print_error "アンマウントに失敗しました"
        exit 1
    fi
fi

# Step 4: Remove internal container if exists
if [[ -e "$CONTAINER_PATH" ]]; then
    print_warning "既存のコンテナパスが存在します: ${CONTAINER_PATH}"
    
    # Check if it's a mount point
    if mount | grep -q " on ${CONTAINER_PATH} "; then
        print_info "既にマウントされています（スキップ）"
        exit 0
    fi
    
    echo -n "削除しますか？ (y/n): "
    read remove_choice
    
    if [[ "$remove_choice" == "y" ]]; then
        print_info "コンテナパスを削除中..."
        sudo rm -rf "$CONTAINER_PATH"
        print_success "削除完了"
    else
        print_error "コンテナパスを削除せずに続行できません"
        exit 1
    fi
fi

# Step 5: Create mount point
print_info "マウントポイントを作成中..."
sudo mkdir -p "$CONTAINER_PATH"

# Step 6: Mount to container path
print_info "ボリュームをマウント中: ${DEVICE} → ${CONTAINER_PATH}"

if sudo mount -t apfs "$DEVICE" "$CONTAINER_PATH"; then
    print_success "マウント成功"
    
    # Verify
    if mount | grep -q " on ${CONTAINER_PATH} "; then
        print_success "マウント確認: OK"
        
        # Fix permissions
        sudo chown -R $(id -u):$(id -g) "$CONTAINER_PATH" 2>/dev/null || true
        
        echo ""
        print_success "すべての処理が完了しました"
        echo ""
        print_info "マウント情報:"
        mount | grep "$CONTAINER_PATH"
    else
        print_error "マウント検証に失敗しました"
        exit 1
    fi
else
    print_error "マウントに失敗しました"
    echo ""
    print_info "診断情報:"
    diskutil info "$DEVICE" 2>/dev/null | grep -E "(Volume Name|File System|Mount Point)"
    exit 1
fi

echo ""
