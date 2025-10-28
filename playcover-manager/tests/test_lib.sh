#!/bin/bash
#
# PlayCover Manager - Test Library
# File: tests/test_lib.sh
# Description: Common test functions and utilities
# Version: 5.0.0-alpha1
#

# Test counters
TEST_TOTAL=0
TEST_PASSED=0
TEST_FAILED=0

# Color codes
COLOR_GREEN="\033[1;32m"
COLOR_RED="\033[1;31m"
COLOR_YELLOW="\033[1;33m"
COLOR_BLUE="\033[1;34m"
COLOR_RESET="\033[0m"

#######################################################
# Test Framework Functions
#######################################################

# Start a test suite
test_suite_start() {
    local suite_name="$1"
    echo ""
    echo -e "${COLOR_BLUE}════════════════════════════════════════════════════${COLOR_RESET}"
    echo -e "${COLOR_BLUE}  Test Suite: ${suite_name}${COLOR_RESET}"
    echo -e "${COLOR_BLUE}════════════════════════════════════════════════════${COLOR_RESET}"
    echo ""
    TEST_TOTAL=0
    TEST_PASSED=0
    TEST_FAILED=0
}

# End a test suite and show summary
test_suite_end() {
    echo ""
    echo -e "${COLOR_BLUE}────────────────────────────────────────────────────${COLOR_RESET}"
    echo -e "  Total:  ${TEST_TOTAL}"
    echo -e "  ${COLOR_GREEN}Passed: ${TEST_PASSED}${COLOR_RESET}"
    if [[ $TEST_FAILED -gt 0 ]]; then
        echo -e "  ${COLOR_RED}Failed: ${TEST_FAILED}${COLOR_RESET}"
    else
        echo -e "  ${COLOR_GREEN}Failed: ${TEST_FAILED}${COLOR_RESET}"
    fi
    echo -e "${COLOR_BLUE}════════════════════════════════════════════════════${COLOR_RESET}"
    echo ""
    
    # Return non-zero if any tests failed
    return $TEST_FAILED
}

# Assert that a condition is true
assert_true() {
    local condition="$1"
    local message="$2"
    
    ((TEST_TOTAL++))
    
    if eval "$condition"; then
        ((TEST_PASSED++))
        echo -e "${COLOR_GREEN}✅ PASS${COLOR_RESET}: $message"
        return 0
    else
        ((TEST_FAILED++))
        echo -e "${COLOR_RED}❌ FAIL${COLOR_RESET}: $message"
        echo -e "   Condition: $condition"
        return 1
    fi
}

# Assert that a condition is false
assert_false() {
    local condition="$1"
    local message="$2"
    
    ((TEST_TOTAL++))
    
    if ! eval "$condition"; then
        ((TEST_PASSED++))
        echo -e "${COLOR_GREEN}✅ PASS${COLOR_RESET}: $message"
        return 0
    else
        ((TEST_FAILED++))
        echo -e "${COLOR_RED}❌ FAIL${COLOR_RESET}: $message"
        echo -e "   Condition should be false: $condition"
        return 1
    fi
}

# Assert that two strings are equal
assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="$3"
    
    ((TEST_TOTAL++))
    
    if [[ "$expected" == "$actual" ]]; then
        ((TEST_PASSED++))
        echo -e "${COLOR_GREEN}✅ PASS${COLOR_RESET}: $message"
        return 0
    else
        ((TEST_FAILED++))
        echo -e "${COLOR_RED}❌ FAIL${COLOR_RESET}: $message"
        echo -e "   Expected: '$expected'"
        echo -e "   Actual:   '$actual'"
        return 1
    fi
}

# Assert that a file exists
assert_file_exists() {
    local file="$1"
    local message="${2:-File should exist: $file}"
    
    assert_true "[[ -f '$file' ]]" "$message"
}

# Assert that a file does not exist
assert_file_not_exists() {
    local file="$1"
    local message="${2:-File should not exist: $file}"
    
    assert_false "[[ -f '$file' ]]" "$message"
}

# Assert that a command succeeds (exit code 0)
assert_success() {
    local command="$1"
    local message="$2"
    
    ((TEST_TOTAL++))
    
    if eval "$command" >/dev/null 2>&1; then
        ((TEST_PASSED++))
        echo -e "${COLOR_GREEN}✅ PASS${COLOR_RESET}: $message"
        return 0
    else
        ((TEST_FAILED++))
        echo -e "${COLOR_RED}❌ FAIL${COLOR_RESET}: $message"
        echo -e "   Command should succeed: $command"
        return 1
    fi
}

# Assert that a command fails (exit code non-zero)
assert_failure() {
    local command="$1"
    local message="$2"
    
    ((TEST_TOTAL++))
    
    if ! eval "$command" >/dev/null 2>&1; then
        ((TEST_PASSED++))
        echo -e "${COLOR_GREEN}✅ PASS${COLOR_RESET}: $message"
        return 0
    else
        ((TEST_FAILED++))
        echo -e "${COLOR_RED}❌ FAIL${COLOR_RESET}: $message"
        echo -e "   Command should fail: $command"
        return 1
    fi
}

# Print a test section header
test_section() {
    local section_name="$1"
    echo ""
    echo -e "${COLOR_YELLOW}▶ ${section_name}${COLOR_RESET}"
    echo ""
}

# Setup function (can be overridden)
test_setup() {
    :
}

# Teardown function (can be overridden)
test_teardown() {
    :
}

#######################################################
# Helper Functions
#######################################################

# Create a temporary test file
create_temp_file() {
    local prefix="${1:-test}"
    mktemp "/tmp/${prefix}_XXXXXX"
}

# Create a temporary test directory
create_temp_dir() {
    local prefix="${1:-test}"
    mktemp -d "/tmp/${prefix}_XXXXXX"
}

# Cleanup temporary files
cleanup_temp_files() {
    local pattern="${1:-/tmp/test_*}"
    rm -rf $pattern 2>/dev/null || true
}
