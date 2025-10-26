#!/bin/zsh

echo "=== PlayCover 完全リセット手順 ==="
echo ""
echo "⚠️  警告: この操作により、すべてのPlayCoverアプリとデータが削除されます"
echo ""
echo "実行する場合は 'YES' と入力してください:"
read confirmation

if [[ "$confirmation" != "YES" ]]; then
    echo "❌ キャンセルされました"
    exit 0
fi

echo ""
echo "=== ステップ1: すべてのボリュームをアンマウント ==="
echo ""

# PlayCoverボリュームをアンマウント
PLAYCOVER_VOLUME="/Users/${USER}/Library/Containers/io.playcover.PlayCover"
if mount | grep -q "$PLAYCOVER_VOLUME"; then
    echo "PlayCoverボリュームをアンマウント中..."
    sudo umount "$PLAYCOVER_VOLUME" 2>/dev/null || diskutil unmount "$PLAYCOVER_VOLUME" 2>/dev/null
    if [[ $? -eq 0 ]]; then
        echo "✅ PlayCoverボリュームをアンマウントしました"
    else
        echo "⚠️  PlayCoverボリュームのアンマウントに失敗（既にアンマウント済み?）"
    fi
else
    echo "✓ PlayCoverボリュームは既にアンマウントされています"
fi

# アプリコンテナボリュームをアンマウント
APP_CONTAINERS=(
    "com.miHoYo.GenshinImpact"
    "com.HoYoverse.hkrpgoversea"
    "com.HoYoverse.Nap"
)

for container in "${APP_CONTAINERS[@]}"; do
    container_path="/Users/${USER}/Library/Containers/${container}"
    if mount | grep -q "$container_path"; then
        echo "アンマウント中: $container"
        sudo umount "$container_path" 2>/dev/null || diskutil unmount "$container_path" 2>/dev/null
        if [[ $? -eq 0 ]]; then
            echo "  ✅ アンマウント完了"
        else
            echo "  ⚠️  アンマウント失敗"
        fi
    else
        echo "  ✓ $container は既にアンマウント済み"
    fi
done

echo ""
echo "少し待機します（ファイルシステムの同期）..."
sleep 3

echo ""
echo "=== ステップ2: すべてのコンテナを完全削除 ==="
echo ""

# PlayCoverコンテナを削除
if [[ -d "$PLAYCOVER_VOLUME" ]]; then
    echo "PlayCoverコンテナを削除中..."
    sudo rm -rf "$PLAYCOVER_VOLUME"
    if [[ $? -eq 0 ]]; then
        echo "✅ PlayCoverコンテナ削除完了"
    else
        echo "❌ 削除失敗: Resource busy の可能性あり"
        echo "   PlayCoverアプリを完全に終了してから再試行してください"
        exit 1
    fi
else
    echo "✓ PlayCoverコンテナは既に削除されています"
fi

# アプリコンテナを削除
for container in "${APP_CONTAINERS[@]}"; do
    container_path="/Users/${USER}/Library/Containers/${container}"
    if [[ -d "$container_path" ]]; then
        echo "削除中: $container"
        sudo rm -rf "$container_path"
        if [[ $? -eq 0 ]]; then
            echo "  ✅ 削除完了"
        else
            echo "  ❌ 削除失敗"
        fi
    else
        echo "  ✓ $container は既に削除されています"
    fi
done

echo ""
echo "=== ステップ3: PlayCoverのキャッシュとプリファレンスを削除 ==="
echo ""

# キャッシュを削除
CACHE_DIR="${HOME}/Library/Caches/io.playcover.PlayCover"
if [[ -d "$CACHE_DIR" ]]; then
    echo "キャッシュを削除中..."
    rm -rf "$CACHE_DIR"
    echo "✅ キャッシュ削除完了"
else
    echo "✓ キャッシュは既に削除されています"
fi

# Saved Application Stateを削除
SAVED_STATE="${HOME}/Library/Saved Application State/io.playcover.PlayCover.savedState"
if [[ -d "$SAVED_STATE" ]]; then
    echo "保存された状態を削除中..."
    rm -rf "$SAVED_STATE"
    echo "✅ 保存状態削除完了"
else
    echo "✓ 保存状態は既に削除されています"
fi

# プリファレンスを削除
PREFS="${HOME}/Library/Preferences/io.playcover.PlayCover.plist"
if [[ -f "$PREFS" ]]; then
    echo "環境設定を削除中..."
    rm -f "$PREFS"
    echo "✅ 環境設定削除完了"
else
    echo "✓ 環境設定は既に削除されています"
fi

# ログを削除
LOG_DIR="${HOME}/Library/Logs/PlayCover"
if [[ -d "$LOG_DIR" ]]; then
    echo "ログを削除中..."
    rm -rf "$LOG_DIR"
    echo "✅ ログ削除完了"
else
    echo "✓ ログは既に削除されています"
fi

echo ""
echo "=== ステップ4: APFSボリュームの確認と削除 ==="
echo ""

# diskutilでPlayCover関連のボリュームを確認
echo "APFS ボリュームを確認中..."
PLAYCOVER_VOLUMES=$(diskutil list | grep -i "playcover\|genshin\|hkrpg\|nap")

if [[ -n "$PLAYCOVER_VOLUMES" ]]; then
    echo "発見されたPlayCover関連ボリューム:"
    echo "$PLAYCOVER_VOLUMES"
    echo ""
    echo "⚠️  これらのボリュームを削除しますか? (YES/NO):"
    read delete_volumes
    
    if [[ "$delete_volumes" == "YES" ]]; then
        # ボリューム削除は手動で行う（慎重を期すため）
        echo "以下のコマンドを手動で実行してください:"
        echo "$PLAYCOVER_VOLUMES" | while read line; do
            volume_id=$(echo "$line" | awk '{print $NF}')
            if [[ -n "$volume_id" ]] && [[ "$volume_id" =~ disk[0-9]+s[0-9]+ ]]; then
                echo "  sudo diskutil apfs deleteVolume $volume_id"
            fi
        done
    fi
else
    echo "✓ PlayCover関連のAPFSボリュームは見つかりませんでした"
fi

echo ""
echo "=== 完全リセット完了 ==="
echo ""
echo "次のステップ:"
echo "1. PlayCoverアプリを起動"
echo "2. 必要に応じて初期設定を行う"
echo "3. IPAファイルを再インストール"
echo ""
echo "⚠️  注意事項:"
echo "- 初回インストール時にPlayCoverがクラッシュする場合があります"
echo "- その場合は、PlayCoverを再起動して再度IPAをインストールしてください"
echo "- ゲームデータはmiHoYoアカウントに紐付いているため、再ログインすれば復元されます"
