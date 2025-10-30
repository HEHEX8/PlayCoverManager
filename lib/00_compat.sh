#!/bin/bash
#######################################################
# PlayCover Manager - Shell Compatibility Layer
# Bash/Zsh互換性レイヤー
#######################################################
# 
# このファイルは、zsh専用スクリプトをbash環境でも動作させるための
# 互換性レイヤーを提供します。
#
# 用途:
# - macOS本番環境: zshで実行（このファイルは不要）
# - sandbox環境: bashで実行（このファイルで互換性を提供）
#

#######################################################
# シェル検出
#######################################################

# 現在のシェルを検出
if [ -n "$ZSH_VERSION" ]; then
    CURRENT_SHELL="zsh"
    SHELL_VERSION="$ZSH_VERSION"
elif [ -n "$BASH_VERSION" ]; then
    CURRENT_SHELL="bash"
    SHELL_VERSION="$BASH_VERSION"
else
    CURRENT_SHELL="unknown"
    SHELL_VERSION="unknown"
fi

# デバッグ情報
if [[ "${DEBUG_COMPAT:-}" == "1" ]]; then
    echo "🐚 Shell Compatibility Layer"
    echo "   Current Shell: $CURRENT_SHELL"
    echo "   Version: $SHELL_VERSION"
fi

#######################################################
# Bash互換性関数
#######################################################

if [[ "$CURRENT_SHELL" == "bash" ]]; then
    # bashでは連想配列は bash 4.0+ が必要
    if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
        echo "エラー: Bash 4.0以降が必要です（現在: ${BASH_VERSION}）" >&2
        exit 1
    fi
    
    # zshの ${(@)array} 構文をbashの ${array[@]} に変換
    # 注意: これはコード内で手動で対応する必要があります
    # 以下は互換性のためのヘルパー関数です
    
    # 配列のすべての要素を取得（zsh互換）
    # 使用例: array_all ARRAY_NAME
    array_all() {
        local array_name="$1"
        local -n arr="$array_name"
        printf '%s\n' "${arr[@]}"
    }
    
    # 配列の要素数を取得（zsh互換）
    # 使用例: array_count ARRAY_NAME
    array_count() {
        local array_name="$1"
        local -n arr="$array_name"
        echo "${#arr[@]}"
    }
    
    # 連想配列のキーを取得（zsh互換）
    # 使用例: array_keys ASSOC_ARRAY_NAME
    array_keys() {
        local array_name="$1"
        local -n arr="$array_name"
        printf '%s\n' "${!arr[@]}"
    }
fi

#######################################################
# スクリプトディレクトリ検出（互換版）
#######################################################

# zshとbash両方で動作するスクリプトディレクトリ取得
get_script_dir() {
    local script_path=""
    
    if [[ -n "${BASH_SOURCE[0]}" ]]; then
        # Bash
        script_path="${BASH_SOURCE[0]}"
    elif [[ -n "${(%):-%x}" ]] 2>/dev/null; then
        # Zsh（エラーを無視）
        script_path="${(%):-%x}"
    elif [[ -n "$0" ]]; then
        # Fallback
        script_path="$0"
    else
        echo "." # 最終フォールバック
        return 1
    fi
    
    # ディレクトリを取得
    local dir_path="$(cd "$(dirname "$script_path")/.." 2>/dev/null && pwd)"
    
    if [[ -n "$dir_path" ]]; then
        echo "$dir_path"
        return 0
    else
        echo "."
        return 1
    fi
}

#######################################################
# 配列操作互換関数
#######################################################

# 配列に要素を追加（zsh/bash互換）
# 使用例: array_append ARRAY_NAME "value"
array_append() {
    local array_name="$1"
    shift
    
    if [[ "$CURRENT_SHELL" == "zsh" ]]; then
        eval "$array_name+=(\"\$@\")"
    else
        local -n arr="$array_name"
        arr+=("$@")
    fi
}

# 配列から要素を削除（zsh/bash互換）
# 使用例: array_remove ARRAY_NAME index
array_remove() {
    local array_name="$1"
    local index="$2"
    
    if [[ "$CURRENT_SHELL" == "zsh" ]]; then
        # zshは1-indexed
        eval "$array_name[$((index))]=()"
    else
        # bashは0-indexed
        local -n arr="$array_name"
        unset "arr[$index]"
        # 配列を再構築して隙間を埋める
        arr=("${arr[@]}")
    fi
}

#######################################################
# 互換性チェック
#######################################################

# 必要な機能が利用可能かチェック
check_shell_compatibility() {
    local errors=0
    
    # 連想配列のサポートチェック
    if [[ "$CURRENT_SHELL" == "bash" ]]; then
        if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
            echo "❌ エラー: 連想配列はBash 4.0以降が必要です" >&2
            errors=$((errors + 1))
        fi
    fi
    
    # 基本的なコマンドの存在確認
    local required_commands="grep sed awk tr cut"
    for cmd in $required_commands; do
        if ! command -v "$cmd" &>/dev/null; then
            echo "❌ エラー: 必須コマンド '$cmd' が見つかりません" >&2
            errors=$((errors + 1))
        fi
    done
    
    if [[ $errors -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

#######################################################
# 互換性レイヤーの初期化
#######################################################

# 互換性チェックを実行（オプション）
if [[ "${AUTO_CHECK_COMPAT:-1}" == "1" ]]; then
    if ! check_shell_compatibility; then
        echo "⚠️  互換性の問題が検出されました" >&2
        # エラーを無視して続行する場合はコメントアウト
        # exit 1
    fi
fi

# デバッグ情報
if [[ "${DEBUG_COMPAT:-}" == "1" ]]; then
    echo "✅ Compatibility layer loaded successfully"
fi
