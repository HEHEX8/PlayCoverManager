#!/bin/zsh

# PlayCover Installation Process Analyzer
# このスクリプトはPlayCoverのインストール動作を詳細にモニタリングします

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
readonly PLAYCOVER_KEYMAPPING="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/Keymapping"

# Log file
readonly LOG_FILE="${HOME}/Desktop/playcover-install-analysis-$(date +%Y%m%d-%H%M%S).log"

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

# Get baseline state before installation
get_directory_state() {
    local dir=$1
    
    if [[ ! -d "$dir" ]]; then
        echo "DIRECTORY_NOT_EXIST"
        return
    fi
    
    # Get file count and latest modification time
    local file_count=$(find "$dir" -type f 2>/dev/null | wc -l | tr -d ' ')
    local latest_mtime=$(find "$dir" -type f -exec stat -f %m {} \; 2>/dev/null | sort -n | tail -1)
    
    echo "${file_count}|${latest_mtime}"
}

# Monitor a directory for changes
monitor_directory() {
    local dir=$1
    local label=$2
    local baseline=$3
    
    if [[ ! -d "$dir" ]]; then
        log_event "  ${label}: ディレクトリが存在しません"
        return
    fi
    
    local current_state=$(get_directory_state "$dir")
    
    if [[ "$current_state" != "$baseline" ]]; then
        local file_count=$(echo "$current_state" | cut -d'|' -f1)
        local mtime=$(echo "$current_state" | cut -d'|' -f2)
        
        log_event "  ${label}: 変更検出 (ファイル数: ${file_count}, 最終更新: ${mtime})"
        
        # List new files if any
        if [[ -n "$mtime" ]]; then
            local new_files=$(find "$dir" -type f -newermt "@$((mtime - 5))" 2>/dev/null)
            if [[ -n "$new_files" ]]; then
                echo "$new_files" | while read -r file; do
                    log_event "    新規/更新: $(basename "$file")"
                done
            fi
        fi
    fi
}

# Monitor PlayCover process
monitor_playcover_process() {
    local playcover_running=$(pgrep -x "PlayCover" 2>/dev/null)
    
    if [[ -n "$playcover_running" ]]; then
        log_event "  PlayCoverプロセス: 実行中 (PID: $playcover_running)"
        
        # Get CPU and memory usage
        local process_info=$(ps -p "$playcover_running" -o %cpu,%mem,rss,vsz 2>/dev/null | tail -1)
        log_event "    CPU/MEM/RSS/VSZ: $process_info"
        
        return 0
    else
        log_event "  PlayCoverプロセス: 停止"
        return 1
    fi
}

# Check for specific app installation
check_app_installation() {
    local bundle_id=$1
    
    if [[ ! -d "$PLAYCOVER_APPS" ]]; then
        return 1
    fi
    
    while IFS= read -r app_path; do
        if [[ -f "${app_path}/Info.plist" ]]; then
            local app_bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "${app_path}/Info.plist" 2>/dev/null)
            
            if [[ "$app_bundle_id" == "$bundle_id" ]]; then
                local app_name=$(/usr/libexec/PlistBuddy -c "Print :CFBundleName" "${app_path}/Info.plist" 2>/dev/null)
                log_event "  アプリ検出: $app_name ($bundle_id)"
                
                # Check structure
                log_event "    構造チェック:"
                
                if [[ -f "${app_path}/Info.plist" ]]; then
                    log_event "      ✓ Info.plist 存在"
                else
                    log_event "      ✗ Info.plist なし"
                fi
                
                if [[ -d "${app_path}/_CodeSignature" ]]; then
                    log_event "      ✓ _CodeSignature 存在"
                else
                    log_event "      ✗ _CodeSignature なし"
                fi
                
                local executable=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "${app_path}/Info.plist" 2>/dev/null)
                if [[ -n "$executable" ]] && [[ -f "${app_path}/MacOS/${executable}" ]]; then
                    log_event "      ✓ 実行ファイル存在: $executable"
                else
                    log_event "      ✗ 実行ファイルなし"
                fi
                
                # Check settings file
                local settings_file="${PLAYCOVER_SETTINGS}/${bundle_id}.plist"
                if [[ -f "$settings_file" ]]; then
                    log_event "      ✓ 設定ファイル存在"
                    
                    # Check settings content
                    local keymapping_enabled=$(/usr/libexec/PlistBuddy -c "Print :keymapping" "$settings_file" 2>/dev/null)
                    log_event "        Keymapping: ${keymapping_enabled:-未設定}"
                else
                    log_event "      ✗ 設定ファイルなし"
                fi
                
                # Check keymapping directory
                if [[ -d "$PLAYCOVER_KEYMAPPING" ]]; then
                    local keymapping_files=$(find "$PLAYCOVER_KEYMAPPING" -name "*${bundle_id}*" 2>/dev/null)
                    if [[ -n "$keymapping_files" ]]; then
                        log_event "      ✓ Keymappingファイル存在"
                    else
                        log_event "      - Keymapping未設定"
                    fi
                else
                    log_event "      - Keymappingディレクトリなし"
                fi
                
                # Get file modification times
                local info_plist_mtime=$(stat -f %m "${app_path}/Info.plist" 2>/dev/null)
                local app_mtime=$(stat -f %m "$app_path" 2>/dev/null)
                log_event "    タイムスタンプ:"
                log_event "      Info.plist: $(date -r $info_plist_mtime '+%H:%M:%S')"
                log_event "      App bundle: $(date -r $app_mtime '+%H:%M:%S')"
                
                if [[ -f "$settings_file" ]]; then
                    local settings_mtime=$(stat -f %m "$settings_file" 2>/dev/null)
                    log_event "      設定ファイル: $(date -r $settings_mtime '+%H:%M:%S')"
                fi
                
                return 0
            fi
        fi
    done < <(find "$PLAYCOVER_APPS" -name "*.app" -maxdepth 1 -type d 2>/dev/null)
    
    return 1
}

