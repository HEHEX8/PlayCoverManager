#!/bin/zsh

echo "=== PlayCover 設定ファイル確認 ==="
echo ""

CONTAINER="${HOME}/Library/Containers/io.playcover.PlayCover"

# Keymapping
echo "【Keymapping ディレクトリ】"
KEYMAPPING_DIR="${CONTAINER}/Keymapping"
if [[ -d "$KEYMAPPING_DIR" ]]; then
    echo "✅ ディレクトリ存在: $KEYMAPPING_DIR"
    echo "   ファイル一覧:"
    ls -lh "$KEYMAPPING_DIR"
    echo ""
    
    # 原神のキーマッピング
    GENSHIN_KEYMAP="${KEYMAPPING_DIR}/com.miHoYo.GenshinImpact.plist"
    if [[ -f "$GENSHIN_KEYMAP" ]]; then
        echo "   原神キーマッピング内容:"
        plutil -p "$GENSHIN_KEYMAP" 2>/dev/null || cat "$GENSHIN_KEYMAP"
    else
        echo "   ⚠️ 原神のキーマッピングファイルなし"
    fi
else
    echo "❌ Keymapping ディレクトリが見つかりません"
fi

echo ""
echo "【Entitlements ディレクトリ】"
ENTITLEMENTS_DIR="${CONTAINER}/Entitlements"
if [[ -d "$ENTITLEMENTS_DIR" ]]; then
    echo "✅ ディレクトリ存在: $ENTITLEMENTS_DIR"
    echo "   ファイル一覧:"
    ls -lh "$ENTITLEMENTS_DIR"
    echo ""
    
    # 原神のエンタイトルメント
    GENSHIN_ENTITLE="${ENTITLEMENTS_DIR}/com.miHoYo.GenshinImpact.plist"
    if [[ -f "$GENSHIN_ENTITLE" ]]; then
        echo "   原神エンタイトルメント内容:"
        plutil -p "$GENSHIN_ENTITLE" 2>/dev/null || cat "$GENSHIN_ENTITLE"
    else
        echo "   ⚠️ 原神のエンタイトルメントファイルなし"
    fi
else
    echo "❌ Entitlements ディレクトリが見つかりません"
fi

echo ""
echo "【App Settings ディレクトリ】"
SETTINGS_DIR="${CONTAINER}/App Settings"
if [[ -d "$SETTINGS_DIR" ]]; then
    echo "✅ ディレクトリ存在: $SETTINGS_DIR"
    echo "   ファイル一覧:"
    ls -lh "$SETTINGS_DIR"
else
    echo "❌ App Settings ディレクトリが見つかりません"
fi

echo ""
echo "=== 完了 ==="
