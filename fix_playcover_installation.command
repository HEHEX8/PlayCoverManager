#!/bin/zsh

echo "=== PlayCover 完全再インストール手順 ==="
echo ""
echo "⚠️  警告: この手順を実行すると、PlayCoverとすべてのアプリが削除されます"
echo "アプリのIPAファイルをバックアップしていることを確認してください"
echo ""
echo "実行する場合は 'YES' と入力してください:"
read confirmation

if [[ "$confirmation" != "YES" ]]; then
    echo "❌ キャンセルされました"
    exit 0
fi

echo ""
echo "=== ステップ1: PlayCoverの完全削除 ==="
echo ""

# PlayCoverアプリケーション本体を削除
if [[ -d "/Applications/PlayCover.app" ]]; then
    echo "PlayCover.app を削除中..."
    sudo rm -rf /Applications/PlayCover.app
    echo "✅ PlayCover.app 削除完了"
else
    echo "⚠️  PlayCover.app が見つかりません（既に削除済み?）"
fi

# PlayCoverコンテナを削除
PLAYCOVER_CONTAINER="${HOME}/Library/Containers/io.playcover.PlayCover"
if [[ -d "$PLAYCOVER_CONTAINER" ]]; then
    echo ""
    echo "PlayCoverコンテナを削除中..."
    echo "削除対象: $PLAYCOVER_CONTAINER"
    rm -rf "$PLAYCOVER_CONTAINER"
    echo "✅ PlayCoverコンテナ削除完了"
else
    echo "⚠️  PlayCoverコンテナが見つかりません"
fi

# キャッシュとログを削除
echo ""
echo "キャッシュとログを削除中..."
rm -rf "${HOME}/Library/Caches/io.playcover.PlayCover" 2>/dev/null
rm -rf "${HOME}/Library/Logs/PlayCover" 2>/dev/null
rm -rf "${HOME}/Library/Preferences/io.playcover.PlayCover.plist" 2>/dev/null
echo "✅ キャッシュとログ削除完了"

echo ""
echo "=== ステップ2: PlayCover最新版のダウンロード ==="
echo ""
echo "以下のURLから最新版のPlayCoverをダウンロードしてください:"
echo "https://github.com/PlayCover/PlayCover/releases/latest"
echo ""
echo "ダウンロードファイル: PlayCover_3.1.0.dmg (または最新版)"
echo ""
echo "ダウンロードが完了したら、Enterキーを押してください..."
read

echo ""
echo "=== ステップ3: PlayCoverのインストール確認 ==="
echo ""

if [[ ! -d "/Applications/PlayCover.app" ]]; then
    echo "❌ PlayCover.app がインストールされていません"
    echo ""
    echo "手動でインストールしてください:"
    echo "1. ダウンロードした PlayCover_3.1.0.dmg をダブルクリック"
    echo "2. PlayCover.app を Applications フォルダにドラッグ"
    echo "3. インストール完了後、このスクリプトを再実行してください"
    exit 1
fi

echo "✅ PlayCover.app が見つかりました"
echo ""

# PlayTools.frameworkの存在確認
PLAYTOOLS_PATHS=(
    "/Applications/PlayCover.app/Contents/Frameworks/PlayTools.framework"
    "/Applications/PlayCover.app/Contents/Resources/PlayTools.framework"
    "/Applications/PlayCover.app/Contents/PlugIns/PlayTools.framework"
)

PLAYTOOLS_FOUND=false
for path in "${PLAYTOOLS_PATHS[@]}"; do
    if [[ -d "$path" ]]; then
        echo "✅ PlayTools.framework 発見: $path"
        PLAYTOOLS_FOUND=true
        
        # バージョン確認
        if [[ -f "$path/Versions/A/Resources/Info.plist" ]]; then
            echo "   バージョン:"
            plutil -p "$path/Versions/A/Resources/Info.plist" | grep -E "CFBundleShortVersionString|CFBundleVersion"
        elif [[ -f "$path/Resources/Info.plist" ]]; then
            echo "   バージョン:"
            plutil -p "$path/Resources/Info.plist" | grep -E "CFBundleShortVersionString|CFBundleVersion"
        fi
        break
    fi
done

if [[ "$PLAYTOOLS_FOUND" == "false" ]]; then
    echo "❌ PlayTools.framework が見つかりません"
    echo "PlayCoverのインストールが破損しています"
    echo ""
    echo "以下を試してください:"
    echo "1. PlayCover.app を完全に削除"
    echo "2. 公式GitHubから最新版を再ダウンロード"
    echo "3. ダウンロードファイルのSHA256ハッシュを確認"
    exit 1
fi

echo ""
echo "=== ステップ4: PlayCoverの初回起動 ==="
echo ""
echo "PlayCover.app を起動して、初期セットアップを完了してください"
echo ""
echo "初期セットアップで必要な操作:"
echo "1. PlayCoverを起動"
echo "2. macOSの「開く」警告が表示された場合は許可"
echo "3. 必要に応じてアクセシビリティ権限を付与"
echo "4. PlayCoverのメインウィンドウが表示されることを確認"
echo ""
echo "初期セットアップが完了したら、Enterキーを押してください..."
read

echo ""
echo "=== ステップ5: 最終確認 ==="
echo ""

# PlayCoverコンテナが作成されたか確認
if [[ -d "${HOME}/Library/Containers/io.playcover.PlayCover" ]]; then
    echo "✅ PlayCoverコンテナが作成されました"
    echo "   場所: ${HOME}/Library/Containers/io.playcover.PlayCover"
    
    # 必要なディレクトリが存在するか確認
    for dir in "Applications" "App Settings" "Entitlements" "Keymapping"; do
        dir_path="${HOME}/Library/Containers/io.playcover.PlayCover/${dir}"
        if [[ -d "$dir_path" ]]; then
            echo "   ✅ ${dir} ディレクトリ存在"
        else
            echo "   ⚠️  ${dir} ディレクトリが作成されていません（アプリインストール時に自動作成されます）"
        fi
    done
else
    echo "⚠️  PlayCoverコンテナがまだ作成されていません"
    echo "PlayCoverを一度起動してください"
fi

echo ""
echo "=== 完了 ==="
echo ""
echo "次のステップ:"
echo "1. PlayCoverで原神のIPAファイルを再インストール"
echo "2. アプリの設定（解像度、キーマッピングなど）を再設定"
echo "3. アプリを起動してクラッシュが解決したか確認"
echo ""
echo "再インストール後もクラッシュが発生する場合は、以下を確認してください:"
echo "- IPAファイルが破損していないか"
echo "- macOS 26 Tahoe に対応したPlayCoverバージョンか（GitHub issuesを確認）"
echo "- システムのアクセシビリティ権限が正しく付与されているか"
