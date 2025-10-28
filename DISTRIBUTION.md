# PlayCover Manager - 配布ガイド

## 📦 配布パッケージ

このプロジェクトは、配布しやすい**macOSアプリケーション**形式で提供されます。

### ビルド方法

```bash
# アプリケーションのビルド
./build-app.sh

# 出力ファイル:
# - build/PlayCover Manager.app     (macOSアプリケーション)
# - build/PlayCover Manager-5.0.0.zip  (配布用ZIPファイル)
```

---

## 🚀 配布方法

### 方法1: GitHub Releases（推奨）

1. **ZIPファイルをGitHub Releasesにアップロード**
   ```bash
   # GitHubのReleasesページで新規リリースを作成
   # build/PlayCover Manager-5.0.0.zip をアップロード
   ```

2. **ユーザーはZIPをダウンロード**
   - ZIPを解凍
   - `PlayCover Manager.app`をアプリケーションフォルダにドラッグ&ドロップ

### 方法2: 直接ダウンロード

ZIPファイルを任意のホスティングサービスで配布：
- GitHub Releases
- Google Drive
- Dropbox
- 自社サーバー

---

## 👤 ユーザー向けインストール手順

### インストール

1. **ZIPファイルをダウンロード**
   ```
   PlayCover Manager-5.0.0.zip
   ```

2. **ZIPを解凍**
   - Finderでダブルクリック
   - または: `unzip "PlayCover Manager-5.0.0.zip"`

3. **アプリをApplicationsフォルダに移動**
   ```bash
   mv "PlayCover Manager.app" /Applications/
   ```

### 初回起動

1. **アプリケーションを開く**
   - `右クリック → 開く` を選択
   - または: `control + クリック → 開く`

2. **セキュリティ警告**
   ```
   "PlayCover Manager"は開発元を確認できないため開けません
   ```
   - 「開く」をクリック（初回のみ）

3. **Terminal権限の許可**
   - システム設定 → プライバシーとセキュリティ
   - 「フルディスクアクセス」でTerminalを許可

---

## 🔐 セキュリティとGatekeeper

### Gatekeeper警告を回避する方法

**開発者向け（コード署名）:**

```bash
# Apple Developer IDで署名（有料）
codesign --force --deep --sign "Developer ID Application: Your Name" \
  "build/PlayCover Manager.app"

# 公証（notarization）
xcrun notarytool submit "build/PlayCover Manager-5.0.0.zip" \
  --apple-id "your@email.com" \
  --team-id "YOUR_TEAM_ID" \
  --wait
```

**ユーザー向け（署名なしアプリ）:**

```bash
# Gatekeeper属性を削除（ユーザーが実行）
xattr -cr "/Applications/PlayCover Manager.app"

# その後、通常通りダブルクリックで起動可能
```

---

## 📁 アプリケーション構造

```
PlayCover Manager.app/
├── Contents/
│   ├── Info.plist              # アプリケーション情報
│   ├── MacOS/
│   │   └── PlayCoverManager    # 実行ファイル（main.shのコピー）
│   └── Resources/
│       ├── lib/                # 8つのモジュール
│       │   ├── 00_core.sh
│       │   ├── 01_mapping.sh
│       │   ├── 02_volume.sh
│       │   ├── 03_storage.sh
│       │   ├── 04_app.sh
│       │   ├── 05_cleanup.sh
│       │   ├── 06_setup.sh
│       │   └── 07_ui.sh
│       ├── README.md           # プロジェクトドキュメント
│       ├── README-EN.md        # 英語ドキュメント
│       ├── README.txt          # アプリ内README
│       └── RELEASE_NOTES_5.0.0.md
```

---

## 🛠️ 開発者向け情報

### ビルドスクリプトのカスタマイズ

`build-app.sh`を編集してカスタマイズ可能：

```bash
# バージョン番号
APP_VERSION="5.0.0"

# Bundle ID
BUNDLE_ID="com.playcover.manager"

# 最小システムバージョン
LSMinimumSystemVersion: 15.1
```

### アイコンの追加

1. **アイコンファイルを作成**
   ```bash
   # 複数サイズのPNGファイルを用意
   mkdir AppIcon.iconset
   # 16x16, 32x32, 128x128, 256x256, 512x512 各2x含む
   ```

2. **.icns ファイルを生成**
   ```bash
   iconutil -c icns AppIcon.iconset
   mv AppIcon.icns build/PlayCover\ Manager.app/Contents/Resources/
   ```

3. **Info.plistに追加**
   ```xml
   <key>CFBundleIconFile</key>
   <string>AppIcon</string>
   ```

---

## 📊 ファイルサイズ

```
PlayCover Manager.app: ~70KB (すべてのシェルスクリプト含む)
PlayCover Manager-5.0.0.zip: ~62KB (圧縮後)
```

軽量でダウンロード・配布が容易です。

---

## 🔄 更新とバージョン管理

### 新バージョンのリリース

1. **バージョン番号を更新**
   ```bash
   # build-app.sh
   APP_VERSION="5.1.0"
   
   # main.sh
   # Version: 5.1.0
   ```

2. **ビルドして配布**
   ```bash
   ./build-app.sh
   # build/PlayCover Manager-5.1.0.zip を配布
   ```

3. **GitHub Releaseを作成**
   - タグ: v5.1.0
   - リリースノートを追加
   - ZIPファイルをアップロード

---

## 📮 サポート

- **GitHub Issues**: https://github.com/HEHEX8/PlayCoverManager/issues
- **リポジトリ**: https://github.com/HEHEX8/PlayCoverManager

---

## 📄 ライセンス

MIT License - 自由に配布・改変可能
