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
readonly PLAYCOVER_BASE="${HOME}/Library/Containers"
readonly PLAYCOVER_CONTAINER="${PLAYCOVER_BASE}/${PLAYCOVER_BUNDLE_ID}"
readonly PLAYCOVER_VOLUME_NAME="PlayCover"
readonly PLAYCOVER_APP_NAME="PlayCover.app"
readonly PLAYCOVER_APP_PATH="/Applications/${PLAYCOVER_APP_NAME}"
readonly PLAYCOVER_APPS_DIR="${PLAYCOVER_CONTAINER}/Applications"

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

# Data directory for PlayCover Manager (centralized storage)
readonly DATA_DIR="${HOME}/.playcover_manager"

# Mapping file stored in data directory
# Format: volume_name<TAB>bundle_id<TAB>display_name<TAB>last_launched
readonly MAPPING_FILE="${DATA_DIR}/volume_mapping.tsv"
readonly MAPPING_LOCK_FILE="${MAPPING_FILE}.lock"

# Internal storage flag (placed in container directories)
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
SELECTED_EXTERNAL_DISK=""
SELECTED_CONTAINER=""

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

# Print functions with newline (ln versions)
print_success_ln() {
    echo "${SUCCESS}✅ $1${NC}"
    echo ""
}

print_error_ln() {
    echo "${ERROR}❌ $1${NC}"
    echo ""
}

print_warning_ln() {
    echo "${WARNING}⚠️  $1${NC}"
    echo ""
}

print_info_ln() {
    echo "${INFO}ℹ️  $1${NC}"
    echo ""
}

print_highlight_ln() {
    echo "${HIGHLIGHT}▶ $1${NC}"
    echo ""
}

# Debug and verbose output functions (controlled by environment variables)


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

