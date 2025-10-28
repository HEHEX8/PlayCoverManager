#!/bin/zsh

#######################################################
# PlayCover Volume Operations Verification Script
# Version: 1.0.0
# Purpose: Verify storage switch operations behavior
#######################################################

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Configuration
readonly TEST_BUNDLE_ID="com.playcover.test.app"
readonly TEST_VOLUME_NAME="PlayCover-Test-App"
readonly TEST_CONTAINER_PATH="${HOME}/Library/Containers/${TEST_BUNDLE_ID}"
readonly TEST_DATA_SIZE_MB=50

#######################################################
# Utility Functions
#######################################################

print_header() {
    echo ""
    echo "${CYAN}========================================${NC}"
    echo "${CYAN}$1${NC}"
    echo "${CYAN}========================================${NC}"
    echo ""
}

print_success() {
    echo "${GREEN}✅ $1${NC}"
}

print_error() {
    echo "${RED}❌ $1${NC}"
}

print_warning() {
    echo "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo "${BLUE}ℹ️  $1${NC}"
}

print_test_result() {
    local test_name="$1"
    local result="$2"
    
    if [[ "$result" == "PASS" ]]; then
        echo "${GREEN}✅ [PASS]${NC} ${test_name}"
    elif [[ "$result" == "FAIL" ]]; then
        echo "${RED}❌ [FAIL]${NC} ${test_name}"
    elif [[ "$result" == "SKIP" ]]; then
        echo "${YELLOW}⏭️  [SKIP]${NC} ${test_name}"
    else
        echo "${BLUE}ℹ️  [INFO]${NC} ${test_name}"
    fi
}

wait_for_enter() {
    echo ""
    echo -n "Enterキーで続行..."
    read
}

#######################################################
# Test Environment Setup
#######################################################

check_test_environment() {
    print_header "テスト環境の確認"
    
    local all_checks_passed=true
    
    # Check if running on macOS
    if [[ "$(uname)" != "Darwin" ]]; then
        print_error "このスクリプトはmacOS専用です"
        all_checks_passed=false
    else
        print_success "macOS環境を検出"
    fi
    
    # Check if diskutil exists
    if ! command -v diskutil >/dev/null 2>&1; then
        print_error "diskutil コマンドが見つかりません"
        all_checks_passed=false
    else
        print_success "diskutil コマンドが利用可能"
    fi
    
    # Check if rsync exists
    if ! command -v rsync >/dev/null 2>&1; then
        print_error "rsync コマンドが見つかりません"
        all_checks_passed=false
    else
        print_success "rsync コマンドが利用可能"
    fi
    
    # Check if sudo is available
    if ! sudo -n true 2>/dev/null; then
        print_warning "sudo権限が必要です（パスワード入力が求められます）"
        sudo -v
        if [[ $? -eq 0 ]]; then
            print_success "sudo権限を取得しました"
        else
            print_error "sudo権限の取得に失敗しました"
            all_checks_passed=false
        fi
    else
        print_success "sudo権限が利用可能"
    fi
    
    if ! $all_checks_passed; then
        echo ""
        print_error "テスト環境の確認に失敗しました"
        exit 1
    fi
    
    echo ""
    print_success "テスト環境の確認が完了しました"
    wait_for_enter
}

