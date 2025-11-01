# PlayCover Manager GUI

SwiftUIベースの完全グラフィカルなmacOSアプリケーション

## 📋 必要要件

- **macOS:** 13.0 (Ventura) 以降
- **Swift:** 5.9 以降
- **Xcode:** 15.0 以降（推奨）

## 🚀 ビルド方法

### 方法1: ビルドスクリプトを使用

```bash
cd PlayCoverManagerGUI
./build.sh
```

### 方法2: Swift Package Managerを直接使用

```bash
cd PlayCoverManagerGUI

# デバッグビルド
swift build

# リリースビルド
swift build -c release

# 実行
swift run
```

### 方法3: Xcodeを使用

```bash
cd PlayCoverManagerGUI
open Package.swift
```

Xcodeで開いた後:
1. スキームで "PlayCoverManagerGUI" を選択
2. デバイスで "My Mac" を選択
3. Cmd+R でビルド＆実行

## 📁 プロジェクト構造

```
PlayCoverManagerGUI/
├── Package.swift           # SPM設定
├── Info.plist             # アプリ情報
├── build.sh               # ビルドスクリプト
├── Sources/
│   ├── App/               # アプリエントリーポイント
│   ├── Models/            # データモデル
│   ├── Services/          # ビジネスロジック
│   ├── ViewModels/        # ビューモデル
│   ├── Views/             # SwiftUI ビュー
│   ├── Utilities/         # ユーティリティ
│   └── Resources/         # リソース（Zshスクリプト等）
└── README.md             # このファイル
```

## 🏗️ アーキテクチャ

### MVVMパターン with Services

```
Views (SwiftUI)
    ↓
ViewModels (@MainActor, ObservableObject)
    ↓
Services (ShellExecutor, PrivilegedOps, etc.)
    ↓
Zsh Scripts (Original CLI backend)
```

### 主要サービス

- **ShellScriptExecutor**: Zshコマンド実行
- **PrivilegedOperationManager**: sudo操作
- **NotificationManager**: macOS通知
- **ErrorManager**: エラー管理
- **Logger**: ログ記録

### 主要ビュー

- **QuickLauncherView**: アプリランチャー
- **AppManagementView**: アプリ管理
- **StorageSwitcherView**: ストレージ切替
- **VolumeListView**: ボリューム管理
- **SettingsView**: 設定
- **MaintenanceView**: メンテナンス
- **SetupWizardView**: 初期セットアップ
- **LogViewerView**: ログビューア

## 🛠️ 開発

### デバッグビルド

```bash
swift build
swift run
```

### リリースビルド

```bash
swift build -c release
.build/release/PlayCoverManagerGUI
```

### クリーン

```bash
swift package clean
```

### 依存関係の更新

```bash
swift package update
```

## 📝 コーディング規約

### Swift スタイル

- **命名**: キャメルケース（変数・関数）、パスカルケース（型）
- **アクセス修飾子**: 必要最小限の公開
- **async/await**: 非同期処理に使用
- **@MainActor**: UIに関わるクラスに付与

### SwiftUI ベストプラクティス

- **@StateObject**: ViewModelのライフサイクル管理
- **@ObservedObject**: 外部から渡されるオブジェクト
- **@EnvironmentObject**: グローバルステート
- **@Published**: リアクティブなプロパティ

### ファイル構成

```swift
//
//  FileName.swift
//  PlayCoverManagerGUI
//
//  Brief description
//

import Foundation
import SwiftUI

// MARK: - Main Type

// MARK: - Supporting Types

// MARK: - Extensions

// MARK: - Preview
```

## 🔍 トラブルシューティング

### ビルドエラー: "Module not found"

```bash
swift package clean
swift package resolve
swift build
```

### 実行時エラー: "Permission denied"

```bash
chmod +x build.sh
./build.sh
```

### Xcodeで開けない

Swift Package Managerプロジェクトなので:
```bash
open Package.swift  # これが正しい
```

### シングルトンの初期化エラー

`SettingsViewModel`、`ErrorManager`などはシングルトンです:
```swift
// ❌ 間違い
let settings = SettingsViewModel()

// ✅ 正しい
let settings = SettingsViewModel.shared
```

## 📚 追加ドキュメント

- **プロジェクトルートの README.md**: ユーザー向けドキュメント
- **GUI_APP_MIGRATION_PLAN.md**: 移行計画
- **IMPLEMENTATION_STATUS.md**: 実装状況
- **MIGRATION_COMPLETE_SUMMARY.md**: 移行完了サマリー

## 🧪 テスト（予定）

```bash
# テストの実行
swift test

# カバレッジ付き
swift test --enable-code-coverage
```

## 🚢 リリースビルド（予定）

アプリバンドルの作成:

```bash
# リリースビルド
swift build -c release

# アプリバンドル作成（手動）
# TODO: バンドル作成スクリプトを追加
```

## 📄 ライセンス

MIT License - 詳細は LICENSE ファイルを参照

## 🙏 謝辞

- **元のCLI**: [PlayCoverManager](https://github.com/HEHEX8/PlayCoverManager) by HEHEX8
- **PlayCover**: [PlayCover](https://github.com/PlayCover/PlayCover) - iOS apps on macOS
- **SwiftUI**: Apple's declarative UI framework

---

**Version:** 6.0.0-alpha1  
**Build Date:** 2025-11-01  
**Status:** Ready for Testing
