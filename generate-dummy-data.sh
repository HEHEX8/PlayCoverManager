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
readonly BACKUP_SUFFIX=".backup.$(date +%Y%m%d_%H%M%S)"

# Sample app names (various genres and origins)
SAMPLE_APPS=(
    "崩壊：スターレイル"
    "原神"
    "ゼンレスゾーンゼロ"
    "アークナイツ"
    "ブルーアーカイブ"
    "ウマ娘 プリティーダービー"
    "プロジェクトセカイ"
    "モンスターストライク"
    "パズル＆ドラゴンズ"
    "Fate/Grand Order"
    "NIKKE"
    "勝利の女神：NIKKE"
    "Call of Duty Mobile"
    "PUBG Mobile"
    "Mobile Legends"
    "League of Legends: Wild Rift"
    "Asphalt 9"
    "Real Racing 3"
    "Among Us"
    "Minecraft"
)

# Sample bundle IDs
SAMPLE_BUNDLE_IDS=(
    "com.miHoYo.StarRail"
    "com.miHoYo.GenshinImpact"
    "com.miHoYo.ZZZ"
    "com.hypergryph.arknights"
    "com.YostarJP.BlueArchive"
    "jp.co.cygames.umamusume"
    "com.sega.pjsekai"
    "jp.co.mixi.monsterstrike"
    "jp.gungho.pad"
    "com.aniplex.fategrandorder"
    "com.proximabeta.nikke"
    "com.shiftup.nikke"
    "com.activision.callofduty.shooter"
    "com.tencent.ig"
    "com.moonton.mobilelegends"
    "com.riotgames.league.wildrift"
    "com.gameloft.asphalt9"
    "com.ea.realracing3"
    "com.innersloth.amongus"
    "com.mojang.minecraft"
)

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

