# Xcode ビルドガイド

## 📖 目次

1. [Xcodeで開く](#xcodeで開く)
2. [プロジェクト設定](#プロジェクト設定)
3. [ビルド実行](#ビルド実行)
4. [トラブルシューティング](#トラブルシューティング)
5. [よくある質問](#よくある質問)

---

## 1. Xcodeで開く

### ステップ1-1: ターミナルから開く

```bash
# プロジェクトディレクトリに移動
cd /path/to/PlayCoverManager/PlayCoverManagerGUI

# Xcodeで開く
open Package.swift
```

**重要:** `Package.swift` を直接開いてください。`.xcodeproj`や`.xcworkspace`ではありません。

### ステップ1-2: Finderから開く

1. Finderで `PlayCoverManagerGUI` フォルダを開く
2. `Package.swift` を右クリック
3. 「このアプリケーションで開く」→「Xcode」を選択

### ステップ1-3: Xcode内から開く

1. Xcodeを起動
2. メニューバーから「File」→「Open」
3. `PlayCoverManagerGUI/Package.swift` を選択
4. 「Open」をクリック

---

## 2. プロジェクト設定

### ステップ2-1: スキームの選択

Xcodeが開いたら、左上のスキーム選択メニューで：

1. **Product Scheme**: `PlayCoverManagerGUI` を選択
2. **Destination**: `My Mac` を選択

```
┌────────────────────────────────────┐
│ PlayCoverManagerGUI > My Mac       │  ← ここをクリック
└────────────────────────────────────┘
```

### ステップ2-2: 署名設定（初回のみ）

1. 左側のプロジェクトナビゲータで `PlayCoverManagerGUI` を選択
2. 中央で「Signing & Capabilities」タブを選択
3. 「Team」ドロップダウンから開発チームを選択
   - Apple IDでログインしていない場合は「Add Account」からログイン
   - 個人開発の場合は自分のApple IDでOK（無料）

```
Signing & Capabilities
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
☑ Automatically manage signing

Team: [Your Team Name] ▼         ← ここを設定

Bundle Identifier: io.playcover.PlayCoverManager
```

**注意:** 「Automatically manage signing」にチェックを入れておくことを推奨します。

---

## 3. ビルド実行

### ステップ3-1: クリーンビルド（推奨）

初回ビルドや、問題がある場合は：

1. メニューバー「Product」→「Clean Build Folder」
2. または ⇧⌘K（Shift + Command + K）

### ステップ3-2: ビルド

**方法A: メニューから**
1. メニューバー「Product」→「Build」
2. またはショートカット ⌘B（Command + B）

**方法B: 実行ボタン**
1. 左上の再生ボタン（▶️）をクリック
2. またはショートカット ⌘R（Command + R）

### ステップ3-3: ビルド進行状況

ビルドが開始されると：

```
Building PlayCoverManagerGUI...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Compiling Swift source files...
Linking...
Copying resources...

Build succeeded  ← 成功！
```

上部中央に進行状況が表示されます。

---

## 4. トラブルシューティング

### 問題1: "No signing certificate found"

**原因**: 開発証明書が設定されていない

**解決方法**:
1. Xcode > Preferences (⌘,)
2. 「Accounts」タブ
3. Apple IDを追加
4. 「Manage Certificates」で証明書を確認
5. プロジェクト設定で「Automatically manage signing」を有効化

### 問題2: "Build failed - Swift Compiler Error"

**原因**: Swift バージョンの不一致や構文エラー

**解決方法**:
```bash
# ターミナルで確認
swift --version

# Swift 5.9 以上が必要
# Xcodeを最新版にアップデート
```

エラーメッセージを確認：
1. 左側の「Issue Navigator」（⚠️アイコン）をクリック
2. エラー内容を確認
3. ファイル名をクリックすると該当箇所に移動

### 問題3: "Module not found"

**原因**: 依存関係の解決が必要

**解決方法**:
1. メニューバー「File」→「Packages」→「Reset Package Caches」
2. メニューバー「File」→「Packages」→「Resolve Package Versions」
3. クリーンビルド（⇧⌘K）後、再ビルド（⌘B）

または、ターミナルで：
```bash
cd PlayCoverManagerGUI
swift package clean
swift package resolve
```

### 問題4: "PlayCoverManagerGUI has no scheme"

**原因**: スキームが生成されていない

**解決方法**:
1. メニューバー「Product」→「Scheme」→「New Scheme」
2. または：Xcodeを閉じて `Package.swift` を再度開く

### 問題5: ビルドは成功するが実行できない

**原因**: 実行権限やパスの問題

**解決方法**:
1. メニューバー「Product」→「Scheme」→「Edit Scheme」
2. 左側で「Run」を選択
3. 「Info」タブで「Executable」が正しく設定されているか確認

---

## 5. よくある質問

### Q1: ビルドにどれくらい時間がかかりますか？

**A**: 
- 初回ビルド: 3-5分（依存関係の解決含む）
- 2回目以降: 30秒-1分（変更箇所のみ）

### Q2: デバッグビルドとリリースビルドの違いは？

**A**:
```
デバッグビルド（Debug）:
- デフォルトの設定
- 最適化なし
- デバッグシンボル含む
- ファイルサイズ大きい
- ビルドが速い

リリースビルド（Release）:
- 最適化あり
- デバッグシンボルなし
- ファイルサイズ小さい
- ビルドが遅い
- 実行速度が速い
```

リリースビルドに切り替えるには：
1. スキーム選択メニューをクリック
2. 「Edit Scheme」
3. 左側で「Run」を選択
4. 「Build Configuration」を「Release」に変更

### Q3: ビルド成果物はどこに保存されますか？

**A**: 
```bash
# デバッグビルド
~/Library/Developer/Xcode/DerivedData/PlayCoverManagerGUI-*/Build/Products/Debug/PlayCoverManagerGUI

# リリースビルド
~/Library/Developer/Xcode/DerivedData/PlayCoverManagerGUI-*/Build/Products/Release/PlayCoverManagerGUI
```

または、Xcode内で：
1. 「Product」メニューから実行後
2. 左側の「Products」フォルダを展開
3. `PlayCoverManagerGUI` を右クリック
4. 「Show in Finder」を選択

### Q4: コード署名なしでビルドできますか？

**A**: 
いいえ、macOSアプリは必ずコード署名が必要です。ただし：
- 開発用署名は無料のApple IDで可能
- 自分のMacでのみ実行可能
- 配布する場合は有料のDeveloper Programが必要（年$99）

### Q5: Xcodeの推奨設定は？

**A**:
```
Xcode > Preferences

General:
- Show live issues: ON
- Show inline messages: ON

Text Editing:
- Show line numbers: ON
- Code completion: ON
- Auto-indent: ON

Behaviors:
- Build succeeds: Play sound (任意)
- Build fails: Play sound (任意)
```

---

## 6. ビルド後の確認

### ステップ6-1: アプリの起動

ビルド成功後、自動的にアプリが起動します。

または手動で：
1. 「Product」→「Run」（⌘R）
2. 左上の再生ボタン（▶️）をクリック

### ステップ6-2: 動作確認

起動後、以下を確認：

1. **初回セットアップウィザード**
   - 4ステップのウィザードが表示される
   - 外部ドライブ選択（ある場合）
   - ボリューム作成設定

2. **メイン画面**
   - サイドバーが表示される
   - タブが正しく表示される
   - ホバーエフェクトが動作する

3. **基本機能**
   - タブ切り替え
   - 設定画面の表示
   - テーマ変更

### ステップ6-3: デバッグ出力の確認

ビルド後、下部の「Debug area」でログを確認：

```
Console output
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[INFO] [system] PlayCover Manager GUI started
[INFO] [application] Loaded 0 applications
[DEBUG] [system] Checking initial setup...
```

表示されない場合：
- 右上の「Show debug area」ボタン（⌘⇧Y）

---

## 7. Xcodeのキーボードショートカット

| 操作 | ショートカット |
|------|---------------|
| ビルド | ⌘B |
| 実行 | ⌘R |
| 停止 | ⌘. |
| クリーンビルド | ⇧⌘K |
| 設定 | ⌘, |
| クイックオープン | ⇧⌘O |
| ファイル検索 | ⌘⇧F |
| デバッグエリア表示 | ⌘⇧Y |
| ナビゲータ表示 | ⌘0 |
| プロジェクトナビゲータ | ⌘1 |
| Issue Navigator | ⌘5 |

---

## 8. 次のステップ

ビルドが成功したら：

1. **機能テスト**
   - 各タブの動作確認
   - ボリューム操作のテスト
   - エラーハンドリングの確認

2. **パフォーマンス確認**
   - 起動時間の計測
   - メモリ使用量の確認
   - CPU使用率の確認

3. **バグ修正**
   - クラッシュログの確認
   - エッジケースの対応

4. **リリースビルド**
   - Release 設定でビルド
   - パフォーマンステスト
   - DMG作成準備

---

## 📞 サポート

問題が解決しない場合：

1. **Xcodeの再起動**: 多くの問題はこれで解決
2. **Mac の再起動**: メモリリークなどの問題
3. **Xcode のアップデート**: 最新版に更新
4. **GitHub Issues**: [PlayCoverManager/issues](https://github.com/HEHEX8/PlayCoverManager/issues)

---

## 🎓 参考リンク

- [Xcode 公式ドキュメント](https://developer.apple.com/documentation/xcode)
- [Swift Package Manager ガイド](https://www.swift.org/package-manager/)
- [SwiftUI チュートリアル](https://developer.apple.com/tutorials/swiftui)

---

**ビルド成功を祈っています！** 🚀

---

最終更新: 2025-11-01
