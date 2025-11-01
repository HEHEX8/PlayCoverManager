.PHONY: build run clean release test help

# デフォルトターゲット
.DEFAULT_GOAL := help

# 変数
PRODUCT_NAME = PlayCoverManagerGUI
BUILD_DIR = .build
RELEASE_DIR = $(BUILD_DIR)/release
DEBUG_DIR = $(BUILD_DIR)/debug

# ヘルプ
help:
	@echo "================================"
	@echo "PlayCover Manager GUI ビルドタスク"
	@echo "================================"
	@echo ""
	@echo "使用可能なコマンド:"
	@echo "  make build      - デバッグビルド"
	@echo "  make release    - リリースビルド"
	@echo "  make run        - デバッグビルドして実行"
	@echo "  make run-release - リリースビルドして実行"
	@echo "  make clean      - ビルド成果物を削除"
	@echo "  make test       - テストを実行"
	@echo "  make resolve    - 依存関係を解決"
	@echo "  make xcode      - Xcodeで開く"
	@echo "  make help       - このヘルプを表示"
	@echo ""

# デバッグビルド
build:
	@echo "🔨 デバッグビルド中..."
	swift build
	@echo "✅ ビルド完了!"

# リリースビルド
release:
	@echo "🔨 リリースビルド中..."
	swift build -c release
	@echo "✅ リリースビルド完了!"
	@echo "📁 実行ファイル: $(RELEASE_DIR)/$(PRODUCT_NAME)"

# デバッグ実行
run: build
	@echo "🚀 アプリを起動中..."
	swift run

# リリース実行
run-release: release
	@echo "🚀 リリース版を起動中..."
	$(RELEASE_DIR)/$(PRODUCT_NAME)

# クリーン
clean:
	@echo "🧹 クリーン中..."
	swift package clean
	@echo "✅ クリーン完了!"

# テスト
test:
	@echo "🧪 テスト実行中..."
	swift test
	@echo "✅ テスト完了!"

# 依存関係の解決
resolve:
	@echo "📦 依存関係を解決中..."
	swift package resolve
	@echo "✅ 解決完了!"

# Xcodeで開く
xcode:
	@echo "🔧 Xcodeで開く..."
	open Package.swift

# すべてクリーンしてからリビルド
rebuild: clean build

# すべてクリーンしてからリリースビルド
rebuild-release: clean release

# バージョン情報
version:
	@echo "📋 バージョン情報"
	@echo "Product: $(PRODUCT_NAME)"
	@echo "Version: 6.0.0-alpha1"
	@echo ""
	@swift --version
