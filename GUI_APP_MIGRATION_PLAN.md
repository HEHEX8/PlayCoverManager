# PlayCover Manager - Mac GUI アプリ移植計画書

## 📋 目次

1. [現状のCLI実装の解析](#1-現状のcli実装の解析)
2. [GUI化のアーキテクチャ設計](#2-gui化のアーキテクチャ設計)
3. [技術スタック選定](#3-技術スタック選定)
4. [機能マッピング](#4-機能マッピング)
5. [UI/UX設計](#5-uiux設計)
6. [実装ロードマップ](#6-実装ロードマップ)
7. [リスクと課題](#7-リスクと課題)

---

## 1. 現状のCLI実装の解析

### 1.1 プロジェクト概要

**プロジェクト名**: PlayCover Manager  
**バージョン**: 5.2.0  
**言語**: Zsh Shell Script  
**総コード行数**: 約9,000行  
**モジュール構成**: 8ファイル + メインスクリプト

### 1.2 アーキテクチャ

```
PlayCoverManager/
├── main.sh (300行)                    # メインエントリーポイント
│   ├── シングルインスタンス制御
│   ├── モジュールのロード
│   └── メイン実行ループ
│
└── lib/                                # モジュール群 (8,682行)
    ├── 00_core.sh (1,800行)           # コア機能・ユーティリティ
    │   ├── 色・スタイル定義（24色）
    │   ├── 定数定義
    │   ├── エラーハンドリング
    │   ├── ファイルシステム操作
    │   ├── キャッシュシステム
    │   └── sudo認証
    │
    ├── 01_mapping.sh (200行)          # マッピングファイル管理
    │   ├── アプリ→ボリューム対応関係
    │   ├── 重複除去
    │   └── 整合性チェック
    │
    ├── 02_volume.sh (800行)           # APFS ボリューム操作
    │   ├── ボリューム作成・削除
    │   ├── マウント・アンマウント
    │   ├── 容量チェック
    │   └── diskutilラッパー
    │
    ├── 03_storage.sh (2,200行)        # ストレージ切り替え
    │   ├── 内蔵→外部移行
    │   ├── 外部→内蔵移行
    │   ├── 4種類の転送方法対応
    │   ├── ストレージモード検出
    │   └── 内蔵データ汚染処理
    │
    ├── 04_app.sh (2,000行)            # アプリ管理
    │   ├── IPAインストール
    │   ├── アンインストール
    │   ├── 完了検知システム
    │   └── PlayCoverラッパー
    │
    ├── 05_cleanup.sh (800行)          # クリーンアップ
    │   ├── 通常クリーンアップ
    │   ├── 超強力クリーンアップ
    │   └── APFSスナップショット削除
    │
    ├── 06_setup.sh (700行)            # 初期セットアップ
    │   ├── 外部ドライブ選択
    │   ├── ボリューム自動作成
    │   └── 環境構築ウィザード
    │
    └── 07_ui.sh (1,182行)             # UI・メニュー表示
        ├── クイックランチャー
        ├── メインメニュー
        ├── アプリ管理メニュー
        ├── ボリューム操作メニュー
        ├── ストレージ切り替えメニュー
        └── システムメンテナンスメニュー
```

### 1.3 主要機能リスト

#### A. クイックランチャー
- **アプリ一覧表示**: 3カラムレイアウト、アイコン付き状態表示
- **状態アイコン**:
  - 🔌: 外部ストレージ設定
  - 🏠: 内蔵ストレージ設定
  - ●: 起動可能（Ready）
  - ⚠️: 警告（内蔵データ検出・要対応）
  - 🔄: 要再マウント
  - 📦: 未マウント（自動マウント実行）
  - 📭: 初期状態（データなし）
  - 🔐: sudo権限が必要
  - ⭐: 最近起動したアプリ
- **自動マウント**: 未マウント状態を検出して自動実行
- **最近起動の記録**: Enterキーで最近起動したアプリを再起動

#### B. アプリ管理
- **IPA インストール**: 
  - 複数 IPA ファイルの一括インストール
  - リアルタイム進捗表示（`.`, `◆`, `◇`, `⏳`）
  - 2パターン完了検知（標準アプリ/極小アプリ）
- **アンインストール**: アプリと関連ボリュームの削除

#### C. ボリューム操作
- **全ボリュームマウント**: 登録済みボリュームを一括マウント
- **全ボリュームアンマウント**: 安全に一括アンマウント
- **個別操作**: 特定ボリュームのマウント/アンマウント/再マウント

#### D. ストレージ切り替え
- **内蔵 → 外部**: 内蔵データを外部ボリュームに移行
- **外部 → 内蔵**: 外部データを内蔵ストレージに戻す
- **内蔵データ処理**: 意図しない内蔵データの検出と対処選択
- **4種類の転送方法**:
  - `rsync`: 安定性重視（デフォルト）
  - `cp`: 高速（rsyncより約20%速い）
  - `ditto`: macOS専用（リソースフォーク保持）
  - `parallel`: 最速（並列処理）

#### E. ディスク取り外し
- 外部ストレージの安全な取り外し（全ボリュームのアンマウント処理）

#### F. システムメンテナンス
- **APFSスナップショット確認・削除**: Time Machineスナップショット削除で容量解放
- **システムキャッシュクリア**: ユーザーキャッシュ、一時ファイル、アップデート削除
- **ストレージ使用状況確認**: システム・外部ボリュームの容量表示

### 1.4 技術的特徴

#### ストレージモード検出システム
アプリの現在のストレージ状態を自動検出：
- `external`: 外部ストレージに正しくマウント済み（Ready）
- `external_wrong_location`: 外部ボリュームが間違った位置にマウント（要再マウント）
- `internal_intentional`: ユーザーが選択した内蔵ストレージ（Ready）
- `internal_intentional_empty`: 内蔵ストレージ選択済みだがデータなし（初期状態）
- `internal_contaminated`: **意図しない内蔵データ検出**（警告表示）
- `none`: データなし・未マウント状態

#### インストール完了検知システム
2パターン対応の高精度検知：
- **パターンA（標準アプリ 185MB～3GB）**: 
  - Phase 1: 設定ファイルの2回目の更新を検知
  - Phase 2: mtimeが4秒間安定していることを確認
- **パターンB（極小アプリ 1～10MB）**: 
  - Phase 1b: 1回目の更新後8秒経過で判定
  - Phase 2: 同様の安定性検証

#### キャッシュシステム
- ボリューム情報のキャッシュ（diskutil高速化）
- ストレージ容量のキャッシュ
- 起動可能アプリリストのキャッシュ
- 外部ドライブ名のキャッシュ

#### シングルインスタンス制御
- ロックファイル（`/tmp/playcover-manager-running.lock`）で多重起動防止
- プロセスIDで有効性確認（ゾンビロック自動検出）
- AppleScriptで既存ウィンドウを前面表示

---

## 2. GUI化のアーキテクチャ設計

### 2.1 アーキテクチャ方針

#### A. ハイブリッドアーキテクチャ（推奨）
```
┌─────────────────────────────────────────────┐
│           Swift/SwiftUI Frontend            │
│  ┌──────────────────────────────────────┐   │
│  │  • メインウィンドウ                  │   │
│  │  • クイックランチャービュー          │   │
│  │  • アプリ管理ビュー                  │   │
│  │  • ボリューム操作ビュー              │   │
│  │  • 設定ビュー                        │   │
│  └──────────────────────────────────────┘   │
└───────────────┬─────────────────────────────┘
                │ Async/Await + Combine
┌───────────────┴─────────────────────────────┐
│          Swift Backend Layer                │
│  ┌──────────────────────────────────────┐   │
│  │  • ビジネスロジック（Swift移植）    │   │
│  │  • Process経由でZshスクリプト実行   │   │
│  │  • 状態管理（ObservableObject）     │   │
│  │  • エラーハンドリング                │   │
│  └──────────────────────────────────────┘   │
└───────────────┬─────────────────────────────┘
                │ Process/Shell
┌───────────────┴─────────────────────────────┐
│        Zsh Shell Scripts (既存)             │
│  ┌──────────────────────────────────────┐   │
│  │  • 既存のlibモジュール（8,682行）   │   │
│  │  • APFS操作（diskutil）             │   │
│  │  • ファイル転送（rsync等）          │   │
│  │  • sudo認証                          │   │
│  └──────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
```

**メリット**:
- 既存のZshロジックを再利用（開発速度）
- Swift/SwiftUIで洗練されたUIを実現
- 段階的にSwiftへの移植が可能

**デメリット**:
- Process経由のオーバーヘッド
- デバッグが複雑

---

## 3. 技術スタック選定

### 3.1 推奨スタック

| レイヤー | 技術 | 理由 |
|---------|------|------|
| **UI Framework** | SwiftUI | ネイティブmacOS、宣言的UI、最新機能 |
| **プログラミング言語** | Swift 5.9+ | 型安全、Async/Await、macOS統合 |
| **状態管理** | Combine + ObservableObject | SwiftUI標準、リアクティブ |
| **非同期処理** | Swift Concurrency | async/await、Task、Actor |
| **シェルスクリプト実行** | Process (Foundation) | 既存Zshスクリプト再利用 |
| **永続化** | UserDefaults + FileManager | 設定・キャッシュ |
| **権限管理** | SMJobBless / AuthorizationServices | sudo相当の権限実行 |
| **アイコン** | SF Symbols 5 | macOS標準アイコンセット |
| **パッケージ管理** | Swift Package Manager | 依存関係管理 |
| **ビルドツール** | Xcode 15+ | 標準開発環境 |

### 3.2 代替案

#### 案B: 完全Swift実装
- **メリット**: パフォーマンス最適化、デバッグ容易
- **デメリット**: 開発コスト大（9,000行の再実装）

#### 案C: Electron + TypeScript
- **メリット**: クロスプラットフォーム、Web技術活用
- **デメリット**: バンドルサイズ大、ネイティブ感が劣る

**結論**: **案A（ハイブリッド）を推奨**

---

## 4. 機能マッピング

### 4.1 CLI → GUI 機能変換表

| CLI機能 | GUI実装 | 優先度 |
|--------|---------|--------|
| **クイックランチャー（番号選択）** | グリッドビュー/リストビュー、ダブルクリック起動 | P0 |
| **メインメニュー（1-6選択）** | タブバー/サイドバーナビゲーション | P0 |
| **アプリ管理メニュー** | 専用ビュー（インストール・削除ボタン） | P0 |
| **ボリューム操作メニュー** | ボリュームリスト + コントロールボタン | P1 |
| **ストレージ切り替えメニュー** | ドラッグ&ドロップ or ボタンベース | P1 |
| **システムメンテナンス** | メンテナンスパネル（ボタン群） | P2 |
| **進捗表示（`.`, `◆`等）** | プログレスバー + 詳細ログ | P0 |
| **カラー出力（24色）** | NSColor/SwiftUI Color | P1 |
| **sudo認証プロンプト** | macOS標準認証ダイアログ | P0 |
| **wait_for_enter** | 自動的に次の画面へ遷移 | P0 |
| **clear（画面クリア）** | ビュー遷移・アニメーション | P0 |

### 4.2 新規追加機能（GUI専用）

| 機能 | 説明 | 優先度 |
|-----|------|--------|
| **メニューバー常駐** | アプリを起動せずにクイックアクション | P1 |
| **ドラッグ&ドロップ** | IPAファイルをウィンドウにドロップしてインストール | P1 |
| **通知センター連携** | インストール完了・エラーを通知 | P2 |
| **Spotlight統合** | アプリ名で検索して起動 | P3 |
| **ダークモード対応** | システム設定に追従 | P1 |
| **設定画面** | 転送方法、テーマ、通知設定 | P2 |
| **ログビューア** | リアルタイムログ表示（折りたたみ可能） | P2 |
| **統計表示** | ストレージ使用量のグラフ | P3 |

---

## 5. UI/UX設計

### 5.1 ウィンドウ構成

#### メインウィンドウ（推奨: サイドバースタイル）

```
┌────────────────────────────────────────────────────────┐
│ PlayCover Manager                          [- □ ✕]     │
├──────────────┬─────────────────────────────────────────┤
│              │                                          │
│  🚀 ランチャー │   ┌──────────────────────────────────┐ │
│  📦 アプリ管理 │   │  崩壊：スターレイル              │ │
│  💾 ボリューム │   │  [🔌外部] [●Ready] [⭐最近起動] │ │
│  ⚙️  設定     │   │  容量: 45GB / 100GB              │ │
│  🔧 メンテナンス│   │                                  │ │
│              │   │  [起動] [設定] [削除]              │ │
│              │   └──────────────────────────────────┘ │
│              │                                          │
│              │   ┌──────────────────────────────────┐ │
│              │   │  原神                            │ │
│              │   │  [🏠内蔵] [⚠️データ検出]        │ │
│              │   │  容量: 25GB                      │ │
│              │   │                                  │ │
│              │   │  [起動] [設定] [削除]              │ │
│              │   └──────────────────────────────────┘ │
│              │                                          │
└──────────────┴─────────────────────────────────────────┘
```

### 5.2 画面遷移フロー

```
起動
 │
 ├─ 初回起動時 → セットアップウィザード（モーダル）
 │   ├─ 外部ドライブ選択
 │   ├─ ボリューム作成
 │   └─ 完了 → メイン画面
 │
 └─ 2回目以降 → メイン画面
     │
     ├─ ランチャータブ（デフォルト）
     │   ├─ アプリ一覧（グリッド/リスト切替）
     │   ├─ ダブルクリック → アプリ起動
     │   └─ 右クリック → コンテキストメニュー
     │       ├─ 起動
     │       ├─ ストレージ切り替え
     │       ├─ Finderで表示
     │       └─ 削除
     │
     ├─ アプリ管理タブ
     │   ├─ IPAドロップエリア
     │   ├─ インストール進捗（プログレスバー）
     │   └─ インストール済みアプリリスト
     │
     ├─ ボリューム操作タブ
     │   ├─ ボリューム一覧（テーブルビュー）
     │   ├─ マウント/アンマウントボタン
     │   └─ 容量表示（プログレスインジケータ）
     │
     ├─ 設定タブ
     │   ├─ 転送方法選択（rsync/cp/ditto/parallel）
     │   ├─ 通知設定
     │   ├─ テーマ設定
     │   └─ キャッシュクリア
     │
     └─ メンテナンスタブ
         ├─ APFSスナップショット削除
         ├─ システムキャッシュクリア
         └─ ストレージ使用状況
```

### 5.3 デザインガイドライン

#### カラーパレット（既存CLIからの移植）
```swift
extension Color {
    // Primary Text Colors
    static let softWhite = Color(red: 230/255, green: 230/255, blue: 230/255)
    static let lightGray = Color(red: 180/255, green: 180/255, blue: 180/255)
    static let midGray = Color(red: 140/255, green: 140/255, blue: 140/255)
    
    // Semantic Colors
    static let softRed = Color(red: 255/255, green: 120/255, blue: 120/255)
    static let softGreen = Color(red: 120/255, green: 220/255, blue: 120/255)
    static let softBlue = Color(red: 120/255, green: 180/255, blue: 240/255)
    static let softYellow = Color(red: 230/255, green: 220/255, blue: 100/255)
    
    // Extended Colors
    static let naturalOrange = Color(red: 240/255, green: 160/255, blue: 100/255)
    static let naturalGold = Color(red: 230/255, green: 200/255, blue: 100/255)
    static let skyBlue = Color(red: 120/255, green: 190/255, blue: 230/255)
    static let turquoise = Color(red: 100/255, green: 200/255, blue: 200/255)
}
```

#### タイポグラフィ
- **見出し**: SF Pro Display Bold, 20pt
- **本文**: SF Pro Text Regular, 14pt
- **キャプション**: SF Pro Text Regular, 12pt

#### アイコン（SF Symbols使用）
| CLI表示 | SF Symbol | 説明 |
|--------|-----------|------|
| 🔌 | `externaldrive.fill` | 外部ストレージ |
| 🏠 | `internaldrive.fill` | 内蔵ストレージ |
| ● | `checkmark.circle.fill` | Ready |
| ⚠️ | `exclamationmark.triangle.fill` | 警告 |
| 🔄 | `arrow.triangle.2.circlepath` | 再マウント |
| 📦 | `shippingbox.fill` | 未マウント |
| 🔐 | `lock.shield.fill` | sudo権限必要 |
| ⭐ | `star.fill` | 最近起動 |

---

## 6. 実装ロードマップ

### Phase 1: 基盤構築（2-3週間）
- [ ] Xcodeプロジェクト作成
- [ ] SwiftUIアプリ骨格構築
- [ ] Zshスクリプト実行ラッパー実装（Process）
- [ ] 基本的な状態管理（ObservableObject）
- [ ] シングルインスタンス制御
- [ ] sudo認証システム（SMJobBless）

### Phase 2: コア機能（4-5週間）
- [ ] クイックランチャービュー（グリッド/リスト）
- [ ] アプリ起動機能
- [ ] ストレージモード検出の統合
- [ ] マウント/アンマウント操作
- [ ] ボリューム一覧表示

### Phase 3: アプリ管理（3-4週間）
- [ ] IPA ドラッグ&ドロップ
- [ ] インストール進捗表示（プログレスバー）
- [ ] 完了検知システムの統合
- [ ] アンインストール機能
- [ ] エラーハンドリング

### Phase 4: 高度な機能（4-5週間）
- [ ] ストレージ切り替え（内蔵⇄外部）
- [ ] 4種類の転送方法選択
- [ ] システムメンテナンス機能
- [ ] 設定画面
- [ ] ログビューア

### Phase 5: UI/UX改善（2-3週間）
- [ ] ダークモード対応
- [ ] アニメーション・トランジション
- [ ] 通知センター連携
- [ ] コンテキストメニュー
- [ ] キーボードショートカット

### Phase 6: 最適化・テスト（2-3週間）
- [ ] パフォーマンスチューニング
- [ ] メモリリーク修正
- [ ] ユニットテスト作成
- [ ] UIテスト作成
- [ ] ベータテスト実施

### Phase 7: リリース準備（1-2週間）
- [ ] アプリアイコン最終調整
- [ ] DMGインストーラー作成
- [ ] ドキュメント更新
- [ ] GitHub Releases公開
- [ ] 公証（Notarization）

**合計期間**: 18-25週間（約4-6ヶ月）

---

## 7. リスクと課題

### 7.1 技術的リスク

| リスク | 影響度 | 対策 |
|-------|--------|------|
| **sudo権限の管理** | 高 | SMJobBless + ヘルパーツール実装 |
| **Process実行のオーバーヘッド** | 中 | 段階的にSwiftへ移植、キャッシュ活用 |
| **マルチスレッド同期** | 中 | Swift Concurrency（Actor）で排他制御 |
| **エラーハンドリングの複雑化** | 中 | Result型、Errorプロトコル活用 |
| **UI応答性** | 中 | 長時間処理は必ずバックグラウンドで実行 |

### 7.2 UX課題

| 課題 | 解決策 |
|-----|--------|
| **CLIの柔軟性をGUIで再現** | コンテキストメニュー、詳細設定パネル |
| **進捗表示の可視化** | プログレスバー、詳細ログ折りたたみ |
| **エラーメッセージの分かりやすさ** | 平易な日本語 + 解決策の提示 |
| **初心者への配慮** | セットアップウィザード、ツールチップ |

### 7.3 開発リソース

- **開発時間**: 4-6ヶ月（フルタイム換算）
- **必要スキル**: Swift/SwiftUI、Shell Script、macOSシステムプログラミング
- **テスト環境**: Apple Silicon Mac（M1以降）、macOS Sequoia 15.1以降

---

## 8. 結論

### 8.1 推奨アプローチ

**ハイブリッドアーキテクチャ（Swift UI + Zsh Backend）を推奨**

**理由**:
1. 既存の9,000行のZshロジックを再利用できる
2. SwiftUIで洗練されたmacOSネイティブUIを実現
3. 段階的にSwiftへの移植が可能（Phase 2以降）
4. 開発期間を4-6ヶ月に短縮（完全再実装なら8-12ヶ月）

### 8.2 次のステップ

1. **Xcodeプロジェクト作成**: `PlayCoverManagerGUI.xcodeproj`
2. **プロトタイプ開発**: クイックランチャー画面の試作（2週間）
3. **技術検証**: Process経由でZshスクリプト実行テスト
4. **UI/UXレビュー**: デザインモックアップのフィードバック
5. **本格開発開始**: Phase 1からロードマップに沿って実装

### 8.3 成功の鍵

- **段階的な移行**: CLI版と並行してGUI版を開発
- **ユーザーテスト**: ベータ版で早期にフィードバック収集
- **ドキュメント整備**: README、CONTRIBUTING、API仕様書
- **コミュニティ**: GitHub Discussionsでユーザーとの対話

---

## 付録

### A. サンプルコード（Zshスクリプト実行ラッパー）

```swift
import Foundation

class ShellScriptExecutor: ObservableObject {
    @Published var output: String = ""
    @Published var isRunning: Bool = false
    
    func executeScript(_ scriptPath: String, arguments: [String] = []) async throws -> String {
        isRunning = true
        defer { isRunning = false }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [scriptPath] + arguments
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        
        let data = try await pipe.fileHandleForReading.readToEnd() ?? Data()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        return output
    }
}
```

### B. サンプルコード（クイックランチャービュー）

```swift
import SwiftUI

struct QuickLauncherView: View {
    @StateObject private var viewModel = QuickLauncherViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("クイックランチャー")
                .font(.title)
                .bold()
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 16) {
                    ForEach(viewModel.apps) { app in
                        AppCardView(app: app)
                            .onTapGesture {
                                Task {
                                    await viewModel.launchApp(app)
                                }
                            }
                    }
                }
            }
        }
        .padding()
        .onAppear {
            Task {
                await viewModel.loadApps()
            }
        }
    }
}

struct AppCardView: View {
    let app: PlayCoverApp
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: app.storageIcon)
                    .foregroundColor(app.storageColor)
                Text(app.name)
                    .font(.headline)
                Spacer()
                if app.isRecentlyLaunched {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                }
            }
            
            HStack {
                StatusBadge(status: app.status)
                Spacer()
                if app.requiresSudo {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(.orange)
                }
            }
            
            Text("容量: \(app.size)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}
```

### C. ディレクトリ構造（推奨）

```
PlayCoverManagerGUI/
├── PlayCoverManagerGUI.xcodeproj
├── PlayCoverManagerGUI/
│   ├── App/
│   │   ├── PlayCoverManagerGUIApp.swift
│   │   └── AppDelegate.swift
│   ├── Views/
│   │   ├── Main/
│   │   │   ├── ContentView.swift
│   │   │   └── SidebarView.swift
│   │   ├── QuickLauncher/
│   │   │   ├── QuickLauncherView.swift
│   │   │   └── AppCardView.swift
│   │   ├── AppManagement/
│   │   │   ├── AppManagementView.swift
│   │   │   ├── InstallView.swift
│   │   │   └── UninstallView.swift
│   │   ├── Volume/
│   │   │   ├── VolumeListView.swift
│   │   │   └── VolumeDetailView.swift
│   │   ├── Settings/
│   │   │   └── SettingsView.swift
│   │   └── Maintenance/
│   │       └── MaintenanceView.swift
│   ├── ViewModels/
│   │   ├── QuickLauncherViewModel.swift
│   │   ├── AppManagementViewModel.swift
│   │   └── VolumeViewModel.swift
│   ├── Models/
│   │   ├── PlayCoverApp.swift
│   │   ├── Volume.swift
│   │   └── StorageMode.swift
│   ├── Services/
│   │   ├── ShellScriptExecutor.swift
│   │   ├── SudoAuthService.swift
│   │   └── NotificationService.swift
│   ├── Utilities/
│   │   ├── Extensions.swift
│   │   └── Constants.swift
│   └── Resources/
│       ├── Assets.xcassets
│       ├── Info.plist
│       └── Scripts/
│           ├── main.sh
│           └── lib/
│               ├── 00_core.sh
│               ├── 01_mapping.sh
│               ├── 02_volume.sh
│               ├── 03_storage.sh
│               ├── 04_app.sh
│               ├── 05_cleanup.sh
│               ├── 06_setup.sh
│               └── 07_ui.sh
└── README.md
```

---

**ドキュメントバージョン**: 1.0  
**作成日**: 2025-11-01  
**最終更新**: 2025-11-01  
**著者**: PlayCover Manager Development Team