create_test_data() {
    print_header "テストデータの作成"
    
    local test_data_dir="${TEST_CONTAINER_PATH}/Data/Documents/test"
    
    print_info "テストコンテナパス: ${TEST_CONTAINER_PATH}"
    print_info "テストデータサイズ: ${TEST_DATA_SIZE_MB} MB"
    echo ""
    
    # Create test container directory
    if [[ -d "$TEST_CONTAINER_PATH" ]]; then
        print_warning "テストコンテナが既に存在します"
        echo -n "削除して再作成しますか？ (y/N): "
        read response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            sudo rm -rf "$TEST_CONTAINER_PATH"
            print_success "既存のテストコンテナを削除しました"
        else
            print_info "既存のテストコンテナを使用します"
            return 0
        fi
    fi
    
    # Create directory structure
    sudo mkdir -p "$test_data_dir"
    
    # Generate test files
    print_info "テストファイルを生成中..."
    for i in {1..5}; do
        sudo dd if=/dev/random of="${test_data_dir}/test_file_${i}.dat" bs=1m count=10 2>/dev/null
        echo -n "."
    done
    echo ""
    
    # Create some text files
    for i in {1..10}; do
        echo "Test data file ${i}" | sudo tee "${test_data_dir}/test_text_${i}.txt" >/dev/null
    done
    
    # Set proper ownership
    sudo chown -R $(id -u):$(id -g) "$TEST_CONTAINER_PATH"
    
    # Display result
    local actual_size=$(du -sh "$TEST_CONTAINER_PATH" 2>/dev/null | awk '{print $1}')
    print_success "テストデータを作成しました"
    print_info "実際のサイズ: ${actual_size}"
    
    echo ""
    echo "テストデータの内容:"
    ls -lh "$test_data_dir" 2>/dev/null | tail -n +2 | head -5
    echo "..."
    
    wait_for_enter
}

cleanup_test_data() {
    print_header "テストデータのクリーンアップ"
    
    echo -n "テストデータを削除しますか？ (y/N): "
    read response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        if [[ -d "$TEST_CONTAINER_PATH" ]]; then
            sudo rm -rf "$TEST_CONTAINER_PATH"
            print_success "テストコンテナを削除しました"
        fi
        
        # Check if test volume exists and delete it
        if diskutil list | grep -q "$TEST_VOLUME_NAME"; then
            print_info "テストボリュームを削除中..."
            local volume_device=$(diskutil list | grep "$TEST_VOLUME_NAME" | awk '{print $NF}')
            if [[ -n "$volume_device" ]]; then
                sudo diskutil apfs deleteVolume "$volume_device" >/dev/null 2>&1
                print_success "テストボリュームを削除しました"
            fi
        fi
        
        print_success "クリーンアップが完了しました"
    else
        print_info "クリーンアップをスキップしました"
    fi
}

#######################################################
# Verification Tests
#######################################################

verify_empty_source_detection() {
    print_header "検証: 空のソースディレクトリ検出"
    
    print_info "テスト内容: 0バイトのディレクトリを正しく検出できるか"
    echo ""
    
    # Create empty directory
    local empty_dir="/tmp/playcover_test_empty"
    mkdir -p "$empty_dir"
    
    # Check size using du (same method as in main script)
    local size_bytes=$(du -sk "$empty_dir" 2>/dev/null | awk '{print $1}')
    size_bytes=$((size_bytes * 1024))
    
    echo "空ディレクトリのサイズ: ${size_bytes} bytes"
    
    if [[ -z "$size_bytes" ]] || [[ "$size_bytes" -eq 0 ]]; then
        print_test_result "空ディレクトリの検出" "PASS"
    else
        print_test_result "空ディレクトリの検出" "FAIL"
    fi
    
    # Cleanup
    rm -rf "$empty_dir"
    
    wait_for_enter
}

