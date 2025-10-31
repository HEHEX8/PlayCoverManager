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
# 色とスタイル定義
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

# Get script directory (zsh only)
readonly SCRIPT_DIR="$(cd "$(dirname "${(%):-%x}")/.." && pwd)"

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

# Volume state cache for performance optimization
# Format: VOLUME_STATE_CACHE[volume_name]="exists|device|mount_point|timestamp"
declare -A VOLUME_STATE_CACHE
CACHE_ENABLED=true  # Global cache enable/disable flag
CACHE_PRELOADED=false  # Track if cache has been preloaded at least once

# External drive name cache (set once at startup, never changes)
EXTERNAL_DRIVE_NAME=""

# Cache update flag for lazy loading (only update when entering main menu)
DRIVE_NAME_CACHE_UPDATED=false

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

# Show error with optional info message and return to menu
# More flexible version with info message support
show_error_info_and_return() {
    local title="$1"
    local error_message="$2"
    local info_message="${3:-}"
    local callback="${4:-}"
    
    clear
    print_header "$title"
    echo ""
    print_error "$error_message"
    
    if [[ -n "$info_message" ]]; then
        echo ""
        print_info "$info_message"
    fi
    
    wait_for_enter
    
    if [[ -n "$callback" ]] && type "$callback" &>/dev/null; then
        "$callback"
    fi
}

# Silent return to menu (for successful operations)
# Args: callback function name
silent_return_to_menu() {
    local callback="${1:-}"
    
    if [[ -n "$callback" ]] && type "$callback" &>/dev/null; then
        "$callback"
    fi
    return 0
}

