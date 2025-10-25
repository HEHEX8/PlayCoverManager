#!/bin/zsh

# PlayCover Real-time Installation Monitor
# リアルタイムで全ての変化を追跡

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
readonly NC='\033[0m'

# Constants
readonly PLAYCOVER_BUNDLE_ID="io.playcover.PlayCover"
readonly PLAYCOVER_APPS="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/Applications"
readonly PLAYCOVER_SETTINGS="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/App Settings"

# Log file
readonly LOG_DIR="${HOME}/Desktop"

# Print functions
print_header() {
    echo "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "${BLUE}  $1${NC}"
    echo "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_info() {
    echo "${CYAN}[INFO]${NC} $1"
}

print_success() {
    echo "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo "${RED}[ERROR]${NC} $1"
}

log_event() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S.%3N')
    echo "[$timestamp] $1" | tee -a "$LOG_FILE"
}

# Check specific condition and log if changed
check_condition() {
    local condition_name=$1
    local current_value=$2
    local previous_value=$3
    
    if [[ "$current_value" != "$previous_value" ]]; then
        log_event "  [変化] ${condition_name}: ${previous_value} → ${current_value}"
        return 0  # Changed
    fi
    return 1  # Not changed
}

# Main monitoring
main() {
    clear
    print_header "PlayCover リアルタイム監視"
    echo ""
    
    # Get bundle ID
    echo -n "監視するアプリの Bundle ID を入力してください: "
    read TARGET_BUNDLE_ID
    
    if [[ -z "$TARGET_BUNDLE_ID" ]]; then
        print_error "Bundle ID が入力されていません"
        exit 1
    fi
    
    # Setup log file
    LOG_FILE="${LOG_DIR}/playcover-realtime-$(date +%Y%m%d-%H%M%S).log"
    
    clear
    print_header "PlayCover リアルタイム監視 - ${TARGET_BUNDLE_ID}"
    echo ""
    print_info "ログファイル: $LOG_FILE"
    echo ""
    
    log_event "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_event "PlayCover リアルタイム監視開始"
    log_event "Target Bundle ID: $TARGET_BUNDLE_ID"
    log_event "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_event ""
    
    local app_path="${PLAYCOVER_APPS}/${TARGET_BUNDLE_ID}.app"
    local settings_file="${PLAYCOVER_SETTINGS}/${TARGET_BUNDLE_ID}.plist"
    
    # Initialize tracking variables
    local prev_app_exists="false"
    local prev_info_plist_exists="false"
    local prev_codesig_exists="false"
    local prev_settings_exists="false"
    local prev_settings_has_resolution="false"
    local prev_executable_exists="false"
    local prev_executable_location=""
    local prev_file_count=0
    local prev_app_mtime=0
    local prev_settings_mtime=0
    local prev_playcover_running="false"
    
    print_warning "今すぐ PlayCover で IPA をインストールしてください"
    print_info "1秒間隔で監視します (Ctrl+C で停止)..."
    echo ""
    
    log_event "初期状態:"
    if [[ -d "$app_path" ]]; then
        log_event "  アプリディレクトリ: 存在"
        prev_app_exists="true"
    else
        log_event "  アプリディレクトリ: なし"
    fi
    
    if [[ -f "$settings_file" ]]; then
        log_event "  設定ファイル: 存在"
        prev_settings_exists="true"
        prev_settings_mtime=$(stat -f %m "$settings_file" 2>/dev/null || echo 0)
        log_event "    初期mtime: $prev_settings_mtime ($(date -r $prev_settings_mtime '+%H:%M:%S'))"
    else
        log_event "  設定ファイル: なし"
    fi
    
    log_event ""
    log_event "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_event "監視ループ開始"
    log_event "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    local check_count=0
    local stable_seconds=0
    
    while true; do
        ((check_count++))
        local any_change=false
        
        log_event ""
        log_event "▼ チェック #${check_count} ($(date '+%H:%M:%S'))"
        
        # Check PlayCover process
        local playcover_running="false"
        if pgrep -x "PlayCover" > /dev/null; then
            playcover_running="true"
        fi
        
        if check_condition "PlayCover実行中" "$playcover_running" "$prev_playcover_running"; then
            any_change=true
            if [[ "$playcover_running" == "false" ]]; then
                log_event "  ⚠️  PlayCover が終了しました！"
            fi
        fi
        prev_playcover_running=$playcover_running
        
        # Check app directory
        local app_exists="false"
        if [[ -d "$app_path" ]]; then
            app_exists="true"
        fi
        
        if check_condition "アプリディレクトリ" "$app_exists" "$prev_app_exists"; then
            any_change=true
        fi
        prev_app_exists=$app_exists
        
        if [[ "$app_exists" == "true" ]]; then
            # Check Info.plist
            local info_plist_exists="false"
            if [[ -f "${app_path}/Info.plist" ]]; then
                info_plist_exists="true"
            fi
            
            if check_condition "Info.plist" "$info_plist_exists" "$prev_info_plist_exists"; then
                any_change=true
                if [[ "$info_plist_exists" == "true" ]]; then
                    local app_name=$(/usr/libexec/PlistBuddy -c "Print :CFBundleName" "${app_path}/Info.plist" 2>/dev/null)
                    local exec_name=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "${app_path}/Info.plist" 2>/dev/null)
                    log_event "    アプリ名: $app_name"
                    log_event "    実行ファイル名: $exec_name"
                fi
            fi
            prev_info_plist_exists=$info_plist_exists
            
            # Check _CodeSignature
            local codesig_exists="false"
            if [[ -d "${app_path}/_CodeSignature" ]]; then
                codesig_exists="true"
            fi
            
            if check_condition "_CodeSignature" "$codesig_exists" "$prev_codesig_exists"; then
                any_change=true
            fi
            prev_codesig_exists=$codesig_exists
            
            # Check executable (try multiple locations)
            local executable_exists="false"
            local executable_location=""
            
            if [[ -f "${app_path}/Info.plist" ]]; then
                local exec_name=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "${app_path}/Info.plist" 2>/dev/null)
                
                if [[ -n "$exec_name" ]]; then
                    # Check root directory
                    if [[ -f "${app_path}/${exec_name}" ]]; then
                        executable_exists="true"
                        executable_location="ROOT:${exec_name}"
                    # Check MacOS directory
                    elif [[ -f "${app_path}/MacOS/${exec_name}" ]]; then
                        executable_exists="true"
                        executable_location="MacOS/${exec_name}"
                    # Check Wrapper directory
                    elif [[ -f "${app_path}/Wrapper/${exec_name}" ]]; then
                        executable_exists="true"
                        executable_location="Wrapper/${exec_name}"
                    fi
                fi
            fi
            
            if check_condition "実行ファイル" "$executable_location" "$prev_executable_location"; then
                any_change=true
                if [[ -n "$executable_location" ]]; then
                    log_event "    場所: $executable_location"
                fi
            fi
            prev_executable_location=$executable_location
            
            # Check file count
            local file_count=$(find "$app_path" -type f 2>/dev/null | wc -l | tr -d ' ')
            if [[ $file_count -ne $prev_file_count ]]; then
                local diff=$((file_count - prev_file_count))
                log_event "  [変化] ファイル数: ${prev_file_count} → ${file_count} (${diff:+"+"}${diff})"
                any_change=true
            fi
            prev_file_count=$file_count
            
            # Check app mtime
            local app_mtime=$(stat -f %m "$app_path" 2>/dev/null || echo 0)
            if [[ $app_mtime -ne $prev_app_mtime ]] && [[ $prev_app_mtime -ne 0 ]]; then
                log_event "  [変化] App mtime: $(date -r $prev_app_mtime '+%H:%M:%S') → $(date -r $app_mtime '+%H:%M:%S')"
                any_change=true
            fi
            prev_app_mtime=$app_mtime
        fi
        
        # Check settings file
        local settings_exists="false"
        if [[ -f "$settings_file" ]]; then
            settings_exists="true"
        fi
        
        if check_condition "設定ファイル存在" "$settings_exists" "$prev_settings_exists"; then
            any_change=true
        fi
        prev_settings_exists=$settings_exists
        
        if [[ "$settings_exists" == "true" ]]; then
            # Check settings mtime
            local settings_mtime=$(stat -f %m "$settings_file" 2>/dev/null || echo 0)
            if [[ $settings_mtime -ne $prev_settings_mtime ]] && [[ $prev_settings_mtime -ne 0 ]]; then
                log_event "  [変化] 設定mtime: $(date -r $prev_settings_mtime '+%H:%M:%S') → $(date -r $settings_mtime '+%H:%M:%S') (${settings_mtime})"
                any_change=true
                
                # Log all keys when settings file is updated
                log_event "    設定内容:"
                plutil -convert xml1 -o - "$settings_file" 2>/dev/null | grep -o "<key>[^<]*</key>" | sed 's/<key>//g' | sed 's/<\/key>//g' | while read -r key; do
                    local value=$(/usr/libexec/PlistBuddy -c "Print :${key}" "$settings_file" 2>/dev/null | head -1)
                    log_event "      ${key} = ${value}"
                done
            fi
            prev_settings_mtime=$settings_mtime
            
            # Check resolution key
            local settings_has_resolution="false"
            if /usr/libexec/PlistBuddy -c "Print :resolution" "$settings_file" >/dev/null 2>&1; then
                settings_has_resolution="true"
            fi
            
            if check_condition "resolution キー" "$settings_has_resolution" "$prev_settings_has_resolution"; then
                any_change=true
                if [[ "$settings_has_resolution" == "true" ]]; then
                    local resolution=$(/usr/libexec/PlistBuddy -c "Print :resolution" "$settings_file" 2>/dev/null)
                    log_event "    resolution 値: $resolution"
                fi
            fi
            prev_settings_has_resolution=$settings_has_resolution
        fi
        
        # Stability check
        if [[ "$any_change" == false ]]; then
            ((stable_seconds++))
            log_event "  ✓ 安定: ${stable_seconds}秒間変化なし"
            
            # Show current detection logic status
            if [[ "$app_exists" == "true" ]] && [[ "$settings_exists" == "true" ]]; then
                log_event ""
                log_event "  現在の検知ロジック判定:"
                log_event "    Phase 1 (構造): Info.plist=${info_plist_exists}, CodeSig=${codesig_exists}"
                log_event "    Phase 2 (完了): resolution=${settings_has_resolution}, executable=${executable_exists}"
                log_event "    Phase 3 (安定): ${stable_seconds}秒 (必要: 6秒)"
                
                if [[ "$info_plist_exists" == "true" ]] && [[ "$codesig_exists" == "true" ]] && \
                   [[ "$settings_has_resolution" == "true" ]] && [[ "$executable_exists" == "true" ]] && \
                   [[ $stable_seconds -ge 6 ]]; then
                    log_event "    >>> 完了判定条件を満たしています <<<"
                fi
            fi
        else
            stable_seconds=0
        fi
        
        sleep 1
    done
}

# Handle Ctrl+C
trap 'echo ""; log_event ""; log_event "監視を中断しました"; print_info "ログファイル: $LOG_FILE"; exit 0' INT

main