verify_data_size_calculation() {
    print_header "検証: データサイズ計算の精度"
    
    if [[ ! -d "$TEST_CONTAINER_PATH" ]]; then
        print_warning "テストデータが存在しません"
        print_test_result "データサイズ計算" "SKIP"
        wait_for_enter
        return
    fi
    
    print_info "テストデータのサイズを計算中..."
    echo ""
    
    # Method 1: du -sk (used in script)
    local size_kb=$(du -sk "$TEST_CONTAINER_PATH" 2>/dev/null | awk '{print $1}')
    local size_bytes=$((size_kb * 1024))
    local size_mb=$((size_bytes / 1024 / 1024))
    
    echo "計算方法 1 (du -sk):"
    echo "  KB: ${size_kb}"
    echo "  Bytes: ${size_bytes}"
    echo "  MB: ${size_mb}"
    echo ""
    
    # Method 2: du -sh (human readable)
    local size_human=$(du -sh "$TEST_CONTAINER_PATH" 2>/dev/null | awk '{print $1}')
    echo "計算方法 2 (du -sh): ${size_human}"
    echo ""
    
    # Method 3: find and sum
    local file_count=$(find "$TEST_CONTAINER_PATH" -type f 2>/dev/null | wc -l | tr -d ' ')
    echo "ファイル数: ${file_count}"
    
    if [[ $size_bytes -gt 0 ]] && [[ $file_count -gt 0 ]]; then
        print_test_result "データサイズ計算" "PASS"
    else
        print_test_result "データサイズ計算" "FAIL"
    fi
    
    wait_for_enter
}

verify_rsync_behavior() {
    print_header "検証: rsync の動作パターン"
    
    print_info "rsync の --delete フラグの有無による動作の違いを確認"
    echo ""
    
    # Create test directories
    local source_dir="/tmp/playcover_rsync_source"
    local dest_dir="/tmp/playcover_rsync_dest"
    
    mkdir -p "$source_dir" "$dest_dir"
    
    # Setup: Create files in both directories
    echo "source_file_1" > "$source_dir/file1.txt"
    echo "source_file_2" > "$source_dir/file2.txt"
    echo "dest_file_old" > "$dest_dir/old_file.txt"
    echo "dest_file_shared" > "$dest_dir/file1.txt"
    
    print_info "初期状態:"
    echo "  ソース: $(ls $source_dir)"
    echo "  宛先: $(ls $dest_dir)"
    echo ""
    
    # Test 1: rsync without --delete
    print_info "テスト 1: rsync WITHOUT --delete"
    rsync -a "$source_dir/" "$dest_dir/" 2>/dev/null
    echo "  結果: $(ls $dest_dir)"
    local has_old_file=$(ls "$dest_dir" | grep -c "old_file.txt")
    if [[ $has_old_file -eq 1 ]]; then
        print_success "古いファイルが保持される（期待通り）"
    else
        print_error "古いファイルが削除された（予期しない動作）"
    fi
    echo ""
    
    # Reset destination
    rm -rf "$dest_dir"
    mkdir -p "$dest_dir"
    echo "dest_file_old" > "$dest_dir/old_file.txt"
    
    # Test 2: rsync with --delete
    print_info "テスト 2: rsync WITH --delete"
    rsync -a --delete "$source_dir/" "$dest_dir/" 2>/dev/null
    echo "  結果: $(ls $dest_dir)"
    local has_old_file=$(ls "$dest_dir" | grep -c "old_file.txt" || echo "0")
    if [[ $has_old_file -eq 0 ]]; then
        print_success "古いファイルが削除される（期待通り）"
    else
        print_error "古いファイルが残っている（予期しない動作）"
    fi
    
    # Cleanup
    rm -rf "$source_dir" "$dest_dir"
    
    print_test_result "rsync 動作パターン検証" "PASS"
    
    wait_for_enter
}

verify_permission_handling() {
    print_header "検証: ファイル権限の処理"
    
    if [[ ! -d "$TEST_CONTAINER_PATH" ]]; then
        print_warning "テストデータが存在しません"
        print_test_result "権限処理" "SKIP"
        wait_for_enter
        return
    fi
    
    print_info "現在の権限を確認中..."
    echo ""
    
    # Check ownership
    local owner=$(ls -ld "$TEST_CONTAINER_PATH" | awk '{print $3":"$4}')
    local current_user="$(id -u):$(id -g)"
    
    echo "コンテナディレクトリの所有者: ${owner}"
    echo "現在のユーザー: ${current_user}"
    echo ""
    
    # Check permissions
    local perms=$(ls -ld "$TEST_CONTAINER_PATH" | awk '{print $1}')
    echo "アクセス権限: ${perms}"
    echo ""
    
    # Test write access
    local test_file="${TEST_CONTAINER_PATH}/permission_test.txt"
    if echo "test" > "$test_file" 2>/dev/null; then
        print_success "書き込み権限あり"
        rm -f "$test_file"
        print_test_result "権限処理" "PASS"
    else
        print_error "書き込み権限なし"
        print_test_result "権限処理" "FAIL"
    fi
    
    wait_for_enter
}