# Generate dummy mapping file
generate_mapping_file() {
    local count=$1
    
    echo "DEBUG: 関数内に入りました count=$count" >&2
    
    print_info "ダミーマッピングファイルを生成中... (${count}アプリ)"
    echo "DEBUG: print_info完了" >&2
    
    # Ensure data directory exists
    mkdir -p "$DATA_DIR"
    echo "DEBUG: mkdir完了" >&2
    
    # Clear existing mapping file
    > "$MAPPING_FILE"
    echo "DEBUG: ファイルクリア完了" >&2
    
    # Generate entries
    # zsh: ${#array} で要素数取得（@は不要）
    echo "DEBUG: SAMPLE_APPS size = ${#SAMPLE_APPS}" >&2
    echo "DEBUG: First element = ${SAMPLE_APPS[1]}" >&2
    
    local total_samples=${#SAMPLE_APPS}
    echo "DEBUG: total_samples=$total_samples" >&2
    
    if [[ $total_samples -eq 0 ]]; then
        print_error "配列が空です！"
        return 1
    fi
    
    for ((i=1; i<=count; i++)); do
        local app_index=$(( ((i - 1) % total_samples) + 1 ))
        local app_name="${SAMPLE_APPS[$app_index]}"
        local bundle_id="${SAMPLE_BUNDLE_IDS[$app_index]}"
        
        print_info "DEBUG: i=$i, app_index=$app_index, app_name=$app_name"  # デバッグ用
        
        # Add number suffix if more than available samples
        if [[ $i -gt $total_samples ]]; then
            local suffix=$(( (i - 1) / total_samples + 1 ))
            app_name="${app_name} ${suffix}"
            bundle_id="${bundle_id}.dummy${suffix}"
        fi
        
        # Volume name: app1-7 = PlayCover, app8-14 = internal, app15+ = PlayCover
        local volume_name="PlayCover"
        if [[ $i -ge 8 && $i -le 14 ]]; then
            volume_name="internal"
        fi
        
        # Recent flag: only first app
        local recent_flag=""
        if [[ $i -eq 1 ]]; then
            recent_flag="recent"
        fi
        
        # Write to mapping file (tab-separated)
        printf "%s\t%s\t%s\t%s\n" "$volume_name" "$bundle_id" "$app_name" "$recent_flag" >> "$MAPPING_FILE"
    done
    
    print_success "マッピングファイル生成完了: $count エントリ"
}

# Generate recent app file
generate_recent_file() {
    print_info "recentファイルを生成中..."
    
    # Set first app as recent
    local bundle_id="${SAMPLE_BUNDLE_IDS[1]}"
    echo "$bundle_id" > "$RECENT_FILE"
    
    print_success "recentファイル生成完了: $bundle_id"
}

# Create dummy app structure (optional - for advanced testing)
create_dummy_app_structure() {
    local count=$1
    local create_structure=$2
    
    if [[ "$create_structure" != "yes" ]]; then
        return
    fi
    
    print_info "ダミーアプリ構造を生成中... (時間がかかります)"
    
    local playcover_apps_dir="${HOME}/Library/Containers/io.playcover.PlayCover/Applications"
    mkdir -p "$playcover_apps_dir"
    
    # zsh: ${#array} で要素数取得（@は不要）
    local total_samples=${#SAMPLE_APPS}
    
    for ((i=1; i<=count; i++)); do
        local app_index=$(( ((i - 1) % total_samples) + 1 ))
        local app_name="${SAMPLE_APPS[$app_index]}"
        local bundle_id="${SAMPLE_BUNDLE_IDS[$app_index]}"
        
        if [[ $i -gt $total_samples ]]; then
            local suffix=$(( (i - 1) / total_samples + 1 ))
            app_name="${app_name} ${suffix}"
            bundle_id="${bundle_id}.dummy${suffix}"
        fi
        
        # Create .app bundle
        local app_path="${playcover_apps_dir}/${app_name}.app"
        mkdir -p "${app_path}/Contents/MacOS"
        
        # Create dummy executable
        touch "${app_path}/Contents/MacOS/${app_name}"
        chmod +x "${app_path}/Contents/MacOS/${app_name}"
        
        # Create Info.plist
        cat > "${app_path}/Contents/Info.plist" << EOF
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
</dict>
</plist>
EOF
    done
    
    print_success "ダミーアプリ構造生成完了"
}

# Main
main() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  PlayCover Manager - Dummy Data Generator${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Get app count
    local app_count=20
    if [[ -n "$1" ]] && [[ "$1" =~ ^[0-9]+$ ]]; then
        app_count=$1
    fi
    
    print_info "生成するアプリ数: ${app_count}"
    echo ""
    
    # Confirm
    print_warning "既存のデータはバックアップされますが、上書きされます"
    printf "続行しますか? [y/N]: "
    read confirm
    
    if [[ ! "$confirm" =~ ^[yY]$ ]]; then
        print_info "キャンセルしました"
        exit 0
    fi
    
    echo ""
    
    # Backup
    backup_files
    echo ""
    
    # Generate data
    echo "DEBUG: generate_mapping_file を呼び出します (count=$app_count)" >&2
    generate_mapping_file "$app_count"
    echo "DEBUG: generate_mapping_file 完了" >&2
    
    generate_recent_file
    echo ""
    
    # Optional: Create app structure
    printf "ダミーアプリ構造も作成しますか? (時間がかかります) [y/N]: "
    read create_structure
    
    if [[ "$create_structure" =~ ^[yY]$ ]]; then
        echo ""
        create_dummy_app_structure "$app_count" "yes"
        echo ""
    fi
    
    # Summary
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    print_success "ダミーデータ生成完了！"
    echo ""
    echo "  📄 マッピングファイル: ${MAPPING_FILE}"
    echo "  📄 recentファイル: ${RECENT_FILE}"
    echo ""
    print_info "PlayCover Manager を起動してクイックランチャーを確認してください"
    echo ""
    print_warning "元に戻すには:"
    echo "  mv ${MAPPING_FILE}${BACKUP_SUFFIX} ${MAPPING_FILE}"
    echo "  mv ${RECENT_FILE}${BACKUP_SUFFIX} ${RECENT_FILE}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Run
main "$@"