# Check if app is running and show error if true
# Returns: 0 if app is NOT running, 1 if running (and shows error)
check_app_running_with_error() {
    local bundle_id="$1"
    local display_name="$2"
    local operation_name="${3:-操作}"  # e.g., "アンマウント", "再マウント"
    local callback="${4:-}"
    
    local app_is_running=false
    
    if [[ "$bundle_id" == "$PLAYCOVER_BUNDLE_ID" ]]; then
        is_playcover_running && app_is_running=true
    else
        is_app_running "$bundle_id" && app_is_running=true
    fi
    
    if [[ "$app_is_running" == true ]]; then
        show_error_info_and_return \
            "${display_name} の操作" \
            "${operation_name}失敗: アプリが実行中です" \
            "アプリを終了してから再度お試しください" \
            "$callback"
        return 1
    fi
    
    return 0
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

# Cache external drive name at startup
# Called once during initialization, result stored in EXTERNAL_DRIVE_NAME
cache_external_drive_name() {
    if volume_exists_cached "$PLAYCOVER_VOLUME_NAME"; then
        local volume_device=$(validate_and_get_device_cached "$PLAYCOVER_VOLUME_NAME")
        if [[ -n "$volume_device" ]]; then
            local playcover_device="/dev/${volume_device}"
            # Extract disk identifier (e.g., disk3 from disk3s1)
            local disk_id=$(echo "$playcover_device" | /usr/bin/sed 's|/dev/||;s|s[0-9]*$||')
            # Get and cache the drive name
            EXTERNAL_DRIVE_NAME=$(get_disk_name "$disk_id")
        fi
    fi
    
    # Set default if not found
    if [[ -z "$EXTERNAL_DRIVE_NAME" ]]; then
        EXTERNAL_DRIVE_NAME="外部ディスク"
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
            unmount_with_fallback "$device" "silent" || return 1
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

#######################################################
# Cross-Module Common Operations
# ファイル間共通操作（複数モジュールで使用される高レベル関数）
#######################################################

# Unmount with automatic force fallback (try normal, then force if failed)
# Args: target (device or mount point), mode (silent|verbose)
# Returns: 0 on success, 1 on failure
unmount_with_fallback() {
    local target="$1"
    local mode="${2:-silent}"
    local volume_name_hint="${3:-}"  # Optional: volume name for cache invalidation
    
    local unmount_success=false
    
    # Try normal unmount first
    if unmount_volume "$target" "$mode"; then
        unmount_success=true
    else
        # If normal unmount failed, try force unmount
        if [[ "$mode" == "verbose" ]]; then
            print_warning "通常のアンマウントに失敗、強制アンマウントを試みます..."
        fi
        
        if unmount_volume "$target" "$mode" "force"; then
            unmount_success=true
        fi
    fi
    
    # Invalidate cache if unmount succeeded
    if [[ "$unmount_success" == true ]]; then
        # If volume name hint provided, use it
        if [[ -n "$volume_name_hint" ]]; then
            invalidate_volume_cache "$volume_name_hint"
        # If target looks like a volume name (not a device path), invalidate it
        elif [[ "$target" != /dev/* ]] && [[ "$target" != /* ]]; then
            invalidate_volume_cache "$target"
        fi
        return 0
    else
        return 1
    fi
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

# Exit with cleanup
exit_with_cleanup() {
    local exit_code=$1
    local message=$2
    
    echo ""
    if [[ $exit_code -eq 0 ]]; then
        print_success "$message"
        echo ""
        print_info "3秒後に終了します..."
        /bin/sleep 3
        echo ""
        echo "${DIM_GRAY}このウィンドウを閉じるには: ${CYAN}⌘ + W${NC}"
        exit 0
    else
        print_error "$message"
        echo ""
        print_warning "エラーが発生しました。ログを確認してください。"
        echo ""
        echo -n "Enterキーを押すと終了します..."
        read
        echo ""
        echo "${DIM_GRAY}このウィンドウを閉じるには: ${CYAN}⌘ + W${NC}"
        exit "$exit_code"
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

# ================================================================
# Redundancy Reduction Helpers
# ================================================================

# Get comprehensive volume information in one call
# This reduces redundant diskutil calls by retrieving all needed info at once
# Args: $1 = volume_name
# Returns: 0 if volume exists and mounted, 1 if not exists, 2 if exists but not mounted
# Output format: "device|mount_point" (both will be empty if volume doesn't exist)
# Usage: 
#   local info=$(get_volume_info "$volume_name")
#   local status=$?
#   if [[ $status -eq 0 ]]; then
#       local device="${info%%|*}"
#       local mount_point="${info#*|}"
#   fi
get_volume_info() {
    local volume_name="$1"
    
    # Single diskutil call to get all info
    local diskutil_output=$(/usr/sbin/diskutil info "$volume_name" 2>/dev/null)
    
    if [[ $? -ne 0 ]] || [[ -z "$diskutil_output" ]]; then
        echo "|"  # Empty device and mount point
        return 1  # Volume doesn't exist
    fi
    
    # Extract device identifier
    local device=$(/usr/bin/grep -E "Device Node:" <<< "$diskutil_output" | /usr/bin/awk '{print $3}')
    
    # Extract mount point
    local mount_point=$(/usr/bin/grep -E "Mount Point:" <<< "$diskutil_output" | /usr/bin/sed 's/^[[:space:]]*Mount Point:[[:space:]]*//')
    
    # Output in format: device|mount_point
    echo "${device}|${mount_point}"
    
    # Return status based on mount state
    if [[ -n "$mount_point" ]]; then
        return 0  # Exists and mounted
    else
        return 2  # Exists but not mounted
    fi
}

# Validate volume and get device in one call
# More efficient than separate volume_exists + get_volume_device calls
# Args: $1 = volume_name
# Returns: 0 if exists, 1 if not
# Output: device node (e.g., /dev/disk3s1) or empty string
# Usage:
#   local device=$(validate_and_get_device "$volume_name")
#   if [[ $? -eq 0 ]] && [[ -n "$device" ]]; then
#       # Use device...
#   fi
validate_and_get_device() {
    local volume_name="$1"
    
    local device=$(/usr/sbin/diskutil info "$volume_name" 2>/dev/null | /usr/bin/grep "Device Node:" | /usr/bin/awk '{print $3}')
    
    if [[ -z "$device" ]]; then
        return 1
    fi
    
    echo "$device"
    return 0
}

# Validate volume existence and get mount point in one call
# More efficient than separate volume_exists + get_mount_point calls
# Args: $1 = volume_name
# Returns: 0 if exists and mounted, 1 if not exists, 2 if exists but not mounted
# Output: mount point path or empty string
# Usage:
#   local mount_point=$(validate_and_get_mount_point "$volume_name")
#   local status=$?
#   if [[ $status -eq 0 ]]; then
#       # Volume is mounted at $mount_point
#   elif [[ $status -eq 2 ]]; then
#       # Volume exists but not mounted
#   fi
validate_and_get_mount_point() {
    local volume_name="$1"
    
    local diskutil_output=$(/usr/sbin/diskutil info "$volume_name" 2>/dev/null)
    
    if [[ $? -ne 0 ]] || [[ -z "$diskutil_output" ]]; then
        return 1  # Volume doesn't exist
    fi
    
    local mount_point=$(/usr/bin/grep -E "Mount Point:" <<< "$diskutil_output" | /usr/bin/sed 's/^[[:space:]]*Mount Point:[[:space:]]*//')
    
    if [[ -n "$mount_point" ]]; then
        echo "$mount_point"
        return 0  # Mounted
    else
        return 2  # Exists but not mounted
    fi
}

# ================================================================
# Volume State Cache Management
# ================================================================
# Performance optimization: Cache volume state to reduce redundant diskutil calls
# Only invalidate cache for volumes that are actually modified

# Get cached volume info or fetch and cache if not present
# Args: $1 = volume_name
# Returns: Same as get_volume_info() - 0 if mounted, 1 if not exists, 2 if exists but not mounted
# Output: "device|mount_point"
# Usage:
#   local info=$(get_volume_info_cached "$volume_name")
#   local status=$?
get_volume_info_cached() {
    local volume_name="$1"
    
    # If cache is disabled, always fetch fresh data
    if [[ "$CACHE_ENABLED" != true ]]; then
        get_volume_info "$volume_name"
        return $?
    fi
    
    # Check if cache exists for this volume
    if [[ -n "${VOLUME_STATE_CACHE[$volume_name]}" ]]; then
        local cached="${VOLUME_STATE_CACHE[$volume_name]}"
        local exists="${cached%%|*}"
        local rest="${cached#*|}"
        local device="${rest%%|*}"
        local rest2="${rest#*|}"
        local mount_point="${rest2%%|*}"
        
        # Output cached data
        echo "${device}|${mount_point}"
        
        # Return status based on cached data
        # IMPORTANT: Double-check mount_point to ensure cache accuracy
        if [[ "$exists" == "0" ]]; then
            # Status says mounted, but verify mount_point is not empty
            if [[ -n "$mount_point" ]]; then
                return 0  # Mounted (verified)
            else
                return 2  # Cache inconsistency: status=0 but no mount point
            fi
        elif [[ "$exists" == "1" ]]; then
            return 1  # Not exists
        else
            return 2  # Exists but not mounted
        fi
    fi
    
    # Cache miss - fetch fresh data
    local vol_info=$(get_volume_info "$volume_name")
    local vol_status=$?
    
    local device="${vol_info%%|*}"
    local mount_point="${vol_info#*|}"
    local timestamp=$(date +%s)
    
    # Store in cache: "status|device|mount_point|timestamp"
    VOLUME_STATE_CACHE[$volume_name]="${vol_status}|${device}|${mount_point}|${timestamp}"
    
    # Output data
    echo "${device}|${mount_point}"
    return $vol_status
}

# Invalidate cache for specific volume(s)
# Args: $@ = volume_name(s) to invalidate (can be multiple)
# Usage:
#   invalidate_volume_cache "$volume_name"
#   invalidate_volume_cache "$vol1" "$vol2" "$vol3"
invalidate_volume_cache() {
    if [[ "$CACHE_ENABLED" != true ]]; then
        return 0
    fi
    
    for volume_name in "$@"; do
        unset "VOLUME_STATE_CACHE[$volume_name]"
    done
}

# Invalidate all volume caches
# This also resets the preload flag, allowing next preload call to execute
# Usage: invalidate_all_volume_caches
invalidate_all_volume_caches() {
    VOLUME_STATE_CACHE=()
    CACHE_PRELOADED=false  # Reset preload flag to allow next preload
}

# Refresh cache by invalidating and immediately reloading
# This is the recommended function to call when user requests cache refresh (empty Enter)
# It ensures cache is immediately updated, avoiding re-preload when returning to menu
# Usage: refresh_all_volume_caches
refresh_all_volume_caches() {
    invalidate_all_volume_caches
    preload_all_volume_cache
}

# Preload all volume information into cache
# Call this before displaying main menu to populate cache with all volumes
# Only preloads on first call - subsequent calls are skipped for performance
# Usage: preload_all_volume_cache
preload_all_volume_cache() {
    if [[ "$CACHE_ENABLED" != true ]]; then
        return 0
    fi
    
    # Skip if already preloaded (only preload once per session)
    if [[ "$CACHE_PRELOADED" == true ]]; then
        return 0
    fi
    
    # Read all volume names from mapping file
    if [[ ! -f "$MAPPING_FILE" ]]; then
        return 0
    fi
    
    # Count total volumes
    local total_volumes=0
    while IFS=$'\t' read -r volume_name bundle_id display_name recent_flag; do
        [[ -z "$volume_name" || -z "$bundle_id" ]] && continue
        ((total_volumes++))
    done < "$MAPPING_FILE"
    
    # Add PlayCover volume to count
    if [[ -n "$PLAYCOVER_VOLUME_NAME" ]]; then
        ((total_volumes++))
    fi
    
    # Only show progress if there are volumes to load
    if (( total_volumes == 0 )); then
        CACHE_PRELOADED=true
        return 0
    fi
    
    local start_time=$(date +%s)
    local loaded=0
    
    # Preload volumes (silent mode, no progress display when called from startup)
    while IFS=$'\t' read -r volume_name bundle_id display_name recent_flag; do
        [[ -z "$volume_name" || -z "$bundle_id" ]] && continue
        get_volume_info_cached "$volume_name" >/dev/null
    done < "$MAPPING_FILE"
    
    # Also preload PlayCover main volume
    if [[ -n "$PLAYCOVER_VOLUME_NAME" ]]; then
        get_volume_info_cached "$PLAYCOVER_VOLUME_NAME" >/dev/null
    fi
    
    # Mark as preloaded
    CACHE_PRELOADED=true
}

# Temporarily disable cache for a code block
# Usage:
#   with_cache_disabled() {
#       # Your code here will not use cache
#   }
with_cache_disabled() {
    local original_state="$CACHE_ENABLED"
    CACHE_ENABLED=false
    "$@"
    local result=$?
    CACHE_ENABLED="$original_state"
    return $result
}

# Wrapper functions for backward compatibility with caching support
# These can be used as drop-in replacements for the original functions

# Cached version of validate_and_get_device
validate_and_get_device_cached() {
    local volume_name="$1"
    
    local vol_info=$(get_volume_info_cached "$volume_name")
    local vol_status=$?
    
    if [[ $vol_status -eq 1 ]]; then
        return 1  # Not exists
    fi
    
    local device="${vol_info%%|*}"
    echo "$device"
    return 0
}

# Cached version of validate_and_get_mount_point
validate_and_get_mount_point_cached() {
    local volume_name="$1"
    
    local vol_info=$(get_volume_info_cached "$volume_name")
    local vol_status=$?
    
    if [[ $vol_status -eq 1 ]]; then
        return 1  # Not exists
    fi
    
    local mount_point="${vol_info#*|}"
    
    if [[ -n "$mount_point" ]]; then
        echo "$mount_point"
        return 0  # Mounted
    else
        return 2  # Exists but not mounted
    fi
}

# Cached version of volume_exists (for backward compatibility)
# Returns: 0 if exists, 1 if not exists
volume_exists_cached() {
    local volume_name="$1"
    
    local vol_info=$(get_volume_info_cached "$volume_name")
    local vol_status=$?
    
    if [[ $vol_status -eq 1 ]]; then
        return 1  # Not exists
    else
        return 0  # Exists (either mounted or unmounted)
    fi
}

# Cached version of get_mount_point (for backward compatibility)
# Returns mount point if mounted, empty if not mounted
get_mount_point_cached() {
    local volume_name="$1"
    
    local vol_info=$(get_volume_info_cached "$volume_name")
    local vol_status=$?
    
    if [[ $vol_status -eq 1 ]]; then
        return 1  # Volume doesn't exist
    fi
    
    local mount_point="${vol_info#*|}"
    echo "$mount_point"
    
    if [[ -n "$mount_point" ]]; then
        return 0  # Mounted
    else
        return 1  # Not mounted
    fi
}

#######################################################
# Generic Progress Bar Functions
#######################################################

# Show a progress bar with percentage, counts, and speed
# Usage: show_progress_bar <current> <total> <start_time> [bar_width] [unit]
# Example: show_progress_bar 450 1000 $start_time 50 "files"
show_progress_bar() {
    local current=$1
    local total=$2
    local start_time=$3
    local bar_width=${4:-50}  # Default: 50 chars
    local unit=${5:-"items"}   # Default: "items"
    
    # Calculate percentage
    local percent=0
    if (( total > 0 )); then
        percent=$(( current * 100 / total ))
    fi
    
    # Ensure percentage doesn't exceed 100%
    if (( percent > 100 )); then
        percent=100
    fi
    
    # Calculate speed
    local elapsed=$(($(date +%s) - start_time))
    local speed=0
    if (( elapsed > 0 )); then
        speed=$(( current / elapsed ))
    fi
    
    # Build progress bar
    local filled=$(( percent * bar_width / 100 ))
    local bar=""
    for ((i=0; i<bar_width; i++)); do
        if (( i < filled )); then
            bar="${bar}█"
        else
            bar="${bar}░"
        fi
    done
    
    # Display with fixed width formatting
    printf "\r[%s] %3d%% | %${#total}d/%d %s | %4d %s/s  " \
        "$bar" "$percent" "$current" "$total" "$unit" "$speed" "$unit"
}

# Clear progress bar line
clear_progress_bar() {
    printf "\r%*s\r" 100 ""
}

# Monitor file count progress in a directory
# Usage: monitor_file_progress <dest_dir> <total_files> <initial_count> <start_time> <pid_to_monitor> [interval]
# Returns: Final file count (via stdout redirection to /dev/fd/3)
monitor_file_progress() {
    local dest_dir=$1
    local total_files=$2
    local initial_count=$3
    local start_time=$4
    local monitor_pid=$5
    local interval=${6:-0.2}  # Default: 0.2 seconds
    
    local copied=0
    
    # Monitor while process is running
    while kill -0 $monitor_pid 2>/dev/null; do
        # Count files copied so far
        local current_count=$(/usr/bin/find "$dest_dir" -type f 2>/dev/null | wc -l | /usr/bin/xargs)
        copied=$((current_count - initial_count))
        
        # Ensure copied doesn't exceed total
        if (( copied > total_files )); then
            copied=$total_files
        fi
        
        # Show progress bar on stderr to avoid interfering with stdout
        show_progress_bar "$copied" "$total_files" "$start_time" 50 "files" >&2
        
        sleep $interval
    done
    
    # Show final progress bar
    local final_count=$(/usr/bin/find "$dest_dir" -type f 2>/dev/null | wc -l | /usr/bin/xargs)
    copied=$((final_count - initial_count))
    
    if (( copied > total_files )); then
        copied=$total_files
    fi
    
    show_progress_bar "$copied" "$total_files" "$start_time" 50 "files" >&2
    
    # Return final count via stdout (without interfering with progress bar)
    echo "$copied"
}

# Show indeterminate spinner for unknown duration tasks
# Usage: show_spinner <message> <pid_to_monitor>
# Example: some_command & show_spinner "処理中" $!
show_spinner() {
    local message=$1
    local monitor_pid=$2
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    
    while kill -0 $monitor_pid 2>/dev/null; do
        i=$(( (i+1) % 10 ))
        printf "\r${message}... ${spin:$i:1} "
        sleep 0.1
    done
    
    # Clear the entire spinner line with extra spaces
    printf "\r%*s\r" 100 ""
}

#######################################################
# Volume Operations Common Functions
#######################################################

# Load all mappings from MAPPING_FILE into an array
# Returns: Array via stdout in format "volume_name|bundle_id|display_name"
# Return code: 0 if loaded, 1 if file not found or empty
load_mappings_array() {
    if [[ ! -f "$MAPPING_FILE" ]]; then
        return 1
    fi
    
    local -a mappings_array=()
    while IFS=$'\t' read -r volume_name bundle_id display_name recent_flag; do
        # Skip empty lines
        [[ -z "$volume_name" || -z "$bundle_id" ]] && continue
        
        # Add to array (only first 3 columns)
        mappings_array+=("${volume_name}|${bundle_id}|${display_name}")
    done < "$MAPPING_FILE"
    
    # Check if we have any mappings
    if [[ ${#mappings_array} -eq 0 ]]; then
        return 1
    fi
    
    # Output array elements
    printf '%s\n' "${mappings_array[@]}"
    return 0
}

# Check if any app (excluding PlayCover) is running
# Returns: 0 if any app is running, 1 if none
check_any_app_running() {
    local -a mappings_list=()
    while IFS= read -r line; do
        mappings_list+=("$line")
    done
    
    for mapping in "${mappings_list[@]}"; do
        IFS='|' read -r _ bundle_id _ <<< "$mapping"
        if [[ "$bundle_id" != "$PLAYCOVER_BUNDLE_ID" ]]; then
            if is_app_running "$bundle_id"; then
                return 0  # Found running app
            fi
        fi
    done
    
    return 1  # No app running
}

# Get volume lock status
# Args: bundle_id, any_app_running_flag (true/false)
# Returns: Status via stdout - "locked:reason" or "unlocked"
get_volume_lock_status() {
    local bundle_id="$1"
    local any_app_running="${2:-false}"
    
    if [[ "$bundle_id" == "$PLAYCOVER_BUNDLE_ID" ]]; then
        # PlayCover volume is locked if PlayCover is running OR any app is running
        if is_playcover_running; then
            echo "locked:app_running"
            return 0
        elif [[ "$any_app_running" == "true" ]]; then
            echo "locked:app_storage"
            return 0
        fi
    else
        if is_app_running "$bundle_id"; then
            echo "locked:app_running"
            return 0
        fi
    fi
    
    echo "unlocked"
    return 0
}

# Get detailed volume status with storage mode
# Args: volume_name, target_path
# Returns: Status info via stdout in format "status_type|status_message|extra_info"
# status_type: not_found, mounted, mounted_wrong, unmounted
get_volume_detailed_status() {
    local volume_name="$1"
    local target_path="$2"
    
    local actual_mount=$(validate_and_get_mount_point_cached "$volume_name")
    local vol_status=$?
    
    if [[ $vol_status -eq 1 ]]; then
        # Volume not found
        echo "not_found|❌ ボリュームが見つかりません|"
        return 0
    elif [[ $vol_status -eq 0 ]]; then
        # Volume is mounted
        if [[ -z "$actual_mount" ]]; then
            # Cache might be stale, treat as unmounted
            local storage_mode=$(get_storage_mode "$target_path" "$volume_name")
            case "$storage_mode" in
                "none")
                    echo "unmounted|⚪️ 未マウント|"
                    ;;
                "internal_intentional")
                    echo "unmounted|⚪️ 未マウント|internal_intentional"
                    ;;
                "internal_intentional_empty")
                    echo "unmounted|⚪️ 未マウント|internal_intentional_empty"
                    ;;
                "internal_contaminated")
                    echo "unmounted|⚪️ 未マウント|internal_contaminated"
                    ;;
                *)
                    echo "unmounted|⚪️ 未マウント|"
                    ;;
            esac
        elif [[ "$actual_mount" == "$target_path" ]]; then
            echo "mounted|🟢 マウント済: ${actual_mount}|"
        else
            echo "mounted_wrong|⚠️  マウント位置異常: ${actual_mount}|"
        fi
    else
        # Volume exists but not mounted (vol_status == 2)
        local storage_mode=$(get_storage_mode "$target_path" "$volume_name")
        case "$storage_mode" in
            "none")
                echo "unmounted|⚪️ 未マウント|"
                ;;
            "internal_intentional")
                echo "unmounted|⚪️ 未マウント|internal_intentional"
                ;;
            "internal_intentional_empty")
                echo "unmounted|⚪️ 未マウント|internal_intentional_empty"
                ;;
            "internal_contaminated")
                echo "unmounted|⚪️ 未マウント|internal_contaminated"
                ;;
            *)
                echo "unmounted|⚪️ 未マウント|"
                ;;
        esac
    fi
    
    return 0
}

