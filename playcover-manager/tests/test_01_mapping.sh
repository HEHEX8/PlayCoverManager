#!/bin/bash
#
# PlayCover Manager - Mapping Module Tests
# File: tests/test_01_mapping.sh
# Description: Test 01_mapping.sh functions
# Version: 5.0.0-alpha1
#

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load test library
source "$SCRIPT_DIR/test_lib.sh"

# Test configuration
TEST_MAPPING_FILE=""

#######################################################
# Setup and Teardown
#######################################################

test_setup() {
    # Create temporary mapping file
    TEST_MAPPING_FILE=$(create_temp_file "mapping")
    echo -e "VolumeName\tBundleID\tDisplayName" > "$TEST_MAPPING_FILE"
}

test_teardown() {
    # Cleanup
    rm -f "$TEST_MAPPING_FILE" 2>/dev/null || true
    cleanup_temp_files "mapping_*"
}

#######################################################
# Test Functions
#######################################################

test_mapping_file_creation() {
    test_section "Mapping File Creation"
    
    assert_file_exists "$TEST_MAPPING_FILE" \
        "Test mapping file should be created"
    
    local line_count=$(wc -l < "$TEST_MAPPING_FILE")
    assert_equals "1" "$line_count" \
        "Mapping file should have header line"
}

test_mapping_file_format() {
    test_section "Mapping File Format"
    
    # Add test entries
    echo -e "TestVol1\tcom.test.app1\tTest App 1" >> "$TEST_MAPPING_FILE"
    echo -e "TestVol2\tcom.test.app2\tテストアプリ2" >> "$TEST_MAPPING_FILE"
    
    # Check tab-separated format
    local has_tabs=$(grep -c $'\t' "$TEST_MAPPING_FILE")
    assert_true "[[ $has_tabs -ge 2 ]]" \
        "File should contain tab-separated values"
    
    # Check we can find entries
    assert_success "grep -q '^TestVol1' '$TEST_MAPPING_FILE'" \
        "Should find TestVol1 entry"
    
    assert_success "grep -q 'テストアプリ2' '$TEST_MAPPING_FILE'" \
        "Should handle Japanese characters"
}

test_mapping_add_operation() {
    test_section "Mapping Add Operation"
    
    # Add new mapping
    echo -e "NewVolume\tcom.new.app\tNew App" >> "$TEST_MAPPING_FILE"
    
    assert_success "grep -q '^NewVolume' '$TEST_MAPPING_FILE'" \
        "Should add new mapping"
    
    local line_count=$(wc -l < "$TEST_MAPPING_FILE")
    assert_equals "2" "$line_count" \
        "Should have 2 lines (header + 1 entry)"
}

test_mapping_search_operation() {
    test_section "Mapping Search Operation"
    
    # Add test data
    echo -e "SearchTest\tcom.search.app\tSearch App" >> "$TEST_MAPPING_FILE"
    
    # Search for volume
    local result=$(grep "^SearchTest" "$TEST_MAPPING_FILE" | cut -f3)
    assert_equals "Search App" "$result" \
        "Should find and extract display name"
    
    # Search for non-existent volume
    assert_failure "grep -q '^NonExistent' '$TEST_MAPPING_FILE'" \
        "Should not find non-existent volume"
}

test_mapping_remove_operation() {
    test_section "Mapping Remove Operation"
    
    # Add multiple entries
    echo -e "Keep1\tcom.keep1\tKeep 1" >> "$TEST_MAPPING_FILE"
    echo -e "Remove\tcom.remove\tRemove Me" >> "$TEST_MAPPING_FILE"
    echo -e "Keep2\tcom.keep2\tKeep 2" >> "$TEST_MAPPING_FILE"
    
    # Remove entry
    grep -v "^Remove" "$TEST_MAPPING_FILE" > "${TEST_MAPPING_FILE}.tmp"
    mv "${TEST_MAPPING_FILE}.tmp" "$TEST_MAPPING_FILE"
    
    # Verify removal
    assert_failure "grep -q '^Remove' '$TEST_MAPPING_FILE'" \
        "Removed entry should not exist"
    
    assert_success "grep -q '^Keep1' '$TEST_MAPPING_FILE'" \
        "Other entries should remain (Keep1)"
    
    assert_success "grep -q '^Keep2' '$TEST_MAPPING_FILE'" \
        "Other entries should remain (Keep2)"
}

test_mapping_empty_file() {
    test_section "Empty File Handling"
    
    local empty_file=$(create_temp_file "empty_mapping")
    
    assert_true "[[ ! -s '$empty_file' ]]" \
        "Empty file should have zero size"
    
    local line_count=$(wc -l < "$empty_file")
    assert_equals "0" "$line_count" \
        "Empty file should have 0 lines"
    
    rm -f "$empty_file"
}

test_mapping_readonly_file() {
    test_section "Read-Only File Handling"
    
    local readonly_file=$(create_temp_file "readonly_mapping")
    echo "test" > "$readonly_file"
    chmod 444 "$readonly_file"
    
    assert_false "[[ -w '$readonly_file' ]]" \
        "File should be read-only"
    
    assert_failure "echo 'new' >> '$readonly_file'" \
        "Writing to read-only file should fail"
    
    chmod 644 "$readonly_file"
    rm -f "$readonly_file"
}

#######################################################
# Main Test Runner
#######################################################

main() {
    test_suite_start "01_mapping.sh - Mapping Module Tests"
    
    test_setup
    test_mapping_file_creation
    test_teardown
    
    test_setup
    test_mapping_file_format
    test_teardown
    
    test_setup
    test_mapping_add_operation
    test_teardown
    
    test_setup
    test_mapping_search_operation
    test_teardown
    
    test_setup
    test_mapping_remove_operation
    test_teardown
    
    test_mapping_empty_file
    test_mapping_readonly_file
    
    test_suite_end
}

# Run tests
main
