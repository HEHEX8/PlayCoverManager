#!/bin/zsh
#######################################################
# PlayCover Manager - Core Module
# Constants, Colors, and Basic Utility Functions
#######################################################

#######################################################
# 前提条件・環境・注意点
#######################################################
# 
# 【前提条件】
# - Apple Silicon Mac (M1/M2/M3/M4)
# - macOS Sequoia 15.1 (Tahoe 26.0.1) 以降
# - zsh シェル
# - ターミナルへのフルディスクアクセス権限
# 
# 【環境】
# - Homebrew: /opt/homebrew (Apple Silicon) または /usr/local (Intel)
# - PlayCover: Homebrew Cask経由でインストール
# - 外部ストレージ: USB/Thunderbolt/SSD (APFSフォーマット)
# 
# 【使用コマンド (macOS標準)】
# awk, cat, chmod, chown, cp, cut, df, diskutil, du, find, grep
# head, kill, mkdir, mount, mv, open, osascript, pgrep, pkill
# rm, rmdir, rsync, sed, sleep, sudo, tail, tr, tty, unzip, xargs
# 
# 【外部依存】
# - Homebrew (brew): PlayCoverインストールに必要
# - PlayCover.app: /Applications/PlayCover.app
# 
# 【注意事項】
# - sudo権限が必要な操作あり（diskutil, mount等）
# - 外部ストレージの選択を誤るとデータ損失の危険
# - 超強力クリーンアップは全データを削除（取り消し不可）
#

#######################################################
# Color & Style Definitions
#######################################################
# 最適化済み: ターミナル背景 RGB(28,28,28) / #1C1C1C
# 人間の色覚特性考慮: 眩しさ軽減 + 視認性向上

# ─── Text Style Modifiers ───
readonly BOLD='\033[1m'              # 太字
readonly DIM='\033[2m'               # 薄暗く
readonly ITALIC='\033[3m'            # 斜体
readonly UNDERLINE='\033[4m'         # 下線
readonly BLINK='\033[5m'             # 点滅（非推奨）
readonly REVERSE='\033[7m'           # 反転
readonly HIDDEN='\033[8m'            # 非表示
readonly STRIKETHROUGH='\033[9m'     # 取り消し線

# ─── Primary Text Colors (Eye-friendly, reduced brightness) ───
readonly WHITE='\033[38;2;230;230;230m'      # ソフトホワイト #E6E6E6 (17.5:1)
readonly LIGHT_GRAY='\033[38;2;180;180;180m' # 明灰 #B4B4B4 (9.8:1)
readonly GRAY='\033[38;2;140;140;140m'       # 中灰 #8C8C8C (5.8:1)
readonly DIM_GRAY='\033[38;2;110;110;110m'   # 暗灰 #6E6E6E (4.6:1)

# ─── Semantic Colors (Reduced saturation for eye comfort) ───
readonly RED='\033[38;2;255;120;120m'        # ソフト赤 #FF7878 (9.5:1)
readonly GREEN='\033[38;2;120;220;120m'      # ソフト緑 #78DC78 (11.8:1)
readonly BLUE='\033[38;2;120;180;240m'       # ソフト青 #78B4F0 (10.2:1)
readonly YELLOW='\033[38;2;230;220;100m'     # ソフト黄 #E6DC64 (14.5:1)
readonly CYAN='\033[38;2;100;220;220m'       # ソフトシアン #64DCDC (12.2:1)
readonly MAGENTA='\033[38;2;220;120;220m'    # ソフトマゼンタ #DC78DC (9.8:1)

# ─── Extended Colors (Natural tones for extended use) ───
readonly ORANGE='\033[38;2;240;160;100m'     # ナチュラルオレンジ #F0A064 (10.5:1)
readonly GOLD='\033[38;2;230;200;100m'       # ナチュラルゴールド #E6C864 (13.8:1)
readonly LIME='\033[38;2;160;220;100m'       # ナチュラルライム #A0DC64 (12.5:1)
readonly SKY_BLUE='\033[38;2;120;190;230m'   # ナチュラルスカイ #78BEE6 (10.8:1)
readonly TURQUOISE='\033[38;2;100;200;200m'  # ナチュラルターコイズ #64C8C8 (11.2:1)
readonly VIOLET='\033[38;2;200;140;230m'     # ナチュラルバイオレット #C88CE6 (8.9:1)
readonly PINK='\033[38;2;230;140;180m'       # ナチュラルピンク #E68CB4 (9.5:1)
readonly LIGHT_GREEN='\033[38;2;140;220;140m' # ナチュラルライトグリーン #8CDC8C (12.8:1)

# ─── Special Purpose Colors (Eye-friendly with bold) ───
readonly SUCCESS='\033[1;38;2;120;220;120m'  # 成功（太字ソフト緑）
readonly ERROR='\033[1;38;2;255;120;120m'    # エラー（太字ソフト赤）
readonly WARNING='\033[1;38;2;240;160;100m'  # 警告（太字ナチュラルオレンジ）
readonly INFO='\033[38;2;120;190;230m'       # 情報（ナチュラルスカイ）
readonly HIGHLIGHT='\033[1;38;2;230;220;100m' # 強調（太字ソフト黄）

