#!/bin/bash
#######################################################
# DMG背景画像作成 v2（正しい座標系）
# create-dmgの座標はアイコンの「左上」基準
#######################################################

set -e

BACKGROUND_FILE="dmg-background.png"

# 推奨サイズ（標準的なDMGウィンドウ）
WIDTH=660
HEIGHT=400

echo "🎨 DMG背景画像を作成中（v2 - 正しい座標系）..."

# macOSで実行されているか確認
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "⚠️  このスクリプトはmacOSで実行してください"
    exit 1
fi

# Pythonスクリプトを作成
cat > /tmp/create_bg_v2.py << 'PYTHON_EOF'
from PIL import Image, ImageDraw, ImageFont

# 画像サイズ（ウィンドウサイズと同じ）
WIDTH = 660
HEIGHT = 400

# アイコンサイズ
ICON_SIZE = 128

# アイコン位置の計算（左上座標）
# 左アイコン: 左から1/6の位置
LEFT_ICON_X = int(WIDTH / 6)
LEFT_ICON_Y = int((HEIGHT - ICON_SIZE) / 2) - 20

# 右アイコン: 右から1/6の位置
RIGHT_ICON_X = int(WIDTH * 5 / 6) - ICON_SIZE
RIGHT_ICON_Y = LEFT_ICON_Y

# デバッグ情報を出力
print(f"📐 画像サイズ: {WIDTH}x{HEIGHT}")
print(f"🔷 アイコンサイズ: {ICON_SIZE}x{ICON_SIZE}")
print(f"📍 左アイコン位置（左上）: ({LEFT_ICON_X}, {LEFT_ICON_Y})")
print(f"📍 右アイコン位置（左上）: ({RIGHT_ICON_X}, {RIGHT_ICON_Y})")

# 中心座標を計算（デバッグ用）
left_center_x = LEFT_ICON_X + ICON_SIZE // 2
left_center_y = LEFT_ICON_Y + ICON_SIZE // 2
right_center_x = RIGHT_ICON_X + ICON_SIZE // 2
right_center_y = RIGHT_ICON_Y + ICON_SIZE // 2

print(f"🎯 左アイコン中心: ({left_center_x}, {left_center_y})")
print(f"🎯 右アイコン中心: ({right_center_x}, {right_center_y})")

# 矢印の中心位置
arrow_center_x = (left_center_x + right_center_x) // 2
arrow_y = left_center_y

print(f"➡️  矢印中心: x={arrow_center_x}, y={arrow_y}")

# ライトグレーの背景
img = Image.new('RGB', (WIDTH, HEIGHT), color=(200, 208, 214))
draw = ImageDraw.Draw(img)

# 矢印を描画（2つのアイコンの中心を結ぶ）
arrow_length = 100
arrow_start_x = arrow_center_x - arrow_length // 2
arrow_end_x = arrow_center_x + arrow_length // 2

# 矢印の色（濃いグレー）
arrow_color = (70, 70, 70)
line_width = 5

# メイン矢印線（太い線）
for offset in [-2, 0, 2]:
    draw.line(
        [(arrow_start_x, arrow_y + offset), (arrow_end_x - 30, arrow_y + offset)],
        fill=arrow_color,
        width=line_width
    )

# 矢印の先端（三角形）
arrow_head_size = 20
arrow_head = [
    (arrow_end_x - 35, arrow_y - arrow_head_size),
    (arrow_end_x, arrow_y),
    (arrow_end_x - 35, arrow_y + arrow_head_size)
]
draw.polygon(arrow_head, fill=arrow_color)

# テキストを追加
try:
    # ヒラギノ角ゴシック
    font_main = ImageFont.truetype("/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc", 20)
    font_sub = ImageFont.truetype("/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc", 14)
except:
    try:
        # San Francisco フォント
        font_main = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 20)
        font_sub = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", 14)
    except:
        font_main = ImageFont.load_default()
        font_sub = ImageFont.load_default()

# メインテキスト（アイコン下部）
main_text = "ドラッグ&ドロップでインストール"
bbox = draw.textbbox((0, 0), main_text, font=font_main)
text_width = bbox[2] - bbox[0]
text_x = (WIDTH - text_width) // 2
text_y = LEFT_ICON_Y + ICON_SIZE + 50

# テキストに影を追加
shadow_offset = 2
draw.text(
    (text_x + shadow_offset, text_y + shadow_offset),
    main_text,
    fill=(255, 255, 255, 180),
    font=font_main
)
draw.text((text_x, text_y), main_text, fill=(40, 40, 40), font=font_main)

# サブテキスト
sub_text = "左のアプリを右のフォルダへ"
bbox2 = draw.textbbox((0, 0), sub_text, font=font_sub)
sub_width = bbox2[2] - bbox2[0]
sub_x = (WIDTH - sub_width) // 2
sub_y = text_y + 30

draw.text(
    (sub_x + 1, sub_y + 1),
    sub_text,
    fill=(255, 255, 255, 150),
    font=font_sub
)
draw.text((sub_x, sub_y), sub_text, fill=(60, 60, 60), font=font_sub)

# 保存
img.save('dmg-background.png', 'PNG')
print("✅ 背景画像を作成しました: dmg-background.png")
print(f"📦 次のステップ: create-dmgで座標 ({LEFT_ICON_X}, {LEFT_ICON_Y}) と ({RIGHT_ICON_X}, {RIGHT_ICON_Y}) を使用")

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
    
    python3 /tmp/create_bg_v2.py
    if [ -f "dmg-background.png" ]; then
        echo ""
        echo "✅ 背景画像作成完了: dmg-background.png"
        ls -lh dmg-background.png
        file dmg-background.png
        rm /tmp/create_bg_v2.py
    else
        echo "❌ 背景画像の作成に失敗しました"
        rm /tmp/create_bg_v2.py
        exit 1
    fi
else
    echo "❌ Python3が見つかりません"
    echo "   Homebrewでインストール: brew install python3"
    exit 1
fi