# Handle error and return (combines print_error + wait_for_enter + return)
# Args:
#   $1: error_message (required)
#   $2: exit_code (optional, default: 1)
# Usage: handle_error_and_return "エラーメッセージ" [exit_code]
handle_error_and_return() {
    local error_message="$1"
    local exit_code="${2:-1}"
    print_error "$error_message"
    wait_for_enter
    return "$exit_code"
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

# Get available disk space in kilobytes
# Args: path (mount point or directory path)
# Returns: Available space in KB, or empty string on error
# Usage: local available_kb=$(get_available_space "/Volumes/MyDisk")
get_available_space() {
    local path="$1"
    
    if [[ -z "$path" ]] || [[ ! -e "$path" ]]; then
        return 1
    fi
    
    local available_kb=$(/bin/df -k "$path" 2>/dev/null | /usr/bin/tail -1 | /usr/bin/awk '{print $4}')
    
    if [[ -n "$available_kb" ]] && [[ "$available_kb" =~ ^[0-9]+$ ]]; then
        echo "$available_kb"
        return 0
    else
        return 1
    fi
}

# Get directory size in kilobytes
# Args: directory_path
# Returns: Size in KB, or empty string on error
# Usage: local size_kb=$(get_directory_size "/path/to/dir")
get_directory_size() {
    local dir_path="$1"
    
    if [[ -z "$dir_path" ]] || [[ ! -d "$dir_path" ]]; then
        return 1
    fi
    
    local size_kb=$(/usr/bin/du -sk "$dir_path" 2>/dev/null | /usr/bin/awk '{print $1}')
    
    if [[ -n "$size_kb" ]] && [[ "$size_kb" =~ ^[0-9]+$ ]]; then
        echo "$size_kb"
        return 0
    else
        return 1
    fi
}

# Convert bytes to human-readable format (decimal units: 1000-based like macOS Finder)
# Args: bytes
# Returns: Human-readable string (e.g., "1.5GB", "250MB", "5.2KB")
# Usage: local size=$(bytes_to_human 1500000000)  # Returns "1.5GB"
bytes_to_human() {
    local bytes=$1
    
    if [[ -z "$bytes" ]] || [[ ! "$bytes" =~ ^[0-9]+$ ]]; then
        echo "0B"
        return 1
    fi
    
    # Use decimal (1000-based) units like macOS Finder
    # This is a statement against Windows using binary units (1024) but calling them GB!
    if [[ $bytes -ge 1000000000000 ]]; then
        # TB - Show one decimal place (e.g., 3.6TB)
        local tb=$((bytes / 1000000000000))
        local remainder=$((bytes % 1000000000000))
        local decimal=$((remainder / 100000000000))  # First digit after decimal point
        echo "${tb}.${decimal}TB"
    elif [[ $bytes -ge 1000000000 ]]; then
        # GB - Show one decimal place (e.g., 34.1GB)
        local gb=$((bytes / 1000000000))
        local remainder=$((bytes % 1000000000))
        local decimal=$((remainder / 100000000))  # First digit after decimal point
        echo "${gb}.${decimal}GB"
    elif [[ $bytes -ge 1000000 ]]; then
        # MB - No decimal places needed (e.g., 250MB)
        local mb=$((bytes / 1000000))
        echo "${mb}MB"
    elif [[ $bytes -ge 1000 ]]; then
        # KB - No decimal places needed (e.g., 512KB)
        local kb=$((bytes / 1000))
        echo "${kb}KB"
    else
        # Bytes
        echo "${bytes}B"
    fi
}

# Create temporary directory with automatic cleanup on error
# Returns: temp directory path
# Usage: local temp_dir=$(create_temp_dir) || return 1
create_temp_dir() {
    local temp_dir=$(mktemp -d 2>/dev/null)
    
    if [[ -z "$temp_dir" ]] || [[ ! -d "$temp_dir" ]]; then
        print_error "一時ディレクトリの作成に失敗しました"
        return 1
    fi
    
    echo "$temp_dir"
    return 0
}

# Get volume mount point from diskutil
# Args: device_or_volume (device path or volume name)
# Returns: Mount point path, or empty string if not mounted
# Usage: local mount_point=$(get_volume_mount_point "/dev/disk3s2")
get_volume_mount_point() {
    local target="$1"
    
    if [[ -z "$target" ]]; then
        return 1
    fi
    
    local mount_point=$(/usr/sbin/diskutil info "$target" 2>/dev/null | \
        /usr/bin/grep "Mount Point:" | \
        /usr/bin/sed 's/.*Mount Point: *//;s/ *$//')
    
    # Filter out "Not applicable" responses
    if [[ "$mount_point" == "Not applicable"* ]]; then
        return 1
    fi
    
    if [[ -n "$mount_point" ]]; then
        echo "$mount_point"
        return 0
    else
        return 1
    fi
}

# Get device node from diskutil
# Args: device_or_volume (device path or volume name)
# Returns: Device node (without /dev/), or empty string on error
# Usage: local device=$(get_volume_device_node "PlayCover")
get_volume_device_node() {
    local target="$1"
    
    if [[ -z "$target" ]]; then
        return 1
    fi
    
    local device_node=$(/usr/sbin/diskutil info "$target" 2>/dev/null | \
        /usr/bin/awk '/Device Node:/ {gsub(/\/dev\//, "", $NF); print $NF}')
    
    if [[ -n "$device_node" ]]; then
        echo "$device_node"
        return 0
    else
        return 1
    fi
}

# Get disk name from diskutil
# Args: device_or_disk (device path or disk identifier)
# Returns: Disk name (e.g., "External SSD"), or empty string on error
# Usage: local name=$(get_disk_name "/dev/disk3")
get_disk_name() {
    local target="$1"
    
    if [[ -z "$target" ]]; then
        return 1
    fi
    
    local disk_name=$(/usr/sbin/diskutil info "$target" 2>/dev/null | \
        /usr/bin/grep "Device / Media Name:" | \
        /usr/bin/sed 's/.*Device \/ Media Name: *//;s/ *$//')
    
    if [[ -n "$disk_name" ]]; then
        echo "$disk_name"
        return 0
    else
        return 1
    fi
}

# Get disk location (Internal/External)
# Args: device_or_disk (device path or disk identifier)
# Returns: "Internal" or "External", or empty string on error
# Usage: local location=$(get_disk_location "/dev/disk3")
get_disk_location() {
    local target="$1"
    
    if [[ -z "$target" ]]; then
        return 1
    fi
    
    local location=$(/usr/sbin/diskutil info "$target" 2>/dev/null | \
        /usr/bin/awk -F: '/Device Location:/ {gsub(/^ */, "", $2); print $2}')
    
    if [[ -n "$location" ]]; then
        echo "$location"
        return 0
    else
        return 1
    fi
}

# Get volume device with existence check (high-level wrapper)
# Args: volume_name
# Returns: Device identifier (e.g., disk3s2) or exits with error
# Usage: local device=$(get_volume_device_or_fail "PlayCover") || return 1
get_volume_device_or_fail() {
    local volume_name="$1"
    
    if [[ -z "$volume_name" ]]; then
        print_error "ボリューム名が指定されていません"
        return 1
    fi
    
    # Check if volume exists using existing volume_exists function
    if ! volume_exists "$volume_name"; then
        print_error "ボリューム '${volume_name}' が見つかりません"
        return 1
    fi
    
    # Get device using existing get_volume_device function
    local device=$(get_volume_device "$volume_name")
    
    if [[ -z "$device" ]]; then
        print_error "ボリューム '${volume_name}' のデバイス情報を取得できません"
        return 1
    fi
    
    echo "$device"
    return 0
}

# Ensure volume is mounted (mount if not mounted, get mount point)
# Args: volume_name, [mount_point], [nobrowse]
# Returns: Mount point path
# Usage: local mount=$(ensure_volume_mounted "PlayCover" "/tmp/mnt" "nobrowse") || return 1
ensure_volume_mounted() {
    local volume_name="$1"
    local desired_mount="$2"
    local nobrowse="${3:-}"
    
    if [[ -z "$volume_name" ]]; then
        return 1
    fi
    
    # Check if volume exists
    local device=$(get_volume_device_or_fail "$volume_name") || return 1
    
    # Check current mount point
    local current_mount=$(get_volume_mount_point "$device")
    
    # If already mounted at desired location, return it
    if [[ -n "$current_mount" ]] && [[ -n "$desired_mount" ]] && [[ "$current_mount" == "$desired_mount" ]]; then
        echo "$current_mount"
        return 0
    fi
    
    # If mounted elsewhere but no desired mount specified, return current
    if [[ -n "$current_mount" ]] && [[ -z "$desired_mount" ]]; then
        echo "$current_mount"
        return 0
    fi
    
    # If not mounted, or mounted at wrong location, need to mount
    if [[ -n "$desired_mount" ]]; then
        # Unmount if mounted elsewhere
        if [[ -n "$current_mount" ]]; then
            unmount_volume "$device" "silent" || unmount_volume "$device" "silent" "force" || return 1
        fi
        
        # Mount to desired location
        if mount_volume "$device" "$desired_mount" "$nobrowse" "silent"; then
            echo "$desired_mount"
            return 0
        else
            return 1
        fi
    fi
    
    return 1
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

# Prompt for confirmation with various prompt types
# Args:
#   $1: message (required)
#   $2: prompt_type (optional, default: "Y/n")
#       - "Y/n"    : Yes is default (press Enter → Yes)
#       - "y/N"    : No is default (press Enter → No)
#       - "yes/NO" : Dangerous operation (must type "yes" explicitly, default: No)
#       - "yes/no" : Nuclear operation (must type "yes" explicitly, no default)
# Returns: 0 if confirmed, 1 if canceled
# Usage: 
#   prompt_confirmation "続行しますか？"              # Default: Y/n
#   prompt_confirmation "削除しますか？" "y/N"       # Default: No
#   prompt_confirmation "本当に削除？" "yes/NO"      # Must type "yes", default No
#   prompt_confirmation "全削除？" "yes/no"          # Must type "yes", no default
prompt_confirmation() {
    local message="$1"
    local prompt_type="${2:-Y/n}"
    local response
    
    case "$prompt_type" in
        "Y/n")
            echo -n "${message} (Y/n): "
            read response
            response=${response:-Y}
            [[ "$response" =~ ^[Yy]$ ]]
            ;;
        "y/N")
            echo -n "${message} (y/N): "
            read response
            response=${response:-N}
            [[ "$response" =~ ^[Yy]$ ]]
            ;;
        "yes/NO")
            echo -n "${message} (yes/NO): "
            read response
            response=${response:-NO}
            [[ "$response" == "yes" ]]
            ;;
        "yes/no")
            echo -n "${message} (yes/no): "
            read response
            [[ "$response" == "yes" ]]
            ;;
        *)
            # Fallback to Y/n
            echo -n "${message} (Y/n): "
            read response
            response=${response:-Y}
            [[ "$response" =~ ^[Yy]$ ]]
            ;;
    esac
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
            if ! prompt_confirmation "それでも続行しますか？" "y/N"; then
                exit_with_cleanup 1 "フルディスクアクセス権限が必要です"
            fi
            echo ""
        fi
    fi
}

#######################################################
# Environment Readiness Check
#######################################################

# Check if PlayCover environment is ready (volume, mapping file, app)
# Returns: 0 if ready, 1 if not ready
is_playcover_environment_ready() {
    # Check if PlayCover is installed
    if [[ ! -d "/Applications/PlayCover.app" ]]; then
        return 1
    fi
    
    # Check if PlayCover volume exists (use volume_exists function)
    if ! volume_exists "${PLAYCOVER_VOLUME_NAME}"; then
        return 1
    fi
    
    # Check if mapping file exists and has content
    if [[ ! -f "$MAPPING_FILE" ]]; then
        return 1
    fi
    
    # Check if mapping file has at least one valid entry (not just empty/whitespace)
    if [[ ! -s "$MAPPING_FILE" ]] || ! /usr/bin/grep -q $'\t' "$MAPPING_FILE" 2>/dev/null; then
        return 1
    fi
    
    return 0
}
p -i playcover >&2
        return 1
    fi
    
    # Check if mapping file exists
    if [[ ! -f "$MAPPING_FILE" ]]; then
        return 1
    fi
    
    return 0
}