# Main monitoring loop
main() {
    clear
    print_header "PlayCover インストール動作解析"
    echo ""
    
    print_info "ログファイル: $LOG_FILE"
    echo ""
    
    # Get bundle ID to monitor
    echo -n "監視するアプリのBundle ID を入力してください: "
    read TARGET_BUNDLE_ID
    
    if [[ -z "$TARGET_BUNDLE_ID" ]]; then
        print_error "Bundle ID が入力されていません"
        exit 1
    fi
    
    echo ""
    print_info "Bundle ID: $TARGET_BUNDLE_ID"
    print_info "監視を開始します..."
    echo ""
    
    log_event "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_event "PlayCover インストール動作解析"
    log_event "Target Bundle ID: $TARGET_BUNDLE_ID"
    log_event "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_event ""
    
    # Get baseline state
    print_info "ベースライン状態を取得中..."
    log_event "ベースライン状態:"
    
    local baseline_apps=$(get_directory_state "$PLAYCOVER_APPS")
    log_event "  Applications: $baseline_apps"
    
    local baseline_settings=$(get_directory_state "$PLAYCOVER_SETTINGS")
    log_event "  Settings: $baseline_settings"
    
    local baseline_keymapping=$(get_directory_state "$PLAYCOVER_KEYMAPPING")
    log_event "  Keymapping: $baseline_keymapping"
    
    echo ""
    print_success "ベースライン取得完了"
    print_warning "今すぐ PlayCover で IPA をインストールしてください"
    echo ""
    print_info "監視を開始します (Ctrl+C で停止)..."
    echo ""
    
    log_event ""
    log_event "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_event "監視開始"
    log_event "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_event ""
    
    local check_count=0
    local app_found=false
    local installation_complete=false
    local last_change_time=$(date +%s)
    local stable_duration=0
    
    while true; do
        ((check_count++))
        
        log_event ""
        log_event "チェック #${check_count} (経過時間: $((check_count * 2))秒)"
        log_event "$(date '+%Y-%m-%d %H:%M:%S')"
        
        # Monitor PlayCover process
        if monitor_playcover_process; then
            # PlayCover is running
            
            # Check directories for changes
            monitor_directory "$PLAYCOVER_APPS" "Applications" "$baseline_apps"
            monitor_directory "$PLAYCOVER_SETTINGS" "Settings" "$baseline_settings"
            monitor_directory "$PLAYCOVER_KEYMAPPING" "Keymapping" "$baseline_keymapping"
            
            # Check for specific app
            if check_app_installation "$TARGET_BUNDLE_ID"; then
                if [[ "$app_found" == false ]]; then
                    log_event ""
                    log_event "🎉 ターゲットアプリが検出されました！"
                    app_found=true
                    last_change_time=$(date +%s)
                fi
                
                # Check stability
                local current_time=$(date +%s)
                local current_apps=$(get_directory_state "$PLAYCOVER_APPS")
                local current_settings=$(get_directory_state "$PLAYCOVER_SETTINGS")
                
                if [[ "$current_apps" == "$baseline_apps" ]] && [[ "$current_settings" == "$baseline_settings" ]]; then
                    stable_duration=$((current_time - last_change_time))
                    log_event "  安定状態: ${stable_duration}秒間変更なし"
                    
                    if [[ $stable_duration -ge 10 ]] && [[ "$installation_complete" == false ]]; then
                        log_event ""
                        log_event "✅ インストール完了と判定 (10秒間変更なし)"
                        installation_complete=true
                    fi
                else
                    last_change_time=$current_time
                    stable_duration=0
                    log_event "  状態: ファイル変更を検出"
                    baseline_apps=$current_apps
                    baseline_settings=$current_settings
                fi
            fi
        else
            # PlayCover stopped
            log_event ""
            log_event "PlayCover が停止しました"
            
            if [[ "$app_found" == true ]]; then
                log_event ""
                log_event "最終状態確認:"
                check_app_installation "$TARGET_BUNDLE_ID"
                
                log_event ""
                log_event "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                log_event "監視終了 (PlayCover停止)"
                log_event "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                
                echo ""
                print_success "解析完了"
                print_info "ログファイル: $LOG_FILE"
                echo ""
                
                break
            fi
        fi
        
        # Update baselines for next check
        baseline_apps=$(get_directory_state "$PLAYCOVER_APPS")
        baseline_settings=$(get_directory_state "$PLAYCOVER_SETTINGS")
        baseline_keymapping=$(get_directory_state "$PLAYCOVER_KEYMAPPING")
        
        sleep 2
    done
}

# Handle Ctrl+C
trap 'echo ""; log_event ""; log_event "監視を中断しました"; print_info "ログファイル: $LOG_FILE"; exit 0' INT

main