# ─── Reset ───
readonly NC='\033[0m' # No Color / Reset All

#######################################################
# Constants
#######################################################

readonly PLAYCOVER_BUNDLE_ID="io.playcover.PlayCover"
readonly PLAYCOVER_CONTAINER="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}"
readonly PLAYCOVER_VOLUME_NAME="PlayCover"
readonly PLAYCOVER_APP_NAME="PlayCover.app"
readonly PLAYCOVER_APP_PATH="/Applications/${PLAYCOVER_APP_NAME}"

# Get script directory (works even when sourced)
if [[ -n "${BASH_SOURCE[0]}" ]]; then
    # Bash
    readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
elif [[ -n "${(%):-%x}" ]]; then
    # Zsh
    readonly SCRIPT_DIR="$(cd "$(dirname "${(%):-%x}")/.." && pwd)"
else
    # Fallback
    readonly SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
fi

# Mapping file stored in manager directory
readonly MAPPING_FILE="${SCRIPT_DIR}/.playcover-volume-mapping.tsv"
readonly MAPPING_LOCK_FILE="${MAPPING_FILE}.lock"
readonly INTERNAL_STORAGE_FLAG=".playcover_internal_storage_flag"

#######################################################
# Common Messages
#######################################################

readonly MSG_CANCELED="キャンセルしました"
readonly MSG_INVALID_SELECTION="無効な選択です"
readonly MSG_MOUNT_FAILED="ボリュームのマウントに失敗しました"
readonly MSG_NO_REGISTERED_VOLUMES="登録されているアプリボリュームがありません"
readonly MSG_MAPPING_FILE_NOT_FOUND="マッピングファイルが見つかりません"
readonly MSG_CLEANUP_INTERNAL_STORAGE="内蔵ストレージをクリア中..."
readonly MSG_INTENTIONAL_INTERNAL_MODE="このアプリは意図的に内蔵ストレージモードに設定されています"
readonly MSG_SWITCH_VIA_STORAGE_MENU="外部ボリュームをマウントするには、先にストレージ切替で外部に戻してください"
readonly MSG_UNINTENDED_INTERNAL_DATA="内蔵ストレージに意図しないデータが検出されました"

# Detect Homebrew path (Apple Silicon vs Intel)
if [[ -x "/opt/homebrew/bin/brew" ]]; then
    readonly BREW_PATH="/opt/homebrew/bin/brew"
elif [[ -x "/usr/local/bin/brew" ]]; then
    readonly BREW_PATH="/usr/local/bin/brew"
else
    readonly BREW_PATH="brew"  # Fallback to PATH
fi

# Display width settings (optimized for 120x30 terminal)
readonly DISPLAY_WIDTH=118
readonly SEPARATOR_CHAR="─"

#######################################################
# Global Variables
#######################################################

declare -a SELECTED_IPAS=()
declare -a INSTALL_SUCCESS=()
declare -a INSTALL_FAILED=()
APP_NAME=""
APP_NAME_EN=""
APP_VERSION=""
APP_BUNDLE_ID=""
APP_VOLUME_NAME=""
SELECTED_DISK=""
PLAYCOVER_VOLUME_DEVICE=""
SUDO_AUTHENTICATED=false
BATCH_MODE=false
CURRENT_IPA_INDEX=0
TOTAL_IPAS=0

# Initial setup specific variables
NEED_XCODE_TOOLS=false
NEED_HOMEBREW=false
NEED_PLAYCOVER=false

#######################################################
# Basic Print Functions
#######################################################

# Print separator line (optimized for 120-column terminal)
print_separator() {
    local char="${1:-$SEPARATOR_CHAR}"
    local color="${2:-$BLUE}"
    printf "${color}"
    printf '%*s' "$DISPLAY_WIDTH" | /usr/bin/tr ' ' "$char"
    printf "${NC}\n"
}

print_header() {
    echo ""
    echo "${BOLD}${CYAN}$1${NC}"
    echo ""
}

print_success() {
    echo "${SUCCESS}✅ $1${NC}"
}

print_error() {
    echo "${ERROR}❌ $1${NC}"
}

print_warning() {
    echo "${WARNING}⚠️  $1${NC}"
}

print_info() {
    echo "${INFO}ℹ️  $1${NC}"
}

print_highlight() {
    echo "${HIGHLIGHT}▶ $1${NC}"
}

print_dim() {
    echo "${DIM}${GRAY}$1${NC}"
}

print_bold() {
    echo "${BOLD}${WHITE}$1${NC}"
}

print_underline() {
    echo "${UNDERLINE}$1${NC}"
}

print_batch_progress() {
    local current=$1
    local total=$2
    local app_name=$3
    
    echo ""
    echo "${VIOLET}▶ 処理中: ${current}/${total} - ${app_name}${NC}"
    print_separator "$SEPARATOR_CHAR" "$VIOLET"
    echo ""
}

wait_for_enter() {
    local message="${1:-Enterキーで続行...}"
    echo ""
    echo -n "$message"
    read
}

#######################################################
# Basic Utility Functions
#######################################################

