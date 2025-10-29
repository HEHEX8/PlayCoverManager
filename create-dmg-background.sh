#!/bin/bash
#######################################################
# DMG背景画像作成
# ドラッグ&ドロップの矢印と説明文を含む背景画像を生成
#######################################################

set -e

BACKGROUND_FILE="dmg-background.png"
WIDTH=660
HEIGHT=400

echo "🎨 DMG背景画像を作成中..."

# macOSで実行されているか確認
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "⚠️  このスクリプトはmacOSで実行してください"
    exit 1
fi

# sipsを使用して背景画像を作成（グラデーション）
# まず、単色の背景を作成
cat > /tmp/create_bg.py << 'PYTHON_EOF'
from PIL import Image, ImageDraw, ImageFont
import sys

# 画像サイズ
width = 660
height = 400

# ライトグレーのグラデーション背景
img = Image.new('RGB', (width, height), color=(200, 208, 214))

# 矢印を描画
draw = ImageDraw.Draw(img)

# 矢印の座標（左側アイコンから右側Applicationsフォルダへ）
arrow_start_x = 240  # 左側アイコンの右側
arrow_end_x = 480    # Applicationsフォルダの左側
arrow_y = 200        # 中央の高さ

# 矢印の線
arrow_color = (100, 100, 100)
line_width = 3

# メインの矢印線
draw.line([(arrow_start_x, arrow_y), (arrow_end_x - 30, arrow_y)], 
          fill=arrow_color, width=line_width)

# 矢印の先端（三角形）
arrow_head = [
    (arrow_end_x - 30, arrow_y - 15),
    (arrow_end_x, arrow_y),
    (arrow_end_x - 30, arrow_y + 15)
]
draw.polygon(arrow_head, fill=arrow_color)

# テキストを追加（ウィンドウ下部）
try:
    # システムフォントを使用
    font = ImageFont.truetype("/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc", 16)
    font_small = ImageFont.truetype("/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc", 13)
except:
    font = ImageFont.load_default()
    font_small = ImageFont.load_default()

text_color = (60, 60, 60)

# メインテキスト
main_text = "👈 アプリを Applications フォルダにドラッグ 👉"
# テキストのバウンディングボックスを取得
bbox = draw.textbbox((0, 0), main_text, font=font)
text_width = bbox[2] - bbox[0]
text_x = (width - text_width) // 2
text_y = 310

draw.text((text_x, text_y), main_text, fill=text_color, font=font)

# サブテキスト
sub_text = "ドラッグ&ドロップでインストール"
bbox2 = draw.textbbox((0, 0), sub_text, font=font_small)
sub_text_width = bbox2[2] - bbox2[0]
sub_x = (width - sub_text_width) // 2
sub_y = text_y + 25

draw.text((sub_x, sub_y), sub_text, fill=(80, 80, 80), font=font_small)

# 保存
img.save('dmg-background.png', 'PNG')
print("✅ 背景画像を作成しました")

PYTHON_EOF

# Pythonで背景画像を作成
if command -v python3 &> /dev/null; then
    python3 /tmp/create_bg.py
    if [ -f "dmg-background.png" ]; then
        echo "✅ 背景画像作成完了: dmg-background.png"
        ls -lh dmg-background.png
        rm /tmp/create_bg.py
    else
        echo "❌ 背景画像の作成に失敗しました"
        exit 1
    fi
else
    echo "❌ Python3が見つかりません"
    echo "   Pythonをインストールするか、手動で背景画像を作成してください"
    exit 1
fi

echo ""
echo "📦 次のステップ:"
echo "   ./create-dmg-applescript.sh を実行してDMGを作成"
