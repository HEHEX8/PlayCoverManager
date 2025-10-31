#!/bin/zsh
#######################################################
# PlayCover Manager - Dummy Data Generator
# クイックランチャー表示検証用のダミーデータ生成
#######################################################

set -e

# Colors
readonly GREEN='\033[38;2;120;220;120m'
readonly YELLOW='\033[38;2;230;220;100m'
readonly RED='\033[38;2;255;120;120m'
readonly CYAN='\033[38;2;100;220;220m'
readonly NC='\033[0m'

# Paths
readonly SCRIPT_DIR="${0:A:h}"
readonly DATA_DIR="${HOME}/Library/Application Support/PlayCover Manager"
readonly MAPPING_FILE="${DATA_DIR}/mapping-file.txt"
readonly RECENT_FILE="${DATA_DIR}/recent-app"
readonly PLAYCOVER_APPS_DIR="${HOME}/Library/Containers/io.playcover.PlayCover/Applications"
readonly BACKUP_SUFFIX=".backup.$(date +%Y%m%d_%H%M%S)"

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Backup existing files
backup_files() {
    if [[ -f "$MAPPING_FILE" ]]; then
        cp "$MAPPING_FILE" "${MAPPING_FILE}${BACKUP_SUFFIX}"
        print_success "既存のマッピングファイルをバックアップ: ${MAPPING_FILE}${BACKUP_SUFFIX}"
    fi
    
    if [[ -f "$RECENT_FILE" ]]; then
        cp "$RECENT_FILE" "${RECENT_FILE}${BACKUP_SUFFIX}"
        print_success "既存のrecentファイルをバックアップ: ${RECENT_FILE}${BACKUP_SUFFIX}"
    fi
}

# Generate dummy data
generate_dummy_data() {
    local count=$1
    
    print_info "ダミーデータを生成中... (${count}アプリ)"
    
    # Ensure directories exist
    mkdir -p "$DATA_DIR"
    mkdir -p "$PLAYCOVER_APPS_DIR"
    
    # Clear mapping file
    > "$MAPPING_FILE"
    
    # Generate apps
    for ((i=1; i<=count; i++)); do
        local app_name="DummyApp${i}"
        local bundle_id="com.dummy.app${i}"
        
        # Volume determination (apps 8-14 are internal, others are external)
        local volume_name="PlayCover"
        if [[ $i -ge 8 && $i -le 14 ]]; then
            volume_name="internal"
        fi
        
        # Recent flag (first app only)
        local recent_flag=""
        if [[ $i -eq 1 ]]; then
            recent_flag="recent"
        fi
        
        # Write to mapping file (tab-separated)
        printf "%s\t%s\t%s\t%s\n" "$volume_name" "$bundle_id" "$app_name" "$recent_flag" >> "$MAPPING_FILE"
        
        # Create .app bundle structure
        local app_path="${PLAYCOVER_APPS_DIR}/${app_name}.app"
        mkdir -p "${app_path}/Contents/MacOS"
        
        # Create dummy executable
        cat > "${app_path}/Contents/MacOS/${app_name}" << 'EXEC_EOF'
#!/bin/zsh
echo "Dummy app launched: $0"
sleep 1
EXEC_EOF
        chmod +x "${app_path}/Contents/MacOS/${app_name}"
        
        # Create Info.plist with proper bundle identifier
        cat > "${app_path}/Contents/Info.plist" << PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>${bundle_id}</string>
    <key>CFBundleName</key>
    <string>${app_name}</string>
    <key>CFBundleExecutable</key>
    <string>${app_name}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
</dict>
</plist>
PLIST_EOF
        
        # Progress indicator
        printf "."
    done
    
    echo ""
    print_success "マッピングファイル生成完了: $count エントリ"
    print_success "ダミーアプリ構造生成完了: $count 個の .app バンドル"
    
    # Generate recent file
    echo "com.dummy.app1" > "$RECENT_FILE"
    print_success "recentファイル生成完了"
}

# Main
main() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  PlayCover Manager - Dummy Data Generator${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Get app count from argument or use default
    local app_count=20
    if [[ -n "$1" ]] && [[ "$1" =~ ^[0-9]+$ ]]; then
        app_count=$1
    fi
    
    print_info "生成するアプリ数: ${app_count}"
    echo ""
    
    # Confirm with user
    print_warning "既存のデータはバックアップされますが、上書きされます"
    printf "続行しますか? [y/N]: "
    read confirm
    
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then
        print_info "キャンセルしました"
        exit 0
    fi
    
    echo ""
    
    # Backup existing files
    backup_files
    echo ""
    
    # Generate dummy data
    generate_dummy_data "$app_count"
    echo ""
    
    # Summary
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    print_success "ダミーデータ生成完了！"
    echo ""
    echo "  📄 マッピングファイル: ${MAPPING_FILE}"
    echo "  📄 recentファイル: ${RECENT_FILE}"
    echo "  📁 アプリディレクトリ: ${PLAYCOVER_APPS_DIR}"
    echo ""
    print_info "PlayCover Manager を起動してクイックランチャーを確認してください"
    echo ""
    print_warning "元に戻すには:"
    echo "  mv ${MAPPING_FILE}${BACKUP_SUFFIX} ${MAPPING_FILE}"
    echo "  rm -rf ${PLAYCOVER_APPS_DIR}/DummyApp*.app"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Run main function
main "$@"
