#!/bin/zsh

# PlayCover Debug Detection Monitor
# 実際の検知ロジックの動作を詳細に追跡

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

# Main
main() {
    clear
    echo "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "${BLUE}  PlayCover デバッグ検知モニター${NC}"
    echo "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Get bundle ID
    echo -n "監視するアプリの Bundle ID を入力してください: "
    read TARGET_BUNDLE_ID
    
    if [[ -z "$TARGET_BUNDLE_ID" ]]; then
        print_error "Bundle ID が入力されていません"
        exit 1
    fi
    
    # Setup log file
    LOG_FILE="${LOG_DIR}/playcover-debug-$(date +%Y%m%d-%H%M%S).log"
    
    clear
    echo "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "${BLUE}  PlayCover デバッグ検知モニター${NC}"
    echo "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    print_info "Bundle ID: $TARGET_BUNDLE_ID"
    print_info "ログファイル: $LOG_FILE"
    echo ""
    
    log_event "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_event "デバッグ検知モニター開始"
    log_event "Target Bundle ID: $TARGET_BUNDLE_ID"
    log_event "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_event ""
    
    local app_path="${PLAYCOVER_APPS}/${TARGET_BUNDLE_ID}.app"
    local settings_file="${PLAYCOVER_SETTINGS}/${TARGET_BUNDLE_ID}.plist"
    
    # Initialize tracking variables (same as actual detection logic)
    local last_settings_mtime=0
    local settings_stable_count=0
    local required_stable_checks=2
    local check_interval=3
    local elapsed=0
    local max_wait=300
    
    print_warning "今すぐ PlayCover で IPA をインストールしてください"
    print_info "3秒間隔で監視します (Ctrl+C で停止)..."
    echo ""
    
    log_event "初期状態:"
    log_event "  last_settings_mtime: ${last_settings_mtime}"
    log_event "  settings_stable_count: ${settings_stable_count}"
    log_event "  required_stable_checks: ${required_stable_checks}"
    log_event ""
    
    local check_count=0
    
    while [[ $elapsed -lt $max_wait ]]; do
        sleep $check_interval
        elapsed=$((elapsed + check_interval))
        ((check_count++))
        
        log_event ""
        log_event "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_event "チェック #${check_count} (経過: ${elapsed}秒)"
        log_event "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        # Check PlayCover process
        local playcover_running="false"
        if pgrep -x "PlayCover" > /dev/null; then
            playcover_running="true"
        fi
        log_event "PlayCover実行中: ${playcover_running}"
        
        # Check app directory
        local app_exists="false"
        if [[ -d "$app_path" ]]; then
            app_exists="true"
        fi
        log_event "アプリディレクトリ: ${app_exists}"
        
        if [[ "$app_exists" == "true" ]]; then
            # Phase 1: Structure validation
            local structure_valid="false"
            local info_plist_exists="false"
            local codesig_exists="false"
            
            if [[ -f "${app_path}/Info.plist" ]]; then
                info_plist_exists="true"
                local app_name=$(/usr/libexec/PlistBuddy -c "Print :CFBundleName" "${app_path}/Info.plist" 2>/dev/null)
                local app_version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${app_path}/Info.plist" 2>/dev/null)
                
                if [[ -d "${app_path}/_CodeSignature" ]] && [[ -n "$app_name" ]] && [[ -n "$app_version" ]]; then
                    codesig_exists="true"
                    structure_valid="true"
                fi
            fi
            
            log_event ""
            log_event "Phase 1 (構造検証):"
            log_event "  Info.plist: ${info_plist_exists}"
            log_event "  _CodeSignature: ${codesig_exists}"
            log_event "  structure_valid: ${structure_valid}"
            
            # Phase 2: Settings file mtime stability
            log_event ""
            log_event "Phase 2 (設定ファイルmtime安定性):"
            
            local settings_exists="false"
            if [[ -f "$settings_file" ]]; then
                settings_exists="true"
            fi
            log_event "  設定ファイル存在: ${settings_exists}"
            
            if [[ "$settings_exists" == "true" ]]; then
                local current_settings_mtime=$(stat -f %m "$settings_file" 2>/dev/null || echo 0)
                log_event "  current_settings_mtime: ${current_settings_mtime} ($(date -r $current_settings_mtime '+%H:%M:%S' 2>/dev/null || echo 'N/A'))"
                log_event "  last_settings_mtime: ${last_settings_mtime} ($(date -r $last_settings_mtime '+%H:%M:%S' 2>/dev/null || echo 'N/A'))"
                
                # Check if settings file mtime changed
                if [[ $current_settings_mtime -ne $last_settings_mtime ]]; then
                    log_event "  → mtime変化検出！カウンターリセット"
                    settings_stable_count=0
                    last_settings_mtime=$current_settings_mtime
                else
                    log_event "  → mtime変化なし"
                    if [[ $last_settings_mtime -gt 0 ]]; then
                        ((settings_stable_count++))
                        log_event "  → 安定カウント増加: ${settings_stable_count}"
                    else
                        log_event "  → last_settings_mtime が 0 なのでカウントしない"
                    fi
                fi
            else
                log_event "  設定ファイルが存在しないためスキップ"
            fi
            
            log_event ""
            log_event "現在の状態:"
            log_event "  last_settings_mtime: ${last_settings_mtime}"
            log_event "  settings_stable_count: ${settings_stable_count}"
            log_event "  required_stable_checks: ${required_stable_checks}"
            
            # Completion check
            log_event ""
            if [[ "$structure_valid" == "true" ]] && [[ $settings_stable_count -ge $required_stable_checks ]]; then
                log_event "✅ 完了条件を満たしました！"
                log_event "  → structure_valid: true"
                log_event "  → settings_stable_count (${settings_stable_count}) >= required_stable_checks (${required_stable_checks})"
                
                print_success "完了検知！"
                break
            else
                log_event "❌ 完了条件を満たしていません"
                if [[ "$structure_valid" != "true" ]]; then
                    log_event "  理由: 構造検証が未完了"
                fi
                if [[ $settings_stable_count -lt $required_stable_checks ]]; then
                    log_event "  理由: 安定カウント不足 (${settings_stable_count} < ${required_stable_checks})"
                fi
            fi
        fi
    done
    
    log_event ""
    log_event "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_event "監視終了"
    log_event "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    echo ""
    print_info "ログファイル: $LOG_FILE"
    echo ""
}

# Handle Ctrl+C
trap 'echo ""; log_event ""; log_event "監視を中断しました"; print_info "ログファイル: $LOG_FILE"; exit 0' INT

main