# Show error and return to previous menu
show_error_and_return() {
    local title="$1"
    local error_message="$2"
    local callback="${3:-}"
    
    clear
    print_header "$title"
    echo ""
    print_error "$error_message"
    echo ""
    wait_for_enter
    
    if [[ -n "$callback" ]] && type "$callback" &>/dev/null; then
        "$callback"
    fi
}

# Clean up temporary directory with error handling
cleanup_temp_dir() {
    local temp_dir="$1"
    local silent="${2:-false}"
    
    if [[ -n "$temp_dir" ]] && [[ -e "$temp_dir" ]]; then
        if /usr/bin/sudo /bin/rm -rf "$temp_dir" 2>/dev/null; then
            [[ "$silent" != "true" ]] && print_success "一時ディレクトリをクリーンアップしました"
            return 0
        else
            [[ "$silent" != "true" ]] && print_warning "一時ディレクトリの削除に失敗しました: $temp_dir"
            return 1
        fi
    fi
    return 0
}

# Quit app before volume operations
quit_app_if_running() {
    local bundle_id="$1"
    
    if [[ -z "$bundle_id" ]] || [[ "$bundle_id" == "$PLAYCOVER_BUNDLE_ID" ]]; then
        return 0
    fi
    
    /usr/bin/pkill -9 -f "$bundle_id" 2>/dev/null || true
    /bin/sleep 0.3
    return 0
}

# Prompt for confirmation with default option
prompt_confirmation() {
    local message="$1"
    local default="${2:-Y}"
    
    if [[ "$default" == "Y" ]]; then
        echo -n "${message} (Y/n): "
    else
        echo -n "${message} (y/N): "
    fi
    read response
    
    response=${response:-$default}
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# Check if PlayCover is running
is_playcover_running() {
    pgrep -x "PlayCover" >/dev/null 2>&1
}

# Check if app is running
is_app_running() {
    local bundle_id=$1
    
    if [[ -z "$bundle_id" ]]; then
        return 1
    fi
    
    /usr/bin/pgrep -f "$bundle_id" >/dev/null 2>&1
}

# Get PlayCover external path
get_playcover_external_path() {
    if [[ -d "$PLAYCOVER_CONTAINER" ]]; then
        echo "${PLAYCOVER_CONTAINER}/${PLAYCOVER_APP_NAME}"
    else
        echo ""
    fi
}

# Exit with cleanup
exit_with_cleanup() {
    local exit_code=$1
    local message=$2
    
    echo ""
    if [[ $exit_code -eq 0 ]]; then
        print_success "$message"
        echo ""
        print_info "3秒後にターミナルを自動で閉じます..."
        /bin/sleep 3
        /usr/bin/osascript -e 'tell application "Terminal" to close (every window whose name contains "playcover")' & exit 0
    else
        print_error "$message"
        echo ""
        print_warning "エラーが発生しました。ログを確認してください。"
        echo ""
        echo -n "Enterキーを押すとターミナルを閉じます..."
        read
        /usr/bin/osascript -e 'tell application "Terminal" to close (every window whose name contains "playcover")' & exit "$exit_code"
    fi
}

# Authenticate sudo
authenticate_sudo() {
    if [[ "$SUDO_AUTHENTICATED" == "true" ]]; then
        return 0
    fi
    
    print_info "管理者権限が必要です"
    
    if /usr/bin/sudo -v; then
        SUDO_AUTHENTICATED=true
        print_success "認証成功"
        
        # Keep sudo alive in background
        while true; do
            /usr/bin/sudo -n true
            /bin/sleep 50
            /bin/kill -0 "$$" 2>/dev/null || exit
        done 2>/dev/null &
        
        echo ""
        return 0
    else
        print_error "認証失敗"
        exit_with_cleanup 1 "管理者権限の取得に失敗しました"
    fi
}

# Check PlayCover app
check_playcover_app() {
    if [[ ! -d "/Applications/PlayCover.app" ]]; then
        print_error "PlayCover が見つかりません"
        print_warning "PlayCover を /Applications にインストールしてください"
        exit_with_cleanup 1 "PlayCover が見つかりません"
    fi
}

# Check full disk access
check_full_disk_access() {
    local test_path="${HOME}/Library/Safari"
    
    if [[ ! -d "$test_path" ]]; then
        test_path="${HOME}/Library/Mail"
    fi
    
    if /bin/ls "$test_path" >/dev/null 2>&1; then
        return 0
    else
        print_warning "Terminal にフルディスクアクセス権限がありません"
        print_info "システム設定 > プライバシーとセキュリティ > フルディスクアクセス から有効にしてください"
        echo ""
        echo -n "設定完了後、Enterキーを押してください..."
        read
        
        if /bin/ls "$test_path" >/dev/null 2>&1; then
            return 0
        else
            print_error "権限が確認できませんでした"
            echo ""
            echo -n "それでも続行しますか？ (y/N): "
            read continue_choice
            
            if [[ ! "$continue_choice" =~ ^[Yy]$ ]]; then
                exit_with_cleanup 1 "フルディスクアクセス権限が必要です"
            fi
            echo ""
        fi
    fi
}
