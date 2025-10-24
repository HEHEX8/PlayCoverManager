# v1.1.0 テスト手順書

## 現在の状況

- **ボリューム**: `ZenlessZoneZero` が `/Volumes/ZenlessZoneZero` にマウント済み
- **アプリ**: Zenless Zone Zero (Bundle ID: `com.HoYoverse.Nap`)
- **問題**: v1.0.0 では作成したボリュームを検出できなかった

## v1.1.0 での改善点

1. **5つの検出メソッド**を実装:
   - Method 1: `/Volumes/` マウントポイントから検出（新規追加）
   - Method 2: `diskutil list` での検索（改善）
   - Method 3: コンテナ内検索
   - Method 4: `diskutil apfs list` での検索
   - Method 5: 全APFSボリューム検索（新規追加）

2. **マウント処理の改善**:
   - 既存マウント競合の自動検出
   - 内蔵コンテナ干渉の自動削除
   - 詳細なエラーログ

## テスト手順

### ステップ1: 診断スクリプトでボリューム確認

```bash
cd /path/to/scripts
./diagnose-volume-creation.sh
```

**確認ポイント**:
- `/Volumes/ZenlessZoneZero` が検出されるか
- デバイスノード（例: `/dev/disk5s4`）が取得できるか

### ステップ2: 既存ボリュームをアンマウント

```bash
sudo diskutil unmount /Volumes/ZenlessZoneZero
```

これで次回のスクリプト実行時に正しくマウント処理が行われます。

### ステップ3: 改善版スクリプトで再インストール

```bash
./1_playcover-ipa-install.command
```

**期待される動作**:
1. ステップ 09 でボリューム作成時に「既に存在します」と表示
2. **ボリューム検出が成功**（v1.0.0では失敗していた）
3. ステップ 10 でマウント処理が成功
4. 内蔵コンテナの自動削除（存在する場合）
5. 正しいパスへのマウント: `~/Library/Containers/com.HoYoverse.Nap`

### ステップ4: マウント確認

```bash
mount | grep ZenlessZoneZero
ls -la ~/Library/Containers/com.HoYoverse.Nap
```

**期待される出力**:
```
/dev/disk5sX on /Users/[username]/Library/Containers/com.HoYoverse.Nap (apfs, ...)
```

## トラブルシューティング

### 依然としてボリュームが見つからない場合

1. **診断スクリプトの実行**:
   ```bash
   ./diagnose-volume-creation.sh
   ```

2. **手動でデバイスノードを確認**:
   ```bash
   diskutil info /Volumes/ZenlessZoneZero | grep "Device Node"
   ```

3. **直接マウントを試行**:
   ```bash
   DEVICE=$(diskutil info /Volumes/ZenlessZoneZero | grep "Device Node" | awk '{print $NF}')
   sudo diskutil unmount $DEVICE
   sudo mount -t apfs $DEVICE ~/Library/Containers/com.HoYoverse.Nap
   ```

### マウントエラーが発生する場合

1. **マウント診断スクリプトの実行**:
   ```bash
   ./diagnose-mount.sh
   ```

2. **内蔵コンテナの手動削除**:
   ```bash
   sudo rm -rf ~/Library/Containers/com.HoYoverse.Nap
   ```

3. **再マウント試行**:
   ```bash
   ./1_playcover-ipa-install.command
   ```

## 成功の確認

以下が全て確認できれば成功です:

- ✅ ボリュームが検出される
- ✅ マウント処理が完了する
- ✅ `~/Library/Containers/com.HoYoverse.Nap` にマウントされる
- ✅ PlayCover で IPA インストールが開始される
- ✅ マッピングデータが登録される

## 次のテストケース

成功したら、以下のケースもテストしてください:

1. **新規アプリのインストール**（別のIPA）
2. **既存アプリの再インストール**（同じIPA）
3. **内蔵コンテナが存在する状態**でのインストール
4. **外部ボリュームに既にデータがある状態**でのインストール

## フィードバック

テスト結果を報告してください:
- どのステップで成功/失敗したか
- エラーメッセージの内容
- 診断スクリプトの出力
