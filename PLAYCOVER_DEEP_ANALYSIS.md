# PlayCover 徹底解析レポート

## 📋 目次
1. [PlayTools注入処理](#1-playtools注入処理)
2. [Macho変換ロジック](#2-macho変換ロジック)
3. [エンタイトルメント処理](#3-エンタイトルメント処理)
4. [Wrap処理](#4-wrap処理)
5. [InstallVMの状態管理](#5-installvmの状態管理)
6. [Mac環境での実機検証要求](#6-mac環境での実機検証要求)
7. [CLI実装の実現可能性](#7-cli実装の実現可能性)

---

## 1. PlayTools注入処理

### 処理フロー (`PlayTools.swift:74-92`)

```swift
static func installInIPA(_ exec: URL) async throws {
    // 1. バイナリを読み込み、ARM64のみに絞り込む
    var binary = try Data(contentsOf: exec)
    try Macho.stripBinary(&binary)
    
    // 2. MachOにPlayToolsのdylibパスを注入
    Inject.injectMachO(
        machoPath: exec.path,
        cmdType: .loadDylib,
        backup: false,
        injectPath: playToolsPath.path,  // ~/Library/Frameworks/PlayTools.framework/PlayTools
        finishHandle: { result in
            if result {
                // 3. AKInterfaceプラグインとローカライゼーションをコピー
                try installPluginInIPA(exec.deletingLastPathComponent())
                // 4. 最終署名
                try Shell.signApp(exec)
            }
        }
    )
}
```

### 重要な発見

**1. 外部ライブラリ依存：**
- `injection` ライブラリを使用（Swift Package Manager）
- MachOファイルへの`LC_LOAD_DYLIB`コマンド注入を実行
- Backup機能は無効（`backup: false`）

**2. PlayToolsのパス：**
```
~/Library/Frameworks/PlayTools.framework/PlayTools
```

**3. 注入されるコンポーネント：**
- PlayTools dylib（メイン機能）
- AKInterface.bundle（プラグイン）
- ローカライゼーションファイル（*.lproj/Playtools.strings）

**4. プラグインのインストール (`installPluginInIPA`)：**
```
Payload/*.app/PlugIns/AKInterface.bundle  # プラグインバンドル
Payload/*.app/*.lproj/Playtools.strings   # 各言語のローカライズファイル
```

### CLI実装への課題

❌ **非常に困難：**
- `injection`ライブラリはSwift実装
- MachOバイナリへのロードコマンド注入は低レベル処理
- 外部ツール（`optool`など）で代替可能だが、PlayCoverとの互換性未保証

---

## 2. Macho変換ロジック

### 処理フロー (`Macho.swift:42-57`)

```swift
static func convertMacho(_ macho: URL) throws {
    var binary = try Data(contentsOf: macho)
    
    // 1. Fat binaryからARM64のみを抽出
    try stripBinary(&binary)
    
    // 2. バージョンコマンドをMac Catalystに変換
    try replaceVersionCommand(&binary)
    
    // 3. @rpathライブラリパスを絶対パスに置換
    try replaceLibraries(&binary)
    
    // 4. 変換後のバイナリを書き戻し
    try FileManager.default.removeItem(at: macho)
    try binary.write(to: macho)
}
```

### 詳細解析

#### 2-1. stripBinary (ARM64抽出)
```swift
// Fat binaryからARM64アーキテクチャのみを取り出す
if header.magic == FAT_MAGIC || header.magic == FAT_CIGAM {
    for _ in 0..<header.nfat_arch {
        if arch.cputype == CPU_TYPE_ARM64 {
            binary = binary.subdata(in: Int(arch.offset)..<Int(arch.offset+arch.size))
            return
        }
    }
}
```

**目的：**
- x86_64やarmv7を含むUniversal Binaryから、M1/M2向けのARM64のみを抽出
- ファイルサイズ削減とM1特化

#### 2-2. replaceVersionCommand (Catalyst化)
```swift
var macCatalystCommand = build_version_command(
    cmd: UInt32(LC_BUILD_VERSION),
    cmdsize: 24,
    platform: UInt32(PLATFORM_MACCATALYST),  // ★重要★
    minos: 0x000b0000,     // macOS 11.0
    sdk: 0x000e0000,       // SDK 14.0
    ntools: 0
)
```

**目的：**
- iOSアプリをmacOSで実行可能にする
- `LC_VERSION_MIN_IPHONEOS` → `LC_BUILD_VERSION (MACCATALYST)` に変換

#### 2-3. replaceLibraries (@rpath修正)
```swift
let dylibsToReplace = ["libswiftUIKit"]

// 変換:
// @rpath/libswiftUIKit.dylib 
// ↓
// /System/iOSSupport/usr/lib/swift/libswiftUIKit.dylib
```

**目的：**
- iOS向けの動的ライブラリパスを、macOSのiOSSupport配下の絶対パスに変更
- ランタイムでのライブラリロード失敗を防止

### CLI実装への可能性

✅ **実装可能：**
- 全てSwiftの標準的なData操作
- MachOフォーマットの知識があれば再現可能
- ただし、複雑なビット操作とエンディアン処理が必要

**再現に必要な知識：**
- MachOヘッダ構造
- Load Command形式
- Fat Binary構造

---

## 3. エンタイトルメント処理

### 処理フロー (`Entitlements.swift:24-27`)

```swift
static func dumpEntitlements(exec: URL) throws -> [String: Any] {
    // codesignコマンドでエンタイトルメント抽出
    let result = try [String: Any].read(try copyEntitlements(exec: exec))
    return result ?? [:]
}

// 内部でPlayTools.fetchEntitlements()を呼び出し
static func fetchEntitlements(_ exec: URL) throws -> String {
    return try Shell.run("/usr/bin/codesign", "-d", "--entitlements", "-", "--xml", exec.path)
}
```

### 追加されるエンタイトルメント (`setBaseEntitlements`)

```plist
com.apple.security.app-sandbox = true
com.apple.security.assets.movies.read-write = true
com.apple.security.assets.music.read-write = true
com.apple.security.assets.pictures.read-write = true
com.apple.security.device.audio-input = true
com.apple.security.device.bluetooth = true
com.apple.security.device.camera = true
com.apple.security.device.microphone = true
com.apple.security.device.usb = true
com.apple.security.files.downloads.read-write = true
com.apple.security.files.user-selected.read-write = true
com.apple.security.network.client = true
com.apple.security.network.server = true
com.apple.security.personal-information.addressbook = true
com.apple.security.personal-information.calendars = true
com.apple.security.personal-information.location = true
com.apple.security.print = true
```

### サンドボックスプロファイル

```swift
// YAML設定ファイルからルールを読み込み
var rules = try getDefaultRules()  // ~/.config/PlayCover/default.yaml
if let bundleRules = try getBundleRules(bundleID) {
    // アプリ固有のルールをマージ
}

// Sandboxプロファイル (SBPL) を構築
base["com.apple.security.temporary-exception.sbpl"] = sandboxProfile
```

### CLI実装への可能性

✅ **実装可能：**
- `/usr/bin/codesign`コマンドで取得
- plistファイル操作のみ
- シェルスクリプトで完全再現可能

---

## 4. Wrap処理

### 処理フロー (`Installer.swift:214-227`)

```swift
static func wrap(_ baseApp: BaseApp) throws -> URL {
    let info = AppInfo(contentsOf: baseApp.url.appendingPathComponent("Info").appendingPathExtension("plist"))
    
    // 最終配置先
    let location = AppsVM.appDirectory
        .appendingEscapedPathComponent(info.bundleIdentifier)
        .appendingPathExtension("app")
    
    // 既存アプリを削除
    if FileManager.default.fileExists(atPath: location.path) {
        try FileManager.default.removeItem(at: location)
    }
    
    // .appバンドルを移動
    try FileManager.default.moveItem(at: baseApp.url, to: location)
    return location
}
```

### 最終配置パス

```
~/Library/Containers/io.playcover.PlayCover/Apps/{bundle_id}.app
```

例：
```
~/Library/Containers/io.playcover.PlayCover/Apps/com.miHoYo.GenshinImpact.app
```

### CLI実装への可能性

✅ **実装可能：**
- 単純なファイル移動
- `mv`コマンドで完全再現可能

---

## 5. InstallVMの状態管理

### 進行状況の内部管理 (`Installer.swift:52, 58, 68, 73, 103, 118`)

```swift
InstallVM.shared.next(.begin, 0.0, 0.0)      // 0%
InstallVM.shared.next(.unzip, 0.0, 0.5)     // 0-50%
InstallVM.shared.next(.library, 0.5, 0.55)  // 50-55%
InstallVM.shared.next(.playtools, 0.55, 0.85) // 55-85%
InstallVM.shared.next(.wrapper, 0.85, 0.95) // 85-95%
InstallVM.shared.next(.finish, 0.95, 1.0)   // 95-100%
```

### InstallVMの状態遷移

```swift
enum InstallStage {
    case begin      // インストール開始
    case unzip      // IPA展開中
    case library    // ライブラリチェック
    case playtools  // PlayTools注入中
    case wrapper    // ラッパー生成中
    case finish     // 完了
    case failed     // 失敗
}
```

### 重要な発見

❌ **外部からの状態取得は不可能：**
- `InstallVM.shared`はPlayCoverアプリ内部のシングルトン
- ファイルシステムへの状態書き込みは**一切なし**
- 外部プロセスから進行状況を取得する手段は存在しない

**これが現行の「ファイル監視方式」が必要な理由**

---

## 6. Mac環境での実機検証要求

### 🔬 実行してほしい検証項目

#### 検証1: インストール中のファイルシステム変更トレース

```bash
# fswatch でリアルタイムにファイル変更を監視
fswatch -r ~/Library/Containers/io.playcover.PlayCover/ \
    --format-time "%F %T" \
    --timestamp-format "%F %T" \
    > /tmp/playcover_install_trace.log &

# PlayCoverでIPAをインストール（GUI操作）
# インストール完了後、fswatch を停止

cat /tmp/playcover_install_trace.log
```

**期待される情報：**
- どのファイルが、どのタイミングで作成/更新されるか
- 設定ファイル（`App Settings/*.plist`）の更新タイミング
- `.app`バンドルの作成タイミング

#### 検証2: CPU使用率の変化

```bash
# PlayCoverのCPU使用率を1秒ごとに記録
while true; do
    date "+%T" >> /tmp/cpu_log.txt
    ps aux | grep "[P]layCover.app" | awk '{print $3}' >> /tmp/cpu_log.txt
    sleep 1
done &

# インストール実行後、ログ確認
cat /tmp/cpu_log.txt
```

**期待される情報：**
- インストール開始〜完了までのCPU使用率推移
- アイドル状態になるタイミング

#### 検証3: lsofでのファイルアクセス監視

```bash
# IPAインストール中にlsofで監視
while true; do
    lsof ~/Library/Containers/io.playcover.PlayCover/App\ Settings/*.plist 2>/dev/null \
        | grep PlayCover >> /tmp/lsof_log.txt
    sleep 0.5
done &

# インストール完了後、ログ確認
cat /tmp/lsof_log.txt
```

**期待される情報：**
- PlayCoverがいつまで設定ファイルにアクセスしているか
- ファイルクローズのタイミング

#### 検証4: 完了シグナルの探索

```bash
# AppleScript でPlayCoverのウィンドウタイトル監視
osascript -e 'tell application "System Events" to get properties of process "PlayCover"' \
    >> /tmp/playcover_ui_log.txt

# またはNotification Centerの監視
log stream --predicate 'subsystem == "io.playcover.PlayCover"' \
    >> /tmp/playcover_notifications.log
```

**期待される情報：**
- UI状態の変化
- システム通知の発行タイミング

---

## 7. CLI実装の実現可能性

### 実装難易度マトリックス

| コンポーネント | 難易度 | 再現方法 | 実装推奨度 |
|--------------|-------|---------|----------|
| **IPA展開** | ★☆☆☆☆ | `unzip -oq {ipa} -d {dest}` | ⭐⭐⭐⭐⭐ 必須 |
| **Macho変換** | ★★★★☆ | Swift実装必要 | ⭐⭐☆☆☆ 困難 |
| **PlayTools注入** | ★★★★★ | `injection`ライブラリ必須 | ⭐☆☆☆☆ 非現実的 |
| **エンタイトルメント** | ★☆☆☆☆ | `codesign`コマンド | ⭐⭐⭐⭐⭐ 必須 |
| **署名** | ★☆☆☆☆ | `codesign -fs-` | ⭐⭐⭐⭐⭐ 必須 |
| **Wrap** | ★☆☆☆☆ | `mv`コマンド | ⭐⭐⭐⭐⭐ 必須 |

### 結論：部分的CLI実装の提案

#### 実装可能な部分（簡易版）

```bash
#!/bin/zsh
# PlayCover Lite CLI - PlayTools無しの簡易インストーラー

install_ipa_lite() {
    local ipa_file="$1"
    local bundle_id="$2"
    
    # 1. 展開
    local temp_dir=$(mktemp -d)
    /usr/bin/unzip -oq "$ipa_file" -d "$temp_dir"
    
    # 2. .app取得
    local app_path=$(find "$temp_dir/Payload" -name "*.app" -maxdepth 1 | head -1)
    
    # 3. エンタイトルメント取得
    local ent_file="$temp_dir/entitlements.plist"
    /usr/bin/codesign -d --entitlements :- "$app_path" > "$ent_file"
    
    # 4. 署名（PlayTools無し）
    /usr/bin/codesign -fs- --deep --entitlements "$ent_file" "$app_path"
    
    # 5. 配置
    local dest="~/Library/Containers/io.playcover.PlayCover/Apps/${bundle_id}.app"
    mv "$app_path" "$dest"
    
    # 6. 隔離属性削除
    /usr/bin/xattr -r -d com.apple.quarantine "$dest"
    
    # 7. クリーンアップ
    rm -rf "$temp_dir"
    
    echo "✅ インストール完了（PlayTools無し）: $dest"
}
```

**制限事項：**
- ❌ PlayTools無効（キーマッピング不可）
- ❌ Macho変換無し（一部アプリ動作不可）
- ❌ AKInterface無し（追加機能無し）
- ✅ 基本的な起動は可能

#### 完全CLI実装に必要な追加作業

1. **Swift CLIツールの開発**
   - Macho変換処理の移植
   - `injection`ライブラリの統合
   - PlayTools注入処理の実装

2. **依存ライブラリの管理**
   - PlayTools.frameworkのバンドル
   - AKInterface.bundleのコピー

3. **PlayCoverとの互換性維持**
   - バージョンアップ対応
   - 設定ファイル形式の同期

---

## 8. 最終提案

### 現実的なアプローチ：ハイブリッド方式（推奨）

```
┌─────────────────────────────────────────┐
│  あなたのスクリプト（IPA自動投入）        │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  PlayCover GUI（実際のインストール処理）  │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  改良版検知システム（v5.0.1+）            │
│  - ファイル安定性チェック                 │
│  - CPU使用率監視（追加予定）             │
│  - fswatch併用（追加予定）              │
└─────────────────────────────────────────┘
```

### 追加改善案

#### オプション1: CPU監視の追加

```bash
# v5.0.2候補
monitor_cpu_until_idle() {
    local threshold=10.0
    local stable_count=0
    local required_stable=3  # 3回連続で低負荷
    
    while [[ $stable_count -lt $required_stable ]]; do
        local cpu=$(ps aux | grep "[P]layCover" | awk '{print $3}')
        if (( $(echo "$cpu < $threshold" | bc -l) )); then
            ((stable_count++))
        else
            stable_count=0
        fi
        sleep 1
    done
}
```

#### オプション2: fswatch併用

```bash
# リアルタイムファイル監視
fswatch -1 ~/Library/Containers/io.playcover.PlayCover/Apps/ \
    --event Created | while read path; do
    if [[ "$path" == *"${bundle_id}.app"* ]]; then
        echo "✓ App bundle created: $path"
        break
    fi
done
```

---

## 📊 まとめ

| 項目 | 結論 |
|-----|-----|
| **独自CLI実装** | ❌ PlayTools注入処理が複雑すぎて非現実的 |
| **簡易CLI実装** | △ PlayTools無しなら可能だが機能制限 |
| **現行v5.0.1** | ✅ ファイル安定性チェックで実用レベル |
| **改善案** | ✅ CPU監視/fswatch追加で精度向上可能 |

**最終推奨：現行のv5.0.1で運用し、実機検証データを元に必要に応じてCPU監視を追加**
