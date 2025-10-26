#!/bin/zsh

# PlayCover Deep Installation Analyzer
# 新規インストール・上書きインストール両方を徹底解析

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
readonly PLAYCOVER_DATA="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/Data"

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

# Deep structure analysis
analyze_app_structure() {
    local app_path=$1
    local indent="${2:-  }"
    
    if [[ ! -d "$app_path" ]]; then
        log_event "${indent}アプリが存在しません"
        return 1
    fi
    
    log_event "${indent}━━━━ アプリ構造の詳細解析 ━━━━"
    
    # Basic Info
    if [[ -f "${app_path}/Info.plist" ]]; then
        local bundle_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "${app_path}/Info.plist" 2>/dev/null)
        local app_name=$(/usr/libexec/PlistBuddy -c "Print :CFBundleName" "${app_path}/Info.plist" 2>/dev/null)
        local version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "${app_path}/Info.plist" 2>/dev/null)
        local executable=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "${app_path}/Info.plist" 2>/dev/null)
        
        log_event "${indent}アプリ名: $app_name"
        log_event "${indent}Bundle ID: $bundle_id"
        log_event "${indent}バージョン: $version"
        log_event "${indent}実行ファイル名: $executable"
    else
        log_event "${indent}✗ Info.plist が存在しません"
    fi
    
    # Directory structure
    log_event "${indent}"
    log_event "${indent}ディレクトリ構造:"
    
    # List all first-level directories
    if [[ -d "$app_path" ]]; then
        find "$app_path" -maxdepth 2 -type d 2>/dev/null | while read -r dir; do
            local rel_path=${dir#$app_path/}
            if [[ "$rel_path" != "$app_path" ]]; then
                local file_count=$(find "$dir" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
                log_event "${indent}  [DIR] $rel_path (ファイル数: $file_count)"
            fi
        done
    fi
    
    # Check for executable in all common locations
    log_event "${indent}"
    log_event "${indent}実行ファイル検索:"
    
    local executable_name=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "${app_path}/Info.plist" 2>/dev/null)
    
    if [[ -n "$executable_name" ]]; then
        # Check common locations
        local locations=(
            "MacOS/${executable_name}"
            "Contents/MacOS/${executable_name}"
            "Wrapper/${executable_name}"
            "${executable_name}"
        )
        
        local found=false
        for loc in "${locations[@]}"; do
            if [[ -f "${app_path}/${loc}" ]]; then
                log_event "${indent}  ✓ 発見: ${loc}"
                local size=$(stat -f %z "${app_path}/${loc}" 2>/dev/null)
                local mtime=$(stat -f %m "${app_path}/${loc}" 2>/dev/null)
                log_event "${indent}    サイズ: ${size} bytes"
                log_event "${indent}    更新時刻: $(date -r $mtime '+%H:%M:%S')"
                found=true
            else
                log_event "${indent}  ✗ なし: ${loc}"
            fi
        done
        
        if [[ "$found" == false ]]; then
            # Search anywhere in the app bundle
            log_event "${indent}"
            log_event "${indent}  全体検索を実行中..."
            local search_result=$(find "$app_path" -name "$executable_name" -type f 2>/dev/null)
            if [[ -n "$search_result" ]]; then
                echo "$search_result" | while read -r file; do
                    local rel_path=${file#$app_path/}
                    log_event "${indent}  ✓ 発見（想定外の場所）: ${rel_path}"
                done
            else
                log_event "${indent}  ✗ アプリ内に実行ファイルが見つかりません"
            fi
        fi
    fi
    
    # Check key files
    log_event "${indent}"
    log_event "${indent}重要ファイルチェック:"
    
    local key_files=(
        "Info.plist"
        "_CodeSignature/CodeResources"
        "PkgInfo"
        "embedded.mobileprovision"
        "SC_Info/Manifest.plist"
    )
    
    for file in "${key_files[@]}"; do
        if [[ -f "${app_path}/${file}" ]] || [[ -d "${app_path}/${file%/*}" ]]; then
            if [[ -f "${app_path}/${file}" ]]; then
                local size=$(stat -f %z "${app_path}/${file}" 2>/dev/null)
                local mtime=$(stat -f %m "${app_path}/${file}" 2>/dev/null)
                log_event "${indent}  ✓ ${file} (${size} bytes, $(date -r $mtime '+%H:%M:%S'))"
            else
                log_event "${indent}  ✓ ${file%/*}/ (ディレクトリ)"
            fi
        else
            log_event "${indent}  ✗ ${file}"
        fi
    done
    
    # Timestamps analysis
    log_event "${indent}"
    log_event "${indent}タイムスタンプ分析:"
    
    local info_plist_mtime=$(stat -f %m "${app_path}/Info.plist" 2>/dev/null)
    local app_bundle_mtime=$(stat -f %m "$app_path" 2>/dev/null)
    
    log_event "${indent}  App bundle: $(date -r $app_bundle_mtime '+%H:%M:%S') (Unix: $app_bundle_mtime)"
    log_event "${indent}  Info.plist: $(date -r $info_plist_mtime '+%H:%M:%S') (Unix: $info_plist_mtime)"
    
    # Find newest file
    local newest_file=$(find "$app_path" -type f -exec stat -f "%m %N" {} \; 2>/dev/null | sort -rn | head -1)
    if [[ -n "$newest_file" ]]; then
        local newest_mtime=$(echo "$newest_file" | awk '{print $1}')
        local newest_path=$(echo "$newest_file" | cut -d' ' -f2-)
        local rel_newest=${newest_path#$app_path/}
        log_event "${indent}  最新ファイル: ${rel_newest} ($(date -r $newest_mtime '+%H:%M:%S'))"
    fi
    
    # Total file count
    local total_files=$(find "$app_path" -type f 2>/dev/null | wc -l | tr -d ' ')
    log_event "${indent}  総ファイル数: ${total_files}"
}

# Analyze settings file in detail
analyze_settings_file() {
    local bundle_id=$1
    local indent="${2:-  }"
    
    local settings_file="${PLAYCOVER_SETTINGS}/${bundle_id}.plist"
    
    log_event "${indent}━━━━ 設定ファイル解析 ━━━━"
    
    if [[ ! -f "$settings_file" ]]; then
        log_event "${indent}設定ファイルが存在しません: $settings_file"
        return 1
    fi
    
    log_event "${indent}ファイルパス: $settings_file"
    
    local size=$(stat -f %z "$settings_file" 2>/dev/null)
    local mtime=$(stat -f %m "$settings_file" 2>/dev/null)
    local ctime=$(stat -f %c "$settings_file" 2>/dev/null)
    
    log_event "${indent}サイズ: ${size} bytes"
    log_event "${indent}作成時刻: $(date -r $ctime '+%H:%M:%S') (Unix: $ctime)"
    log_event "${indent}更新時刻: $(date -r $mtime '+%H:%M:%S') (Unix: $mtime)"
    
    # Read all keys
    log_event "${indent}"
    log_event "${indent}設定内容:"
    
    # Try to read all keys using plutil
    local plist_xml=$(plutil -convert xml1 -o - "$settings_file" 2>/dev/null)
    
    if [[ -n "$plist_xml" ]]; then
        # Extract all keys
        echo "$plist_xml" | grep -o "<key>[^<]*</key>" | sed 's/<key>//g' | sed 's/<\/key>//g' | while read -r key; do
            local value=$(/usr/libexec/PlistBuddy -c "Print :${key}" "$settings_file" 2>/dev/null)
            log_event "${indent}  ${key} = ${value}"
        done
    else
        log_event "${indent}  ✗ plist の読み込みに失敗"
    fi
}

# Monitor file system events in real-time
monitor_filesystem_events() {
    local target_dir=$1
    local label=$2
    local duration=$3
    local output_file=$4
    
    log_event "  ${label}: fswatch を開始 (${duration}秒間)"
    
    # Use fswatch to monitor real-time changes
    timeout "$duration" fswatch -r -t -x "$target_dir" 2>/dev/null | while read -r line; do
        echo "$line" >> "$output_file"
        
        # Parse and log important events
        if echo "$line" | grep -q "Created\|Updated\|Renamed"; then
            log_event "    [FS] $line"
        fi
    done &
    
    return 0
}

# Compare before/after state
compare_states() {
    local before_file=$1
    local after_file=$2
    local label=$3
    local indent="${4:-  }"
    
    log_event "${indent}━━━━ ${label} 変更分析 ━━━━"
    
    if [[ ! -f "$before_file" ]] || [[ ! -f "$after_file" ]]; then
        log_event "${indent}比較ファイルが存在しません"
        return 1
    fi
    
    # File count difference
    local before_count=$(cat "$before_file" | wc -l | tr -d ' ')
    local after_count=$(cat "$after_file" | wc -l | tr -d ' ')
    local diff_count=$((after_count - before_count))
    
    log_event "${indent}ファイル数変化: ${before_count} → ${after_count} (${diff_count:+"+"}${diff_count})"
    
    # New files
    log_event "${indent}"
    log_event "${indent}新規ファイル:"
    comm -13 <(sort "$before_file") <(sort "$after_file") | head -20 | while read -r file; do
        if [[ -f "$file" ]]; then
            local size=$(stat -f %z "$file" 2>/dev/null)
            local rel_path=$(echo "$file" | sed "s|${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/||")
            log_event "${indent}  + ${rel_path} (${size} bytes)"
        fi
    done
    
    # Deleted files
    log_event "${indent}"
    log_event "${indent}削除ファイル:"
    comm -23 <(sort "$before_file") <(sort "$after_file") | head -20 | while read -r file; do
        local rel_path=$(echo "$file" | sed "s|${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/||")
        log_event "${indent}  - ${rel_path}"
    done
}

# Check for PlayCover process details
analyze_playcover_process() {
    local indent="${1:-  }"
    
    log_event "${indent}━━━━ PlayCover プロセス解析 ━━━━"
    
    local pid=$(pgrep -x "PlayCover" 2>/dev/null)
    
    if [[ -z "$pid" ]]; then
        log_event "${indent}PlayCover プロセスが見つかりません"
        return 1
    fi
    
    log_event "${indent}PID: $pid"
    
    # Process info
    local ps_info=$(ps -p "$pid" -o %cpu,%mem,rss,vsz,state,start,time,command 2>/dev/null | tail -1)
    log_event "${indent}CPU/MEM/RSS/VSZ: $ps_info"
    
    # Open files
    log_event "${indent}"
    log_event "${indent}開いているファイル (PlayCover関連):"
    lsof -p "$pid" 2>/dev/null | grep -i "playcover\|\.app\|\.ipa" | head -20 | while read -r line; do
        log_event "${indent}  $line"
    done
    
    # Network connections
    log_event "${indent}"
    log_event "${indent}ネットワーク接続:"
    lsof -p "$pid" -i 2>/dev/null | head -10 | while read -r line; do
        log_event "${indent}  $line"
    done
}

# Main monitoring function
main() {
    clear
    print_header "PlayCover 徹底解析ツール"
    echo ""
    
    # Installation type selection
    echo "${CYAN}インストールタイプを選択してください:${NC}"
    echo "  ${GREEN}[1]${NC} 新規インストール"
    echo "  ${GREEN}[2]${NC} 上書きインストール"
    echo ""
    echo -n "選択 [1-2]: "
    read install_type
    
    case $install_type in
        1) INSTALL_TYPE="new" ;;
        2) INSTALL_TYPE="overwrite" ;;
        *) print_error "無効な選択"; exit 1 ;;
    esac
    
    clear
    print_header "PlayCover 徹底解析ツール - ${INSTALL_TYPE} インストール"
    echo ""
    
    # Get bundle ID
    echo -n "監視するアプリの Bundle ID を入力してください: "
    read TARGET_BUNDLE_ID
    
    if [[ -z "$TARGET_BUNDLE_ID" ]]; then
        print_error "Bundle ID が入力されていません"
        exit 1
    fi
    
    # Setup log file
    LOG_FILE="${LOG_DIR}/playcover-deep-analysis-${INSTALL_TYPE}-$(date +%Y%m%d-%H%M%S).log"
    
    echo ""
    print_info "Bundle ID: $TARGET_BUNDLE_ID"
    print_info "タイプ: $INSTALL_TYPE"
    print_info "ログファイル: $LOG_FILE"
    echo ""
    
    log_event "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_event "PlayCover 徹底解析"
    log_event "インストールタイプ: $INSTALL_TYPE"
    log_event "Target Bundle ID: $TARGET_BUNDLE_ID"
    log_event "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_event ""
    
    # Check if app exists (for overwrite scenario)
    local app_path="${PLAYCOVER_APPS}/${TARGET_BUNDLE_ID}.app"
    
    if [[ "$INSTALL_TYPE" == "overwrite" ]]; then
        if [[ ! -d "$app_path" ]]; then
            print_error "上書きインストールが選択されていますが、アプリが存在しません"
            log_event "エラー: アプリが存在しません: $app_path"
            exit 1
        fi
        
        print_info "既存アプリを解析中..."
        log_event "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_event "インストール前の状態"
        log_event "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_event ""
        
        analyze_app_structure "$app_path" "  "
        log_event ""
        analyze_settings_file "$TARGET_BUNDLE_ID" "  "
        log_event ""
    else
        if [[ -d "$app_path" ]]; then
            print_warning "新規インストールが選択されていますが、アプリが既に存在します"
            echo -n "続行しますか? [y/N]: "
            read confirm
            if [[ "$confirm" != "y" ]] && [[ "$confirm" != "Y" ]]; then
                exit 0
            fi
        fi
    fi
    
    # Take filesystem snapshot
    print_info "ファイルシステムのスナップショットを取得中..."
    
    local before_apps="${LOG_FILE}.before.apps"
    local before_settings="${LOG_FILE}.before.settings"
    local after_apps="${LOG_FILE}.after.apps"
    local after_settings="${LOG_FILE}.after.settings"
    
    find "$PLAYCOVER_APPS" -type f 2>/dev/null > "$before_apps"
    find "$PLAYCOVER_SETTINGS" -type f 2>/dev/null > "$before_settings"
    
    log_event "スナップショット取得完了"
    log_event "  Applications: $(cat "$before_apps" | wc -l | tr -d ' ') ファイル"
    log_event "  Settings: $(cat "$before_settings" | wc -l | tr -d ' ') ファイル"
    log_event ""
    
    # Analyze PlayCover process before installation
    analyze_playcover_process "  "
    log_event ""
    
    echo ""
    print_success "準備完了"
    print_warning "今すぐ PlayCover で IPA をインストールしてください"
    echo ""
    print_info "監視を開始します (Ctrl+C で停止)..."
    echo ""
    
    log_event "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_event "監視開始"
    log_event "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_event ""
    
    local check_count=0
    local app_appeared=false
    local installation_complete=false
    local last_settings_mtime=0
    local last_app_mtime=0
    local stable_count=0
    
    # Tracking variables for detailed analysis
    local first_detection_time=0
    local structure_complete_time=0
    local settings_updated_time=0
    
    while true; do
        ((check_count++))
        
        log_event ""
        log_event "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log_event "チェック #${check_count} (経過: $((check_count * 2))秒)"
        log_event "$(date '+%Y-%m-%d %H:%M:%S')"
        log_event "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        
        # Check PlayCover process
        local playcover_pid=$(pgrep -x "PlayCover" 2>/dev/null)
        
        if [[ -z "$playcover_pid" ]]; then
            log_event ""
            log_event "PlayCover プロセスが停止しました"
            break
        fi
        
        local cpu_usage=$(ps -p "$playcover_pid" -o %cpu | tail -1 | tr -d ' ')
        local mem_usage=$(ps -p "$playcover_pid" -o %mem | tail -1 | tr -d ' ')
        log_event "PlayCover プロセス: PID=$playcover_pid, CPU=${cpu_usage}%, MEM=${mem_usage}%"
        log_event ""
        
        # Check if app exists
        if [[ -d "$app_path" ]]; then
            if [[ "$app_appeared" == false ]]; then
                log_event "🎉 ターゲットアプリを検出！"
                app_appeared=true
                first_detection_time=$(date +%s)
                log_event ""
                
                analyze_app_structure "$app_path" "  "
                log_event ""
            fi
            
            # Get current state
            local current_app_mtime=$(stat -f %m "$app_path" 2>/dev/null || echo 0)
            local settings_file="${PLAYCOVER_SETTINGS}/${TARGET_BUNDLE_ID}.plist"
            local current_settings_mtime=0
            
            if [[ -f "$settings_file" ]]; then
                current_settings_mtime=$(stat -f %m "$settings_file" 2>/dev/null || echo 0)
            fi
            
            # Detect changes
            local app_changed=false
            local settings_changed=false
            
            if [[ $current_app_mtime -ne $last_app_mtime ]]; then
                app_changed=true
                log_event "📦 App bundle が更新されました ($(date -r $current_app_mtime '+%H:%M:%S'))"
                last_app_mtime=$current_app_mtime
                stable_count=0
            fi
            
            if [[ $current_settings_mtime -ne $last_settings_mtime ]]; then
                settings_changed=true
                log_event "⚙️  設定ファイルが更新されました ($(date -r $current_settings_mtime '+%H:%M:%S'))"
                
                if [[ $last_settings_mtime -eq 0 ]]; then
                    log_event "   → 設定ファイルが作成されました"
                fi
                
                last_settings_mtime=$current_settings_mtime
                settings_updated_time=$(date +%s)
                stable_count=0
                
                log_event ""
                analyze_settings_file "$TARGET_BUNDLE_ID" "  "
                log_event ""
            fi
            
            # Check stability
            if [[ "$app_changed" == false ]] && [[ "$settings_changed" == false ]]; then
                ((stable_count++))
                log_event "✓ 安定状態: $((stable_count * 2))秒間変更なし"
                
                # Check completion conditions
                if [[ $stable_count -ge 3 ]]; then
                    # 6 seconds stable
                    
                    # Check if settings file is newer than app bundle
                    if [[ $current_settings_mtime -gt $current_app_mtime ]]; then
                        log_event ""
                        log_event "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                        log_event "✅ インストール完了を検出"
                        log_event "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                        log_event ""
                        log_event "判定条件:"
                        log_event "  ✓ 設定ファイルが App bundle より新しい"
                        log_event "    App: $(date -r $current_app_mtime '+%H:%M:%S') (Unix: $current_app_mtime)"
                        log_event "    設定: $(date -r $current_settings_mtime '+%H:%M:%S') (Unix: $current_settings_mtime)"
                        log_event "    差分: $((current_settings_mtime - current_app_mtime))秒"
                        log_event "  ✓ 6秒間安定"
                        log_event ""
                        
                        installation_complete=true
                        
                        # Final detailed analysis
                        log_event "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                        log_event "最終状態解析"
                        log_event "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                        log_event ""
                        
                        analyze_app_structure "$app_path" "  "
                        log_event ""
                        analyze_settings_file "$TARGET_BUNDLE_ID" "  "
                        log_event ""
                        
                        # Timing analysis
                        if [[ $first_detection_time -gt 0 ]]; then
                            local current_time=$(date +%s)
                            local total_time=$((current_time - first_detection_time))
                            
                            log_event "タイミング分析:"
                            log_event "  初回検出 → 完了判定: ${total_time}秒"
                            
                            if [[ $settings_updated_time -gt 0 ]]; then
                                local settings_delay=$((settings_updated_time - first_detection_time))
                                log_event "  初回検出 → 設定更新: ${settings_delay}秒"
                            fi
                        fi
                        
                        break
                    else
                        log_event "   警告: 設定ファイルが App bundle より古い (まだ処理中？)"
                    fi
                fi
            fi
        else
            if [[ "$INSTALL_TYPE" == "new" ]]; then
                log_event "アプリ未検出 (新規インストール待機中...)"
            else
                log_event "⚠️  アプリが削除されました (再作成待機中...)"
            fi
        fi
        
        sleep 2
    done
    
    log_event ""
    log_event "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_event "インストール後の状態"
    log_event "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_event ""
    
    # Take final snapshot
    find "$PLAYCOVER_APPS" -type f 2>/dev/null > "$after_apps"
    find "$PLAYCOVER_SETTINGS" -type f 2>/dev/null > "$after_settings"
    
    # Compare states
    compare_states "$before_apps" "$after_apps" "Applications" "  "
    log_event ""
    compare_states "$before_settings" "$after_settings" "Settings" "  "
    log_event ""
    
    # Final app analysis
    if [[ -d "$app_path" ]]; then
        analyze_app_structure "$app_path" "  "
        log_event ""
        analyze_settings_file "$TARGET_BUNDLE_ID" "  "
    fi
    
    log_event ""
    log_event "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_event "解析完了"
    log_event "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    echo ""
    print_success "解析完了"
    print_info "ログファイル: $LOG_FILE"
    echo ""
    
    # Cleanup temp files
    rm -f "$before_apps" "$before_settings" "$after_apps" "$after_settings" 2>/dev/null
}

# Handle Ctrl+C
trap 'echo ""; log_event ""; log_event "監視を中断しました"; print_info "ログファイル: $LOG_FILE"; exit 0' INT

main
