#!/bin/bash

# Diagnosis Script for Volume Creation

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ボリューム作成診断スクリプト"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

VOLUME_NAME="ZenlessZoneZero"

echo "▼ 1. diskutil list での検索"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "検索パターン: ${VOLUME_NAME}.*APFS"
echo ""
diskutil list | grep -E "${VOLUME_NAME}.*APFS"
echo ""
echo "抽出されたデバイス:"
diskutil list | grep -E "${VOLUME_NAME}.*APFS" | head -n 1 | awk '{print $NF}'
echo ""

echo "▼ 2. 完全な diskutil list 出力（ZenlessZoneZero 関連）"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
diskutil list | grep -i "zenless"
echo ""

echo "▼ 3. diskutil list disk5（想定コンテナ）"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
diskutil list disk5
echo ""

echo "▼ 4. mount コマンドでの確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
mount | grep -i "zenless"
echo ""

echo "▼ 5. /Volumes/ ディレクトリの確認"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ls -la /Volumes/ | grep -i "zenless"
echo ""

echo "▼ 6. diskutil info /Volumes/ZenlessZoneZero"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
diskutil info "/Volumes/ZenlessZoneZero" 2>/dev/null | grep -E "(Volume Name|Device Node|File System|Mount Point)"
echo ""

echo "▼ 7. diskutil apfs list での検索"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
diskutil apfs list | grep -A 10 "ZenlessZoneZero"
echo ""

echo "▼ 8. 推奨される修正"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "スクリプトの検索ロジックを改善する必要があります:"
echo ""
echo "現在の方法:"
echo "  diskutil list | grep -E \"\${APP_VOLUME_NAME}.*APFS\" | awk '{print \$NF}'"
echo ""
echo "改善案:"
echo "  1. diskutil info /Volumes/\$VOLUME_NAME でデバイスノードを取得"
echo "  2. diskutil list を行ごと解析して正確にマッチング"
echo "  3. diskutil apfs list で APFS ボリューム一覧から検索"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  診断完了"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
