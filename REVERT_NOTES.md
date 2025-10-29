# Zsh復元について

## 🔄 変更内容

元のzsh実装に戻しました。bash変換は不要でした。

---

## ❌ 誤った判断（申し訳ございません）

### 問題の誤診断:
1. **誤**: 「.appバンドルではbashが必要」
2. **誤**: 「zsh構文がbashで動かない」
3. **誤**: 「ANSIエスケープにecho -eが必要」

### 正しい事実:
1. **正**: macOSの標準シェルはzsh（Catalina以降）
2. **正**: `/bin/zsh`は全macOSで利用可能
3. **正**: 元のコードはzshで完璧に動作していた

---

## ✅ 復元内容

### ランチャースクリプト (build-app.sh)

**Before (bash版 - 誤り)**:
```bash
osascript <<EOF
tell application "Terminal"
    activate
    do script "clear && cd '$RESOURCES_DIR' && bash '$MAIN_SCRIPT'"
end tell
EOF
```

**After (zsh版 - 正しい)**:
```bash
osascript <<EOF
tell application "Terminal"
    activate
    do script "clear && cd '$RESOURCES_DIR' && /bin/zsh '$MAIN_SCRIPT'"
end tell
EOF
```

### 配列構文

**Before (bash版 - 不要な変更)**:
```bash
for item in "${array[@]}"; do
```

**After (zsh版 - 元の構文)**:
```zsh
for item in "${(@)array}"; do
```

### Echo文

**Before (bash版 - 不要な-e)**:
```bash
echo -e "${COLOR}テキスト${NC}"
```

**After (zsh版 - 元のまま)**:
```zsh
echo "${COLOR}テキスト${NC}"
```

---

## 📋 技術的背景

### macOSのデフォルトシェル履歴

| macOS バージョン | デフォルトシェル |
|-----------------|-----------------|
| Mojave 以前 | bash |
| **Catalina (10.15) 以降** | **zsh** |
| Big Sur, Monterey, Ventura | zsh |
| Sonoma, Sequoia | zsh |

### なぜzshがベスト？

1. **macOS標準**: Catalina (2019) 以降のデフォルト
2. **フル互換**: `/bin/zsh` は全macOSに存在
3. **高機能**: 配列操作、パス展開などbashより強力
4. **安定動作**: 元のコードで完璧に動いていた

---

## 🚀 現在の正しい実装

### シェル: zsh
- ランチャー: `#!/bin/zsh`
- 実行: `/bin/zsh main-script.sh`

### 配列: zsh構文
```zsh
local -a array
array+=("item")
for item in "${(@)array}"; do
    echo "$item"
done
```

### 色: zshネイティブ
```zsh
echo "${BOLD}${CYAN}テキスト${NC}"
# -e フラグ不要
```

---

## 🎯 macOSでの再ビルド

```bash
cd /Users/hehex/Documents/GitHub/PlayCoverManager
git pull origin main
rm -rf build AppIcon.iconset AppIcon.icns
./create-icon.sh
./build-app.sh
open "build/PlayCover Manager.app"
```

---

## ✨ 結果

- ✅ オリジナルのzsh実装に復元
- ✅ 安定動作が保証される
- ✅ macOS標準に準拠
- ✅ 不要な変換なし

---

## 🙏 お詫び

bash変換は完全に不要でした。

**誤った判断の原因**:
- .appバンドルでの実行環境を誤解
- macOSの標準シェル変更（bash→zsh）を考慮不足
- 元のコードが正しく動作していたことを軽視

**教訓**:
- 動作しているコードを安易に変更しない
- macOSの標準（zsh）を尊重する
- 「標準に従う」ことの重要性

申し訳ございませんでした。
