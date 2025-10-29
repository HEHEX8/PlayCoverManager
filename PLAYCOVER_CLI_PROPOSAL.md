# PlayCover CLI 実装提案

## 解析結果サマリー

PlayCover内部では以下のシステムコマンドを使用してIPAインストールを実行：

### 使用ツール
1. `/usr/bin/unzip` - IPA展開
2. `/usr/bin/codesign` - バイナリ署名
3. `/usr/bin/xattr` - 隔離属性削除
4. `/usr/bin/zip` - 再パッケージ（export時）

### インストールフロー

```swift
1. allocateTempDir()          // 一時ディレクトリ作成
2. unzip()                     // IPA展開 → Payload/*.app
3. saveEntitlements()          // エンタイトルメント保存
4. resolveValidMachOs()        // MachOバイナリ検出
5. Macho.convertMacho()        // バイナリ変換
6. Shell.signMacho()           // 署名 (codesign -fs-)
7. PlayTools.installInIPA()    // PlayTools注入
8. wrap()                      // ラッパー生成 → Apps/{bundle_id}.app
9. sign()                      // 最終署名
10. removeQuarantine()         // xattr削除
```

## 🚀 提案1：独自CLI実装

PlayCoverの処理をシェルスクリプトで再現：

### メリット
- ✅ PlayCoverのGUIに依存しない
- ✅ インストール完了を確実に検知可能
- ✅ バッチ処理に最適
- ✅ 進行状況を完全制御

### デメリット
- ⚠️ PlayToolsの注入処理が複雑（Swift実装）
- ⚠️ Macho変換ロジックが必要
- ⚠️ メンテナンスコストが高い
- ⚠️ PlayCoverのバージョンアップ対応

### 実装例（簡易版）

```bash
#!/bin/zsh

install_ipa_direct() {
    local ipa_file="$1"
    local bundle_id="$2"
    
    # 1. 一時ディレクトリ作成
    local temp_dir=$(mktemp -d)
    
    # 2. IPA展開
    /usr/bin/unzip -oq "$ipa_file" -d "$temp_dir"
    
    # 3. .appを検出
    local app_path=$(find "$temp_dir/Payload" -name "*.app" -maxdepth 1 -type d | head -1)
    
    # 4. エンタイトルメント抽出
    local entitlements="$temp_dir/entitlements.plist"
    /usr/bin/codesign -d --entitlements :- "$app_path" > "$entitlements"
    
    # 5. 署名（簡易版：アドホック署名のみ）
    /usr/bin/codesign -fs- --deep --entitlements "$entitlements" "$app_path"
    
    # 6. 最終配置
    local final_path="${PLAYCOVER_APPS}/${bundle_id}.app"
    mv "$app_path" "$final_path"
    
    # 7. 隔離属性削除
    /usr/bin/xattr -r -d com.apple.quarantine "$final_path"
    
    # 8. クリーンアップ
    rm -rf "$temp_dir"
    
    echo "✅ インストール完了: $final_path"
}
```

**問題点：**
- PlayToolsの注入処理が未実装（Swift依存）
- Macho変換ロジックが未実装

## 🎯 提案2：現実的アプローチ（推奨）

PlayCoverのGUIを使いつつ、検知精度を向上：

### v5.0.1の改善（実装済み）
- ✅ ファイル安定性チェック
- ✅ lsofでのアクセス検証
- ✅ false positive防止

### さらなる改善案

#### A. プロセス監視の強化

```bash
# PlayCoverのCPU使用率監視
monitor_playcover_cpu() {
    while true; do
        local cpu=$(ps aux | grep "[P]layCover.app" | awk '{print $3}')
        if [[ $(echo "$cpu < 5.0" | bc) -eq 1 ]]; then
            # CPU使用率が5%未満 = インストール処理完了の可能性
            echo "CPU idle detected"
            break
        fi
        sleep 1
    done
}
```

#### B. ファイルシステム監視（fswatch）

```bash
# Apps/ディレクトリの変更監視
fswatch -1 ~/Library/Containers/io.playcover.PlayCover/Apps/
```

#### C. AppleScriptでのステータス取得

```bash
# PlayCoverのウィンドウタイトル監視
osascript -e 'tell application "PlayCover" to get name of front window'
```

## 🔧 提案3：ハイブリッドアプローチ

CLI + GUI の組み合わせ：

### フェーズ1：PlayCover起動とIPA投入
```bash
open -a PlayCover "$ipa_file"
```

### フェーズ2：多層検知
```bash
1. CPU使用率監視（インストール処理中は高負荷）
2. Apps/ディレクトリ監視（.appファイル出現）
3. 設定ファイル監視（現行の2回更新検知）
4. ファイル安定性確認（現行の4秒安定）
5. lsofチェック（現行）
```

### 実装例

```bash
detect_installation_multilayer() {
    local bundle_id="$1"
    local app_path="${PLAYCOVER_APPS}/${bundle_id}.app"
    local settings_plist="${PLAYCOVER_SETTINGS}/${bundle_id}.plist"
    
    # Layer 1: Wait for .app directory creation
    while [[ ! -d "$app_path" ]]; do
        sleep 1
    done
    echo "✓ App directory created"
    
    # Layer 2: Wait for CPU to stabilize
    while true; do
        local cpu=$(ps aux | grep "[P]layCover" | awk '{print $3}')
        if [[ $(echo "$cpu < 10.0" | bc) -eq 1 ]]; then
            break
        fi
        sleep 1
    done
    echo "✓ CPU stabilized"
    
    # Layer 3: Existing logic (2nd update + stability)
    # ... (現行の検知ロジック)
    
    echo "✅ Installation complete"
}
```

## 📊 各アプローチの比較

| アプローチ | 精度 | 速度 | 実装難易度 | メンテナンス |
|-----------|------|------|-----------|-------------|
| 独自CLI | ★★★★★ | ★★★★★ | ★★★★★ (高) | ★★★★★ (高) |
| 現行v5.0.1 | ★★★★☆ | ★★★★☆ | ★☆☆☆☆ (完了) | ★☆☆☆☆ (低) |
| CPU監視追加 | ★★★★★ | ★★★☆☆ | ★★☆☆☆ (中) | ★★☆☆☆ (中) |
| ハイブリッド | ★★★★★ | ★★★★☆ | ★★★☆☆ (中) | ★★☆☆☆ (中) |

## 🎯 推奨：段階的改善

### Phase 1（現状維持）
- v5.0.1のファイル安定性チェックで運用
- 実際の問題発生率をモニター

### Phase 2（必要に応じて）
- CPU使用率監視を追加
- 検知精度をさらに向上

### Phase 3（将来的に）
- 独自CLI実装の検討
- PlayCover非依存の完全自動化

## 結論

**現時点での推奨：v5.0.1で運用継続**

理由：
1. ✅ ファイル安定性チェックで大容量IPAのfalse positiveを防止
2. ✅ 小容量IPAも高速検知（6-10秒）
3. ✅ 実装済みでメンテナンスコスト低
4. ⚠️ 独自CLI実装はPlayTools注入処理が複雑すぎる

**もし問題が続く場合：**
- CPU監視を追加検討（実装コスト中程度）
- fswatch併用を検討（リアルタイム検知）
