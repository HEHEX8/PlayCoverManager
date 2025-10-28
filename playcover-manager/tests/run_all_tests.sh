#!/bin/bash
#
# PlayCover Manager - Run All Tests
# File: tests/run_all_tests.sh
# Description: Execute all test suites
# Version: 5.0.0-alpha1
#

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Color codes
COLOR_GREEN="\033[1;32m"
COLOR_RED="\033[1;31m"
COLOR_BLUE="\033[1;34m"
COLOR_CYAN="\033[1;36m"
COLOR_YELLOW="\033[1;33m"
COLOR_RESET="\033[0m"

# Test results
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0

#######################################################
# Helper Functions
#######################################################

run_test_suite() {
    local test_script="$1"
    local test_name="$(basename "$test_script")"
    
    ((TOTAL_SUITES++))
    
    echo ""
    echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    echo -e "${COLOR_CYAN}  Running: $test_name${COLOR_RESET}"
    echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    
    if bash "$test_script"; then
        ((PASSED_SUITES++))
        echo -e "${COLOR_GREEN}✅ $test_name: PASSED${COLOR_RESET}"
    else
        ((FAILED_SUITES++))
        echo -e "${COLOR_RED}❌ $test_name: FAILED${COLOR_RESET}"
    fi
}

print_summary() {
    echo ""
    echo ""
    echo -e "${COLOR_BLUE}╔════════════════════════════════════════════════════╗${COLOR_RESET}"
    echo -e "${COLOR_BLUE}║           TEST SUITE SUMMARY                       ║${COLOR_RESET}"
    echo -e "${COLOR_BLUE}╠════════════════════════════════════════════════════╣${COLOR_RESET}"
    echo -e "${COLOR_BLUE}║${COLOR_RESET}  Total Test Suites:  $TOTAL_SUITES                             ${COLOR_BLUE}║${COLOR_RESET}"
    
    if [[ $FAILED_SUITES -eq 0 ]]; then
        echo -e "${COLOR_BLUE}║${COLOR_RESET}  ${COLOR_GREEN}Passed:${COLOR_RESET}             $PASSED_SUITES                             ${COLOR_BLUE}║${COLOR_RESET}"
        echo -e "${COLOR_BLUE}║${COLOR_RESET}  ${COLOR_GREEN}Failed:${COLOR_RESET}             $FAILED_SUITES                             ${COLOR_BLUE}║${COLOR_RESET}"
    else
        echo -e "${COLOR_BLUE}║${COLOR_RESET}  ${COLOR_GREEN}Passed:${COLOR_RESET}             $PASSED_SUITES                             ${COLOR_BLUE}║${COLOR_RESET}"
        echo -e "${COLOR_BLUE}║${COLOR_RESET}  ${COLOR_RED}Failed:${COLOR_RESET}             $FAILED_SUITES                             ${COLOR_BLUE}║${COLOR_RESET}"
    fi
    
    echo -e "${COLOR_BLUE}╠════════════════════════════════════════════════════╣${COLOR_RESET}"
    
    if [[ $FAILED_SUITES -eq 0 ]]; then
        echo -e "${COLOR_BLUE}║${COLOR_RESET}  ${COLOR_GREEN}Status: ALL TESTS PASSED ✅${COLOR_RESET}                      ${COLOR_BLUE}║${COLOR_RESET}"
    else
        echo -e "${COLOR_BLUE}║${COLOR_RESET}  ${COLOR_RED}Status: SOME TESTS FAILED ❌${COLOR_RESET}                    ${COLOR_BLUE}║${COLOR_RESET}"
    fi
    
    echo -e "${COLOR_BLUE}╚════════════════════════════════════════════════════╝${COLOR_RESET}"
    echo ""
}

#######################################################
# Main
#######################################################

main() {
    echo ""
    echo -e "${COLOR_BLUE}╔════════════════════════════════════════════════════╗${COLOR_RESET}"
    echo -e "${COLOR_BLUE}║     PlayCover Manager - Test Suite Runner         ║${COLOR_RESET}"
    echo -e "${COLOR_BLUE}║     Version: 5.0.0-alpha1                          ║${COLOR_RESET}"
    echo -e "${COLOR_BLUE}╚════════════════════════════════════════════════════╝${COLOR_RESET}"
    echo ""
    
    # Find all test scripts
    local test_scripts=($(find "$SCRIPT_DIR" -name "test_*.sh" -type f | sort))
    
    if [[ ${#test_scripts[@]} -eq 0 ]]; then
        echo -e "${COLOR_RED}❌ No test scripts found!${COLOR_RESET}"
        exit 1
    fi
    
    echo -e "${COLOR_YELLOW}Found ${#test_scripts[@]} test suite(s)${COLOR_RESET}"
    
    # Run each test suite
    for test_script in "${test_scripts[@]}"; do
        run_test_suite "$test_script"
    done
    
    # Print summary
    print_summary
    
    # Exit with failure if any test failed
    if [[ $FAILED_SUITES -gt 0 ]]; then
        exit 1
    fi
    
    exit 0
}

main "$@"
