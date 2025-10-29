# PlayCover CLI Integration Research

## 背景

現在のPlayCover Manager (v5.0.1) は、IPAインストール完了を検知するために「設定ファイルの変更監視」という間接的な方法を使用しています。これには以下の課題があります：

### 現在の課題

1. **間接的な検知**
   - PlayCoverアプリケーション自体から直接ステータスを取得できない
   - 設定ファイル (`App Settings/{bundle_id}.plist`) の変更タイミングで推測
   - 2段階検知（2nd update + stability check）でfalse positiveを防止

2. **タイミングの不確実性**
   - 小容量IPA（180MB）: 6-10秒で検知
   - 大容量IPA（2-3GB）: 完了後+6秒で検知
   - ファイル安定性チェックによる追加待機時間

3. **複雑な検知ロジック**
   - mtime監視
   - lsof によるファイルアクセスチェック
   - 安定性カウンター管理

## 提案: PlayCover CLI統合

### コンセプト

> **「PlayCoverのGUIってフロントエンドなだけで、内部的にはCLI処理してるんだろうからそれを直接叩けると良い」**

この観点は非常に重要で、以下のメリットがあります：

1. **直接的なステータス取得**
   - インストール進捗をリアルタイムで取得
   - 完了/エラー/キャンセル状態を確実に判定
   - 間接的な推測が不要

2. **シンプルな実装**
   - ファイル監視ロジックが不要
   - 安定性チェックが不要
   - エラーハンドリングが明確

3. **高速化**
   - 完了を即座に検知
   - 待機時間の削減
   - false positiveリスクゼロ

## 調査結果

### 1. PlayCover-CLI プロジェクト

**GitHub**: https://github.com/JoseMoreville/PlayCover-CLI

- PlayCoverのコードベースを使用したCLIフォーク
- "sideloading via Command line" を目的に作成
- PlayCoverのインストールが前提条件

**現状**: 
- README に具体的なコマンド例がない
- 使用方法のドキュメントが不足
- アクティブな開発状況が不明

### 2. PlayCover本体のアーキテクチャ

**使用技術**:
- Swift/SwiftUI ベースのmacOSアプリ
- 依存ライブラリ:
  - `inject`: https://github.com/paradiseduo/inject
  - `PTFakeTouch`: https://github.com/Ret70/PTFakeTouch
  - `DownloadManager`: https://github.com/shapedbyiris/download-manager

**推測される構造**:
- GUIは SwiftUI
- バックエンドは Swift クラス/モジュール
- IPAインストールロジックは独立したモジュールの可能性

### 3. macOSでの一般的なCLI統合パターン

#### パターン1: AppleScript経由
```applescript
tell application "PlayCover"
    install ipa at "/path/to/app.ipa"
    repeat until (installation status is "completed")
        delay 1
    end repeat
end tell
```

**メリット**:
- PlayCoverが対応していれば簡単に実装可能
- macOS標準機能

**デメリット**:
- PlayCoverがAppleScriptサポートを実装している必要がある

#### パターン2: URL Scheme
```bash
open "playcover://install?path=/path/to/app.ipa"
```

**メリット**:
- アプリ間通信の標準的な方法
- 実装が比較的簡単

**デメリット**:
- ステータス取得が困難
- 現在の問題と同じ課題

#### パターン3: PlayCoverバイナリの直接実行
```bash
/Applications/PlayCover.app/Contents/MacOS/PlayCover \
    --install "/path/to/app.ipa" \
    --wait \
    --json-output
```

**メリット**:
- 最も直接的
- ステータス取得が可能
- エラーハンドリングが明確

**デメリット**:
- PlayCoverがCLIモードをサポートしている必要がある

#### パターン4: PlayCover内部APIの利用
```swift
// Swift CLIツールを作成
import PlayCoverKit

let installer = IPAInstaller()
let result = installer.install(ipaPath: "/path/to/app.ipa")
print(result.status)
```

**メリット**:
- 最も柔軟
- フル機能アクセス

**デメリット**:
- Swift CLIツールのビルドが必要
- PlayCoverの内部構造への依存

## 実装可能性の評価

### 短期的な実装 (すぐに可能)

#### 1. PlayCover-CLIの調査と検証
```bash
# PlayCover-CLIをインストール
brew tap JoseMoreville/playcover-cli
brew install playcover-cli

# コマンドを調査
playcover-cli --help
playcover-cli install --help

# テストインストール
playcover-cli install "/path/to/test.ipa" --wait --verbose
```

**アクション**:
1. PlayCover-CLIの実際のコマンドを確認
2. ステータス取得機能の有無を検証
3. 実用性を評価

#### 2. AppleScriptサポートの確認
```bash
# PlayCoverがAppleScriptに対応しているか確認
osascript -e 'tell application "PlayCover" to «event version»'
```

**アクション**:
1. PlayCoverのAppleScript辞書を確認
2. サポート状況を評価

### 中期的な実装 (開発が必要)

#### 3. PlayCoverへのCLI機能追加の提案
**アプローチ**:
1. PlayCoverリポジトリにissueを作成
2. CLI APIの必要性を説明
3. 設計案を提示（例：`--install`, `--status`, `--wait`オプション）

