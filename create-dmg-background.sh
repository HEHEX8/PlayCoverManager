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

# Pythonスクリプトを作成
cat > /tmp/create_bg.py << 'PYTHON_EOF'
from PIL import Image, ImageDraw, ImageFont

# 画像サイズ
width = 660
height = 400

# ライトグレーの背景（DMGと同じ色）
img = Image.new('RGB', (width, height), color=(200, 208, 214))

draw = ImageDraw.Draw(img)

# 矢印を描画（2つのアイコンの間の空間の中央に配置）
# アイコン位置: 左=160, 右=500, y=185
# アイコンサイズ: 128x128
left_icon_right_edge = 160 + 128  # = 288
right_icon_left_edge = 500 - 64   # = 436 (Applicationsフォルダは中心が500)

# 空間の中央を計算
space_center = (left_icon_right_edge + right_icon_left_edge) // 2  # = 362

# 矢印のサイズ
arrow_length = 80
arrow_start_x = space_center - arrow_length // 2  # 362 - 40 = 322
arrow_end_x = space_center + arrow_length // 2    # 362 + 40 = 402
arrow_y = 185 + 64  # アイコンの中心の高さ（185 + 128/2）

# 矢印の色（濃いグレー）
arrow_color = (80, 80, 80)
line_width = 4

# メイン矢印線（3本の線で太く見せる）
for offset in [-2, 0, 2]:
    draw.line([(arrow_start_x, arrow_y + offset), (arrow_end_x - 25, arrow_y + offset)], 
              fill=arrow_color, width=line_width)

# 矢印の先端（大きめの三角形）
arrow_head = [
    (arrow_end_x - 30, arrow_y - 15),
    (arrow_end_x, arrow_y),
    (arrow_end_x - 30, arrow_y + 15)
]
draw.polygon(arrow_head, fill=arrow_color)

# テキストを追加
try:
    # ヒラギノ角ゴシック
    font_main = ImageFont.truetype("/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc", 18)
    font_sub = ImageFont.truetype("/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc", 14)
except:
    try:
        # San Francisco フォント
        font_main = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 18)
        font_sub = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 14)
    except:
        font_main = ImageFont.load_default()
        font_sub = ImageFont.load_default()

# メインテキスト（アイコン上部）
main_text = "ドラッグ&ドロップでインストール"
bbox = draw.textbbox((0, 0), main_text, font=font_main)
text_width = bbox[2] - bbox[0]
text_x = (width - text_width) // 2
text_y = 320

# テキストに影を追加（読みやすく）
shadow_offset = 2
draw.text((text_x + shadow_offset, text_y + shadow_offset), main_text, fill=(255, 255, 255, 180), font=font_main)
draw.text((text_x, text_y), main_text, fill=(50, 50, 50), font=font_main)

# サブテキスト（小さめ）
sub_text = "左のアプリを右のフォルダへ"
bbox2 = draw.textbbox((0, 0), sub_text, font=font_sub)
sub_width = bbox2[2] - bbox2[0]
sub_x = (width - sub_width) // 2
sub_y = text_y + 28

draw.text((sub_x + 1, sub_y + 1), sub_text, fill=(255, 255, 255, 150), font=font_sub)
draw.text((sub_x, sub_y), sub_text, fill=(70, 70, 70), font=font_sub)

# 保存
img.save('dmg-background.png', 'PNG')
print("✅ 背景画像を作成しました: dmg-background.png")

PYTHON_EOF

# Pythonで背景画像を作成
if command -v python3 &> /dev/null; then
    # PILがインストールされているか確認
    if ! python3 -c "import PIL" 2>/dev/null; then
        echo "📦 Pillow (PIL) をインストール中..."
        python3 -m pip install --user Pillow --quiet || {
            echo "❌ Pillow のインストールに失敗しました"
            echo "   手動でインストールしてください: python3 -m pip install Pillow"
            exit 1
        }
    fi
    
    python3 /tmp/create_bg.py
    if [ -f "dmg-background.png" ]; then
        echo "✅ 背景画像作成完了: dmg-background.png"
        ls -lh dmg-background.png
        file dmg-background.png
        rm /tmp/create_bg.py
        echo ""
        echo "📦 次のステップ:"
        echo "   ./create-dmg-applescript.sh を実行してDMGを作成"
    else
        echo "❌ 背景画像の作成に失敗しました"
        rm /tmp/create_bg.py
        exit 1
    fi
else
    echo "❌ Python3が見つかりません"
    echo "   Homebrewでインストール: brew install python3"
    exit 1
fi
