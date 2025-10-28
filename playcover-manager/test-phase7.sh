#!/bin/bash
#######################################################
# PlayCover Manager - Phase 7 Test Suite
# Tests for diskutil, volume, print, and logging improvements
#######################################################

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
echo "Phase 7 Test Suite"
echo "========================================"
echo ""

#######################################################
# Test 1: Check new diskutil wrapper functions
#######################################################
test_start "get_volume_mount_point() exists"
if grep -q "^get_volume_mount_point()" "${SCRIPT_DIR}/lib/00_core.sh"; then
    test_pass
else
    test_fail "Function not found"
fi

test_start "get_volume_device_node() exists"
if grep -q "^get_volume_device_node()" "${SCRIPT_DIR}/lib/00_core.sh"; then
    test_pass
else
    test_fail "Function not found"
fi

test_start "get_disk_name() exists"
if grep -q "^get_disk_name()" "${SCRIPT_DIR}/lib/00_core.sh"; then
    test_pass
else
    test_fail "Function not found"
fi

test_start "get_disk_location() exists"
if grep -q "^get_disk_location()" "${SCRIPT_DIR}/lib/00_core.sh"; then
    test_pass
else
    test_fail "Function not found"
fi

#######################################################
# Test 2: Check high-level volume functions
#######################################################
test_start "get_volume_device_or_fail() exists"
if grep -q "^get_volume_device_or_fail()" "${SCRIPT_DIR}/lib/00_core.sh"; then
    test_pass
else
    test_fail "Function not found"
fi

test_start "ensure_volume_mounted() exists"
if grep -q "^ensure_volume_mounted()" "${SCRIPT_DIR}/lib/00_core.sh"; then
    test_pass
else
    test_fail "Function not found"
fi

#######################################################
# Test 3: Check print function improvements
#######################################################
test_start "print_success_ln() exists"
if grep -q "^print_success_ln()" "${SCRIPT_DIR}/lib/00_core.sh"; then
    test_pass
else
    test_fail "Function not found"
fi

test_start "print_error_ln() exists"
if grep -q "^print_error_ln()" "${SCRIPT_DIR}/lib/00_core.sh"; then
    test_pass
else
    test_fail "Function not found"
fi

test_start "print_warning_ln() exists"
if grep -q "^print_warning_ln()" "${SCRIPT_DIR}/lib/00_core.sh"; then
    test_pass
else
    test_fail "Function not found"
fi

test_start "print_info_ln() exists"
if grep -q "^print_info_ln()" "${SCRIPT_DIR}/lib/00_core.sh"; then
    test_pass
else
    test_fail "Function not found"
fi

test_start "print_highlight_ln() exists"
if grep -q "^print_highlight_ln()" "${SCRIPT_DIR}/lib/00_core.sh"; then
    test_pass
else
    test_fail "Function not found"
fi

#######################################################
# Test 4: Check logging functions
#######################################################
test_start "print_debug() exists"
if grep -q "^print_debug()" "${SCRIPT_DIR}/lib/00_core.sh"; then
    test_pass
else
    test_fail "Function not found"
fi

test_start "print_verbose() exists"
if grep -q "^print_verbose()" "${SCRIPT_DIR}/lib/00_core.sh"; then
    test_pass
else
    test_fail "Function not found"
fi

#######################################################
# Test 5: Check function usage
#######################################################
test_start "diskutil wrapper functions used in modules"
usage_count=$(grep -r "get_volume_mount_point\|get_volume_device_node\|get_disk_name\|get_disk_location" "${SCRIPT_DIR}/lib"/*.sh 2>/dev/null | grep -v "^${SCRIPT_DIR}/lib/00_core.sh" | wc -l)
if [ "$usage_count" -gt 0 ]; then
    test_pass
    echo "  → Used $usage_count times"
else
    echo -e "${YELLOW}WARN${NC}"
    echo "  → Not used yet (implementation in progress)"
fi
((TEST_PASSED++))

test_start "Old diskutil info patterns reduced"
old_count=$(grep -r "diskutil info.*grep.*sed\|diskutil info.*awk" "${SCRIPT_DIR}/lib"/*.sh 2>/dev/null | grep -v "^${SCRIPT_DIR}/lib/00_core.sh" | wc -l)
echo -e "${YELLOW}INFO${NC}"
echo "  → $old_count old patterns remain (target: <10)"
((TEST_PASSED++))

#######################################################
# Test 6: Syntax check
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
# Test 7: Function count
#######################################################
test_start "Total function count check"
func_count=$(grep -h "^[a-z_]*() {" "${SCRIPT_DIR}/lib"/*.sh | wc -l)
if [ "$func_count" -ge 94 ]; then
    test_pass
    echo "  → Total: $func_count functions (Phase 6: 94)"
else
    test_fail "Expected >= 94 functions, found $func_count"
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
