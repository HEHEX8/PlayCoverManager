#!/bin/bash

# PlayCover Manager GUI ビルドスクリプト
# このスクリプトはSwift Package Managerを使用してアプリをビルドします

set -e

echo "================================"
echo "PlayCover Manager GUI ビルド"
echo "================================"
echo ""

# カレントディレクトリの確認
if [ ! -f "Package.swift" ]; then
    echo "❌ エラー: Package.swift が見つかりません"
    echo "このスクリプトはプロジェクトルートで実行してください"
    exit 1
fi

# Swiftバージョンの確認
echo "📋 Swift バージョン確認..."
swift --version
echo ""

# クリーンビルド
echo "🧹 クリーンビルド..."
swift package clean
echo ""

# 依存関係の解決
echo "📦 依存関係の解決..."
swift package resolve
echo ""

# ビルド
echo "🔨 ビルド開始..."
swift build -c release
echo ""

# ビルド成果物の場所を表示
BUILD_DIR=$(swift build -c release --show-bin-path)
echo "✅ ビルド完了！"
echo ""
echo "📁 実行ファイルの場所:"
echo "   $BUILD_DIR/PlayCoverManagerGUI"
echo ""
echo "🚀 実行方法:"
echo "   $BUILD_DIR/PlayCoverManagerGUI"
echo ""
echo "または:"
echo "   swift run -c release PlayCoverManagerGUI"
echo ""

# 実行可能か確認
if [ -f "$BUILD_DIR/PlayCoverManagerGUI" ]; then
    echo "✨ ビルド成功！アプリを実行できます。"
else
    echo "⚠️  警告: 実行ファイルが見つかりません"
    exit 1
fi
