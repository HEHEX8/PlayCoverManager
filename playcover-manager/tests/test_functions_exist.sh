#!/bin/bash
#
# PlayCover Manager - Function Existence Tests
# File: tests/test_functions_exist.sh
# Description: Verify all functions are defined
# Version: 5.0.0-alpha1
#

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load test library
source "$SCRIPT_DIR/test_lib.sh"

# Source all modules to check function existence
source "$PROJECT_DIR/lib/00_core.sh" 2>/dev/null
source "$PROJECT_DIR/lib/01_mapping.sh" 2>/dev/null
source "$PROJECT_DIR/lib/02_volume.sh" 2>/dev/null

#######################################################
# Test Functions
#######################################################

test_00_core_functions() {
    test_section "00_core.sh - Core Functions"
    
    assert_success "type print_success" \
        "print_success() should exist"
    
    assert_success "type print_error" \
        "print_error() should exist"
    
    assert_success "type print_warning" \
        "print_warning() should exist"
    
    assert_success "type print_info" \
        "print_info() should exist"
    
    assert_success "type print_separator" \
        "print_separator() should exist"
    
    assert_success "type authenticate_sudo" \
        "authenticate_sudo() should exist"
    
    assert_success "type check_full_disk_access" \
        "check_full_disk_access() should exist"
    
    assert_success "type is_playcover_environment_ready" \
        "is_playcover_environment_ready() should exist (Phase 3)"
}

test_01_mapping_functions() {
    test_section "01_mapping.sh - Mapping Functions"
    
    assert_success "type acquire_mapping_lock" \
        "acquire_mapping_lock() should exist"
    
    assert_success "type release_mapping_lock" \
        "release_mapping_lock() should exist"
    
    assert_success "type check_mapping_file" \
        "check_mapping_file() should exist"
    
    assert_success "type read_mappings" \
        "read_mappings() should exist"
    
    assert_success "type deduplicate_mappings" \
        "deduplicate_mappings() should exist"
    
    assert_success "type add_mapping" \
        "add_mapping() should exist"
    
    assert_success "type remove_mapping" \
        "remove_mapping() should exist"
    
    assert_success "type update_mapping" \
        "update_mapping() should exist"
}

test_02_volume_critical_functions() {
    test_section "02_volume.sh - CRITICAL Functions (Phase 3)"
    
    assert_success "type mount_volume" \
        "mount_volume() should exist (CRITICAL)"
    
    assert_success "type unmount_volume" \
        "unmount_volume() should exist (CRITICAL)"
    
    assert_success "type unmount_with_fallback" \
        "unmount_with_fallback() should exist (CRITICAL)"
    
    assert_success "type eject_disk" \
        "eject_disk() should exist (Phase 3)"
}

test_02_volume_other_functions() {
    test_section "02_volume.sh - Other Volume Functions"
    
    assert_success "type volume_exists" \
        "volume_exists() should exist"
    
    assert_success "type get_volume_device" \
        "get_volume_device() should exist"
    
    assert_success "type get_mount_point" \
        "get_mount_point() should exist"
    
    assert_success "type create_app_volume" \
        "create_app_volume() should exist"
    
    assert_success "type delete_app_volume" \
        "delete_app_volume() should exist"
    
    assert_success "type mount_app_volume" \
        "mount_app_volume() should exist"
    
    assert_success "type unmount_app_volume" \
        "unmount_app_volume() should exist"
}

test_module_files_exist() {
    test_section "Module Files Existence"
    
    assert_file_exists "$PROJECT_DIR/main.sh" \
        "main.sh should exist"
    
    assert_file_exists "$PROJECT_DIR/lib/00_core.sh" \
        "00_core.sh should exist"
    
    assert_file_exists "$PROJECT_DIR/lib/01_mapping.sh" \
        "01_mapping.sh should exist"
    
    assert_file_exists "$PROJECT_DIR/lib/02_volume.sh" \
        "02_volume.sh should exist"
    
    assert_file_exists "$PROJECT_DIR/lib/03_storage.sh" \
        "03_storage.sh should exist"
    
    assert_file_exists "$PROJECT_DIR/lib/04_app.sh" \
        "04_app.sh should exist"
    
    assert_file_exists "$PROJECT_DIR/lib/05_cleanup.sh" \
        "05_cleanup.sh should exist"
    
    assert_file_exists "$PROJECT_DIR/lib/06_setup.sh" \
        "06_setup.sh should exist"
    
    assert_file_exists "$PROJECT_DIR/lib/07_ui.sh" \
        "07_ui.sh should exist"
}

test_module_syntax() {
    test_section "Module Syntax Check"
    
    assert_success "bash -n '$PROJECT_DIR/main.sh'" \
        "main.sh syntax should be valid"
    
    assert_success "bash -n '$PROJECT_DIR/lib/00_core.sh'" \
        "00_core.sh syntax should be valid"
    
    assert_success "bash -n '$PROJECT_DIR/lib/01_mapping.sh'" \
        "01_mapping.sh syntax should be valid"
    
    assert_success "bash -n '$PROJECT_DIR/lib/02_volume.sh'" \
        "02_volume.sh syntax should be valid"
    
    assert_success "bash -n '$PROJECT_DIR/lib/03_storage.sh'" \
        "03_storage.sh syntax should be valid"
    
    assert_success "bash -n '$PROJECT_DIR/lib/04_app.sh'" \
        "04_app.sh syntax should be valid"
    
    assert_success "bash -n '$PROJECT_DIR/lib/05_cleanup.sh'" \
        "05_cleanup.sh syntax should be valid"
    
    assert_success "bash -n '$PROJECT_DIR/lib/06_setup.sh'" \
        "06_setup.sh syntax should be valid"
    
    assert_success "bash -n '$PROJECT_DIR/lib/07_ui.sh'" \
        "07_ui.sh syntax should be valid"
}

#######################################################
# Main Test Runner
#######################################################

main() {
    test_suite_start "Function Existence Tests - All Modules"
    
    test_module_files_exist
    test_module_syntax
    test_00_core_functions
    test_01_mapping_functions
    test_02_volume_critical_functions
    test_02_volume_other_functions
    
    test_suite_end
}

# Run tests
main
