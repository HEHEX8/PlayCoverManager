# PlayCover Manager GUI

**完全なMac用ネイティブGUIアプリケーション**

このプロジェクトは、[PlayCover Manager](https://github.com/HEHEX8/PlayCoverManager)のCLI実装（v5.2.0）を、SwiftUIを使用した完全なmacOS GUIアプリケーションに移植したものです。

## 🎯 プロジェクト概要

- **バージョン**: 6.0.0-alpha1 (開発中)
- **ベース**: PlayCover Manager v5.2.0 (CLI版)
- **フレームワーク**: SwiftUI
- **言語**: Swift 5.9+
- **対応OS**: macOS Sonoma 14.0以降
- **アーキテクチャ**: Apple Silicon専用 (M1/M2/M3/M4)

## 🏗️ アーキテクチャ

### ハイブリッドアプローチ
- **フロントエンド**: SwiftUI (ネイティブmacOS UI)
- **バックエンド**: Swift + 既存Zshスクリプト
- **統合**: Process経由でZshスクリプトを実行

```
┌─────────────────────────────────────┐
│      SwiftUI Views                  │
│  • QuickLauncher                    │
│  • AppManagement                    │
│  • Volume Operations                │
│  • Settings                         │
│  • Maintenance                      │
└──────────────┬──────────────────────┘
               │
┌──────────────┴──────────────────────┐
│      ViewModels + Services          │
│  • ShellScriptExecutor              │
│  • AppState Management              │
│  • Error Handling                   │
└──────────────┬──────────────────────┘
               │
┌──────────────┴──────────────────────┐
│      Zsh Scripts (既存)              │
│  • lib/*.sh (8,682行)               │
│  • APFS操作、ファイル転送など       │
└─────────────────────────────────────┘
```

## 📁 プロジェクト構造

```
PlayCoverManagerGUI/
├── Package.swift                      # Swift Package定義
├── Sources/
│   ├── App/                          # アプリケーション
│   │   ├── PlayCoverManagerGUIApp.swift
│   │   └── AppDelegate.swift         # シングルインスタンス制御
│   ├── Views/                        # UI層
│   │   ├── Main/
│   │   │   ├── ContentView.swift
│   │   │   └── SidebarView.swift
│   │   ├── QuickLauncher/            # ✅ 実装済み
│   │   │   ├── QuickLauncherView.swift
│   │   │   ├── AppCardView.swift
│   │   │   └── AppListRowView.swift
│   │   ├── AppManagement/            # 🚧 実装予定
│   │   ├── Volume/                   # 🚧 実装予定
│   │   ├── Settings/                 # 🚧 実装予定
│   │   └── Maintenance/              # 🚧 実装予定
│   ├── ViewModels/                   # ビジネスロジック
│   │   └── QuickLauncherViewModel.swift
│   ├── Models/                       # データモデル
│   │   ├── PlayCoverApp.swift
│   │   └── AppState.swift
│   ├── Services/                     # サービス層
│   │   └── ShellScriptExecutor.swift # ✅ 実装済み
│   ├── Utilities/                    # ユーティリティ
│   │   ├── Colors.swift
│   │   ├── Constants.swift
│   │   └── Extensions.swift
│   └── Resources/                    # リソース
│       └── Scripts/                  # 既存のZshスクリプト
│           ├── main.sh
│           └── lib/*.sh
└── README.md
```

## ✅ 実装状況 (Phase 1)

### 完了した機能

- [x] **基盤構築**
  - [x] Swift Package構造
  - [x] AppDelegate（シングルインスタンス制御）
  - [x] AppState（グローバル状態管理）
  - [x] ShellScriptExecutor（Zsh実行ラッパー）

- [x] **UI基礎**
  - [x] ContentView（メインビュー）
  - [x] SidebarView（ナビゲーション）
  - [x] カラーシステム（CLI版から移植）

- [x] **クイックランチャー（メイン機能）**
  - [x] QuickLauncherView
  - [x] AppCardView（グリッドレイアウト）
  - [x] AppListRowView（リストレイアウト）
  - [x] 検索機能
  - [x] 表示モード切替（グリッド/リスト）
  - [x] コンテキストメニュー

- [x] **モデル**
  - [x] PlayCoverApp（アプリモデル）
  - [x] StorageMode（6パターン）
  - [x] AppStatus（5種類）
  - [x] サンプルデータ

### 次のステップ (Phase 2)

- [ ] ShellScriptExecutorと既存Zshスクリプトの統合
- [ ] アプリ起動機能の実装
- [ ] マウント/アンマウント操作の統合
- [ ] ストレージモード検出の統合

## 🚀 ビルド方法

### 必要環境

- macOS Sonoma 14.0以降
- Xcode 15.0以降
- Swift 5.9以降

### ビルドコマンド

```bash
# プロジェクトディレクトリに移動
cd PlayCoverManagerGUI

# ビルド
swift build

# 実行
swift run
```

### Xcodeで開く

```bash
# Xcodeプロジェクトを生成
swift package generate-xcodeproj

# Xcodeで開く
open PlayCoverManagerGUI.xcodeproj
```

## 🎨 デザイン

### カラーパレット

CLI版の24色カラーシステムをSwiftUIに移植：
- 目に優しい低輝度カラー
- ダークモード最適化
- アクセシビリティ配慮（コントラスト比）

### SF Symbols

| CLI表示 | SF Symbol | 用途 |
|--------|-----------|------|
| 🔌 | `externaldrive.fill` | 外部ストレージ |
| 🏠 | `internaldrive.fill` | 内蔵ストレージ |
| ● | `checkmark.circle.fill` | Ready |
| ⚠️ | `exclamationmark.triangle.fill` | 警告 |
| 🔄 | `arrow.triangle.2.circlepath` | 再マウント |
| 📦 | `shippingbox.fill` | 未マウント |
| 🔐 | `lock.shield.fill` | sudo権限 |
| ⭐ | `star.fill` | 最近起動 |

## 📝 開発メモ

### 設計判断

1. **ハイブリッドアーキテクチャ**
   - 理由: 既存の9,000行のZshロジックを再利用
   - 利点: 開発速度、段階的な移植が可能
   - 欠点: Process経由のオーバーヘッド

2. **SwiftUI採用**
   - 理由: 宣言的UI、macOS統合、最新機能
   - 利点: コード量削減、プレビュー機能
   - 欠点: 学習曲線（従来のAppKitと比較）

3. **シングルインスタンス制御**
   - 実装: AppDelegate + ロックファイル
   - 互換性: CLI版と同じ仕組み

### 技術的課題

- [ ] sudo権限の管理（SMJobBless実装予定）
- [ ] Process実行のエラーハンドリング
- [ ] リアルタイム進捗表示
- [ ] 通知センター連携

## 📚 参考資料

- [GUI移植計画書](../GUI_APP_MIGRATION_PLAN.md) - 完全な移植計画
- [PlayCover Manager (CLI版)](../README.md) - オリジナルCLI実装

## 📄 ライセンス

MIT License

---

**開発状況**: Phase 1 完了 🎉  
**次の目標**: Phase 2（Zshスクリプト統合）
