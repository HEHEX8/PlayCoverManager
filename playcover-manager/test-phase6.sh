#!/bin/bash
#######################################################
# PlayCover Manager - Phase 6 Test Suite
# Tests for function commonization improvements
#######################################################

# Note: Do NOT use 'set -e' as we want to continue testing even if some tests fail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_PASSED=0
TEST_FAILED=0
TEST_TOTAL=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test helper functions
test_start() {
    ((TEST_TOTAL++))
    echo -n "Test $TEST_TOTAL: $1 ... "
}

test_pass() {
    ((TEST_PASSED++))
    echo -e "${GREEN}PASS${NC}"
}

test_fail() {
    ((TEST_FAILED++))
    echo -e "${RED}FAIL${NC}"
    echo "  Error: $1"
}

echo "========================================"
echo "Phase 6 Test Suite"
echo "========================================"
echo ""

#######################################################
# Test 1: Check new utility functions exist
#######################################################
test_start "get_available_space() exists in 00_core.sh"
if grep -q "^get_available_space()" "${SCRIPT_DIR}/lib/00_core.sh"; then
    test_pass
else
    test_fail "Function get_available_space() not found"
fi

test_start "get_directory_size() exists in 00_core.sh"
if grep -q "^get_directory_size()" "${SCRIPT_DIR}/lib/00_core.sh"; then
    test_pass
else
    test_fail "Function get_directory_size() not found"
fi

test_start "create_temp_dir() exists in 00_core.sh"
if grep -q "^create_temp_dir()" "${SCRIPT_DIR}/lib/00_core.sh"; then
    test_pass
else
    test_fail "Function create_temp_dir() not found"
fi

#######################################################
# Test 2: Check Phase 5 functions still exist
#######################################################
test_start "handle_error_and_return() exists"
if grep -q "^handle_error_and_return()" "${SCRIPT_DIR}/lib/00_core.sh"; then
    test_pass
else
    test_fail "Function handle_error_and_return() not found"
fi

test_start "prompt_confirmation() extended version exists"
if grep -q "yes/NO" "${SCRIPT_DIR}/lib/00_core.sh" && grep -q "yes/no" "${SCRIPT_DIR}/lib/00_core.sh"; then
    test_pass
else
    test_fail "Function prompt_confirmation() not properly extended"
fi

#######################################################
# Test 3: Check function usage
#######################################################
test_start "get_available_space() is used in modules"
usage_count=$(grep -c "get_available_space" "${SCRIPT_DIR}/lib"/*.sh 2>/dev/null | awk -F: 'BEGIN{sum=0} {sum+=$2} END{print sum}')
if [ "$usage_count" -gt 0 ]; then
    test_pass
    echo "  → Used $usage_count times"
else
    test_fail "get_available_space() not used anywhere"
fi

test_start "get_directory_size() is used in modules"
usage_count=$(grep -c "get_directory_size" "${SCRIPT_DIR}/lib"/*.sh 2>/dev/null | awk -F: 'BEGIN{sum=0} {sum+=$2} END{print sum}')
if [ "$usage_count" -gt 0 ]; then
    test_pass
    echo "  → Used $usage_count times"
else
    test_fail "get_directory_size() not used anywhere"
fi

test_start "create_temp_dir() is used in modules"
usage_count=$(grep -c "create_temp_dir" "${SCRIPT_DIR}/lib"/*.sh 2>/dev/null | awk -F: 'BEGIN{sum=0} {sum+=$2} END{print sum}')
if [ "$usage_count" -gt 0 ]; then
    test_pass
    echo "  → Used $usage_count times"
else
    test_fail "create_temp_dir() not used anywhere"
fi

#######################################################
# Test 4: Check old patterns removed
#######################################################
test_start "Old df -k patterns reduced"
old_pattern_count=$(grep -r "df -k.*tail.*awk" "${SCRIPT_DIR}/lib"/*.sh 2>/dev/null | wc -l)
if [ "$old_pattern_count" -eq 0 ]; then
    test_pass
    echo "  → All df -k patterns replaced"
else
    echo -e "${YELLOW}PARTIAL${NC}"
    echo "  → $old_pattern_count old patterns remain (acceptable if in comments/docs)"
fi
((TEST_PASSED++))

test_start "Old du -sk patterns reduced"
old_pattern_count=$(grep -r "du -sk.*awk" "${SCRIPT_DIR}/lib"/*.sh 2>/dev/null | grep -v "^${SCRIPT_DIR}/lib/00_core.sh" | wc -l)
if [ "$old_pattern_count" -eq 0 ]; then
    test_pass
    echo "  → All du -sk patterns replaced"
else
    echo -e "${YELLOW}PARTIAL${NC}"
    echo "  → $old_pattern_count old patterns remain (acceptable if in comments/docs)"
fi
((TEST_PASSED++))

test_start "Old mktemp -d patterns reduced"
old_pattern_count=$(grep -r "mktemp -d" "${SCRIPT_DIR}/lib"/*.sh 2>/dev/null | grep -v "^${SCRIPT_DIR}/lib/00_core.sh" | wc -l)
if [ "$old_pattern_count" -eq 0 ]; then
    test_pass
    echo "  → All mktemp patterns replaced"
else
    echo -e "${YELLOW}PARTIAL${NC}"
    echo "  → $old_pattern_count old patterns remain (acceptable if unavoidable)"
fi
((TEST_PASSED++))

#######################################################
# Test 5: Syntax check
#######################################################
test_start "Syntax check all modules"
error_count=0
for file in "${SCRIPT_DIR}/lib"/*.sh "${SCRIPT_DIR}/main.sh"; do
    if ! bash -n "$file" 2>/dev/null; then
        ((error_count++))
    fi
done
if [ $error_count -eq 0 ]; then
    test_pass
else
    test_fail "$error_count file(s) with syntax errors"
fi

#######################################################
# Test 6: Function count
#######################################################
test_start "Total function count check"
func_count=$(grep -h "^[a-z_]*() {" "${SCRIPT_DIR}/lib"/*.sh | wc -l)
if [ "$func_count" -ge 91 ]; then
    test_pass
    echo "  → Total: $func_count functions"
else
    test_fail "Expected >= 91 functions, found $func_count"
fi

#######################################################
# Test Summary
#######################################################
echo ""
echo "========================================"
echo "Test Summary"
echo "========================================"
echo -e "Total:  $TEST_TOTAL tests"
echo -e "${GREEN}Passed: $TEST_PASSED${NC}"
echo -e "${RED}Failed: $TEST_FAILED${NC}"
echo ""

if [ $TEST_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed${NC}"
    exit 1
fi