# Format and display volume entry with lock/status indicators
# Args: display_index, display_name, lock_status, status_message, extra_info
# Returns: 0 if selectable, 1 if locked/non-selectable
format_volume_display_entry() {
    local display_index="$1"
    local display_name="$2"
    local lock_status="$3"
    local status_message="$4"
    local extra_info="$5"
    
    # Parse lock status
    local is_locked=false
    local lock_reason=""
    if [[ "$lock_status" == locked:* ]]; then
        is_locked=true
        lock_reason="${lock_status#locked:}"
    fi
    
    # Display with lock status or number
    if $is_locked; then
        # Locked: show with lock icon, no number
        if [[ "$lock_reason" == "app_running" ]]; then
            echo "  ${BOLD}🔒 ${GOLD}ロック中${NC} ${BOLD}${WHITE}${display_name}${NC} ${GRAY}| 🏃 アプリ動作中${NC}"
        elif [[ "$lock_reason" == "app_storage" ]]; then
            echo "  ${BOLD}🔒 ${GOLD}ロック中${NC} ${BOLD}${WHITE}${display_name}${NC} ${GRAY}| 🚬 下記アプリの終了待機中${NC}"
        fi
        echo "      ${GRAY}${status_message}${NC}"
        echo ""
        return 1  # Non-selectable
    elif [[ "$extra_info" == "internal_intentional" ]] || [[ "$extra_info" == "internal_intentional_empty" ]]; then
        # Intentional internal storage mode: show as locked
        echo "  ${BOLD}🔒 ${GOLD}ロック中${NC} ${BOLD}${WHITE}${display_name}${NC} ${GRAY}| 🍎 内蔵ストレージモード${NC}"
        echo "      ${GRAY}${status_message}${NC}"
        echo ""
        return 1  # Non-selectable
    elif [[ "$extra_info" == "internal_contaminated" ]]; then
        # Contaminated: show as warning (selectable)
        echo "  ${BOLD}${YELLOW}${display_index}.${NC} ${BOLD}${WHITE}${display_name}${NC} ${BOLD}${ORANGE}⚠️  内蔵データ検出${NC}"
        echo "      ${GRAY}${status_message} ${ORANGE}| マウント時に処理方法を確認します${NC}"
        echo ""
        return 0  # Selectable
    else
        # Not locked: show with number
        echo "  ${BOLD}${CYAN}${display_index}.${NC} ${BOLD}${WHITE}${display_name}${NC}"
        echo "      ${GRAY}${status_message}${NC}"
        echo ""
        return 0  # Selectable
    fi
}

