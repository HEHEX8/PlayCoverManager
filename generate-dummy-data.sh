#!/bin/zsh
#######################################################
# PlayCover Manager - Dummy Data Generator
# クイックランチャー表示検証用のダミーデータ生成
#######################################################

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
readonly PLAYCOVER_BUNDLE_ID="io.playcover.PlayCover"
readonly PLAYCOVER_APPS_DIR="${HOME}/Library/Containers/${PLAYCOVER_BUNDLE_ID}/Applications"
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
    : > "$MAPPING_FILE"
    
    # Generate apps
    for ((i=1; i<=count; i++)); do
        local app_name="DummyApp${i}"
        local bundle_id="com.dummy.app${i}"
        
        # All apps use internal storage mode for simplicity
        local volume_name="internal"
        
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
        
        # Create container directory with .internal_storage marker
        # get_container_path() returns: ${HOME}/Library/Containers/${bundle_id}
        local container_path="${HOME}/Library/Containers/${bundle_id}"
        mkdir -p "$container_path"
        touch "${container_path}/.internal_storage"
        
        # Create dummy executable
        {
            echo '#!/bin/zsh'
            echo 'echo "Dummy app launched: $0"'
            echo 'sleep 1'
        } > "${app_path}/Contents/MacOS/${app_name}"
        chmod +x "${app_path}/Contents/MacOS/${app_name}"
        
        # Create Info.plist at ROOT of .app bundle (NOT in Contents/)
        # This is where get_bundle_id_from_app() looks for it
        {
            echo '<?xml version="1.0" encoding="UTF-8"?>'
            echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">'
            echo '<plist version="1.0">'
            echo '<dict>'
            echo '    <key>CFBundleIdentifier</key>'
            echo "    <string>${bundle_id}</string>"
            echo '    <key>CFBundleName</key>'
            echo "    <string>${app_name}</string>"
            echo '    <key>CFBundleExecutable</key>'
            echo "    <string>${app_name}</string>"
            echo '    <key>CFBundlePackageType</key>'
            echo '    <string>APPL</string>'
            echo '    <key>CFBundleVersion</key>'
            echo '    <string>1.0</string>'
            echo '    <key>CFBundleShortVersionString</key>'
            echo '    <string>1.0</string>'
            echo '</dict>'
            echo '</plist>'
        } > "${app_path}/Info.plist"
        
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
    echo "  📄 recent ファイル: ${RECENT_FILE}"
    echo "  📁 アプリディレクトリ: ${PLAYCOVER_APPS_DIR}"
    echo "  📦 コンテナディレクトリ: ${HOME}/Library/Containers/com.dummy.app*"
    echo ""
    
    # Verification
    local mapping_count=$(wc -l < "$MAPPING_FILE" | xargs)
    local app_count=$(find "$PLAYCOVER_APPS_DIR" -name "DummyApp*.app" -maxdepth 1 2>/dev/null | wc -l | xargs)
    local container_count=$(find "${HOME}/Library/Containers" -name ".internal_storage" -path "*/com.dummy.app*/.internal_storage" 2>/dev/null | wc -l | xargs)
    
    echo "  ✓ マッピングエントリ: ${mapping_count}"
    echo "  ✓ .app バンドル: ${app_count}"
    echo "  ✓ コンテナ (.internal_storage): ${container_count}"
    echo ""
    
    if [[ "$mapping_count" -eq "$app_count" ]] && [[ "$app_count" -eq "$container_count" ]]; then
        print_success "検証完了: すべてのコンポーネントが正常に生成されました"
    else
        print_warning "警告: コンポーネント数が一致しません（動作に影響する可能性）"
    fi
    echo ""
    
    print_info "PlayCover Manager を起動してクイックランチャーを確認してください"
    echo ""
    print_warning "元に戻すには:"
    echo "  mv ${MAPPING_FILE}${BACKUP_SUFFIX} ${MAPPING_FILE}"
    echo "  rm -rf ${PLAYCOVER_APPS_DIR}/DummyApp*.app"
    echo "  rm -rf ${HOME}/Library/Containers/com.dummy.app*"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Run main function
main "$@"