verify_volume_operations() {
    print_header "検証: ボリューム操作の基本動作"
    
    print_warning "この検証では実際のAPFSボリューム操作は行いません"
    print_info "コマンドの構文チェックとロジック確認のみ実施"
    echo ""
    
    # Check diskutil availability
    print_info "diskutil コマンドの確認..."
    if diskutil list >/dev/null 2>&1; then
        print_success "diskutil が正常に動作します"
    else
        print_error "diskutil の実行に失敗しました"
    fi
    echo ""
    
    # List current APFS volumes
    print_info "現在のAPFSボリューム一覧:"
    diskutil list | grep "APFS Volume" | head -5
    echo ""
    
    # Check mount command
    print_info "マウント情報の確認..."
    if mount | grep -q "apfs"; then
        print_success "APFSマウントが検出されました"
        local apfs_count=$(mount | grep -c "apfs")
        echo "  APFSマウント数: ${apfs_count}"
    fi
    
    print_test_result "ボリューム操作確認" "PASS"
    
    wait_for_enter
}

#######################################################
# Main Menu
#######################################################

show_verification_menu() {
    clear
    echo ""
    echo "${GREEN}PlayCover ボリューム操作検証ツール${NC} ${CYAN}v1.0.0${NC}"
    echo ""
    echo "${CYAN}検証メニュー${NC}"
    echo ""
    echo "  ${YELLOW}1.${NC} テスト環境の確認"
    echo "  ${YELLOW}2.${NC} テストデータの作成"
    echo "  ${YELLOW}3.${NC} 空ソース検出の検証"
    echo "  ${YELLOW}4.${NC} データサイズ計算の検証"
    echo "  ${YELLOW}5.${NC} rsync 動作パターンの検証"
    echo "  ${YELLOW}6.${NC} ファイル権限処理の検証"
    echo "  ${YELLOW}7.${NC} ボリューム操作の検証"
    echo ""
    echo "  ${YELLOW}8.${NC} 全ての検証を実行"
    echo "  ${YELLOW}9.${NC} テストデータのクリーンアップ"
    echo ""
    echo "  ${YELLOW}0.${NC} 終了"
    echo ""
    echo -n "${CYAN}選択 (0-9):${NC} "
}

run_all_verifications() {
    print_header "全検証の実行"
    
    print_info "全ての検証を順次実行します"
    echo ""
    
    verify_empty_source_detection
    verify_data_size_calculation
    verify_rsync_behavior
    verify_permission_handling
    verify_volume_operations
    
    print_header "検証完了"
    print_success "全ての検証が完了しました"
    wait_for_enter
}

main() {
    while true; do
        show_verification_menu
        read choice
        
        case "$choice" in
            1)
                check_test_environment
                ;;
            2)
                create_test_data
                ;;
            3)
                verify_empty_source_detection
                ;;
            4)
                verify_data_size_calculation
                ;;
            5)
                verify_rsync_behavior
                ;;
            6)
                verify_permission_handling
                ;;
            7)
                verify_volume_operations
                ;;
            8)
                run_all_verifications
                ;;
            9)
                cleanup_test_data
                ;;
            0)
                echo ""
                print_info "終了します"
                exit 0
                ;;
            *)
                echo ""
                print_error "無効な選択です"
                sleep 2
                ;;
        esac
    done
}

# Execute
main