# Check if volume is in contaminated state
# Args: volume_name, bundle_id
# Returns: 0 if contaminated, 1 if not contaminated
is_volume_contaminated() {
    local volume_name="$1"
    local bundle_id="$2"
    
    local target_path="${HOME}/Library/Containers/${bundle_id}"
    local storage_mode=$(get_storage_mode "$target_path" "$volume_name")
    
    if [[ "$storage_mode" == "internal_contaminated" ]]; then
        return 0  # Contaminated
    else
        return 1  # Not contaminated
    fi
}

# Auto-mount volume if contaminated (for operations that can proceed after mount)
# Args: volume_name, bundle_id, display_name, operation_name
# Returns: 0 if mounted successfully or not contaminated, 1 if failed
auto_mount_if_contaminated() {
    local volume_name="$1"
    local bundle_id="$2"
    local display_name="$3"
    local operation_name="$4"
    
    if ! is_volume_contaminated "$volume_name" "$bundle_id"; then
        return 0  # Not contaminated, proceed
    fi
    
    # Contaminated - attempt auto-mount
    echo ""
    print_warning "${display_name}: 内蔵データが検出されました"
    echo ""
    print_info "${operation_name}を実行するため、外部ボリュームを自動マウントします"
    echo ""
    
    local target_path="${HOME}/Library/Containers/${bundle_id}"
    
    # Show options
    echo "${CYAN}処理方法を選択:${NC}"
    echo "  ${LIGHT_GREEN}1.${NC} 削除して外部ボリュームをマウント"
    echo "  ${LIGHT_GREEN}2.${NC} 保持して外部ボリュームと統合"
    echo "  ${LIGHT_GREEN}3.${NC} キャンセル"
    echo ""
    echo -n "選択 (1-3): "
    read contamination_choice
    echo ""
    
    case "$contamination_choice" in
        1)
            print_info "内蔵データを削除中..."
            if /usr/bin/sudo /bin/rm -rf "$target_path" 2>/dev/null; then
                print_success "削除完了"
            else
                print_error "削除失敗"
                return 1
            fi
            ;;
        2)
            print_info "データを統合します（マウント後に外部に移動）"
            ;;
        3|*)
            print_info "キャンセルしました"
            return 1
            ;;
    esac
    
    # Mount the volume
    echo ""
    print_info "外部ボリュームをマウント中..."
    
    if mount_app_volume "$volume_name" "$target_path" "$bundle_id"; then
        print_success "マウント完了"
        return 0
    else
        print_error "マウント失敗"
        return 1
    fi
}

# Block operation if volume is contaminated
# Args: volume_name, bundle_id, display_name, operation_name
# Returns: 0 if not contaminated (can proceed), 1 if contaminated (blocked)
block_if_contaminated() {
    local volume_name="$1"
    local bundle_id="$2"
    local display_name="$3"
    local operation_name="$4"
    
    if ! is_volume_contaminated "$volume_name" "$bundle_id"; then
        return 0  # Not contaminated, can proceed
    fi
    
    # Contaminated - block operation
    echo ""
    print_error "${display_name}: 内蔵データが検出されました"
    echo ""
    print_warning "${operation_name}を実行できません"
    echo ""
    print_info "対処方法:"
    echo "  1. ボリューム操作画面で外部ボリュームをマウント"
    echo "  2. 内蔵データの処理方法を選択（削除 or 統合）"
    echo "  3. マウント完了後、再度${operation_name}を実行"
    echo ""
    wait_for_enter
    
    return 1  # Blocked
}