**提案内容例**:
```
Title: Feature Request: CLI Mode for Programmatic IPA Installation

Description:
- Use case: External tools need to install IPAs programmatically
- Required features:
  - Install IPA from command line
  - Real-time status output (JSON format)
  - Wait for completion
  - Error reporting
  
Example usage:
  PlayCover --cli --install "/path/to/app.ipa" --wait --json

Expected output:
  {"status": "installing", "progress": 45}
  {"status": "installing", "progress": 78}
  {"status": "completed", "bundle_id": "com.example.app"}
```

#### 4. 独自PlayCover CLIラッパーの開発
**コンセプト**:
- PlayCoverの内部処理を模倣
- IPAの解析・展開・署名を独自実装
- PlayCoverのデータ構造に合わせて配置

**技術スタック**:
- Swift または Bash/Zsh
- 必要な機能:
  - IPA解凍 (unzip)
  - Info.plist解析 (PlistBuddy)
  - コード署名 (codesign)
  - ファイル配置

**課題**:
- PlayCoverの内部構造の理解が必要
- メンテナンスコスト
- PlayCoverのアップデートへの追従

### 長期的な実装 (コミュニティ協力が必要)

#### 5. PlayCoverへの直接的なコントリビューション
**アプローチ**:
1. PlayCoverのソースコードをフォーク
2. CLI機能を実装
3. Pull Requestを作成
4. コミュニティレビュー

**実装内容**:
```swift
// PlayCover/CLI/InstallCommand.swift
import ArgumentParser

struct InstallCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "install"
    )
    
    @Argument(help: "Path to IPA file")
    var ipaPath: String
    
    @Flag(help: "Wait for installation to complete")
    var wait: Bool = false
    
    @Flag(help: "Output status as JSON")
    var json: Bool = false
    
    func run() throws {
        let installer = IPAInstaller()
        
        if json {
            installer.onProgress = { status in
                print(status.toJSON())
            }
        }
        
        let result = installer.install(ipaPath: ipaPath)
        
        if wait {
            while !result.isComplete {
                sleep(1)
            }
        }
        
        exit(result.exitCode)
    }
}
```

## 推奨アクションプラン

### Phase 1: 調査 (1-2日)

1. **PlayCover-CLIの実装確認**
   ```bash
   # リポジトリをクローン
   git clone https://github.com/JoseMoreville/PlayCover-CLI.git
   cd PlayCover-CLI
   
   # ソースコードを確認
   find . -name "*.swift" -type f | head -20
   grep -r "install" . | grep -E "func|class|struct"
   ```

2. **PlayCover本体のCLI機能確認**
   ```bash
   # PlayCoverバイナリを確認
   /Applications/PlayCover.app/Contents/MacOS/PlayCover --help
   
   # 利用可能な引数を確認
   strings /Applications/PlayCover.app/Contents/MacOS/PlayCover | grep -i "install\|cli\|command"
   ```

3. **AppleScriptサポート確認**
   ```bash
   # PlayCoverのAppleScript辞書を確認
   sdef /Applications/PlayCover.app
   ```

### Phase 2: 実装 (3-5日)

**Option A: PlayCover-CLIが使える場合**
- PlayCover Managerに統合
- 現在のファイル監視ロジックを置き換え
- エラーハンドリング追加

**Option B: 独自実装が必要な場合**
- PlayCoverコミュニティにissueを作成
- 暫定的に現在のv5.0.1検知ロジックを継続使用
- 将来的なCLI統合を準備

### Phase 3: テストと最適化 (2-3日)

- 小容量IPA（180MB）でのテスト
- 大容量IPA（2-3GB）でのテスト
- エラーケースのテスト
- パフォーマンス測定

## 結論

PlayCoverのCLI統合は理想的なソリューションですが、以下の点を確認する必要があります：

### 即座に確認すべきこと:
1. ✅ PlayCover-CLIの実装状況
2. ✅ PlayCover本体のCLI機能の有無
3. ✅ AppleScriptサポートの有無

### 現実的な選択肢:
1. **Best**: PlayCoverにCLI機能がある → 即座に統合
2. **Good**: PlayCover-CLIが使える → 依存関係として追加
3. **Acceptable**: 独自CLIラッパー開発 → メンテナンスコスト
4. **Current**: 現在の検知ロジック (v5.0.1) → 動作は保証されている

### 次のステップ:
**まずは調査**を実施し、実際にPlayCoverまたはPlayCover-CLIがCLI機能を提供しているか確認することが最優先です。

---

## 参考リンク

- **PlayCover本体**: https://github.com/PlayCover/PlayCover
- **PlayCover-CLI**: https://github.com/JoseMoreville/PlayCover-CLI
- **PlayCover Documentation**: https://playcover.github.io/PlayBook
- **PlayCover Discord**: https://discord.gg/rMv5qxGTGC

---

**作成日**: 2025-10-29  
**バージョン**: 1.0  
**関連Issue**: Large IPA false-positive detection (v5.0.1)
