#!/bin/bash
#######################################################
# Phase 8 Test Suite
# Volume operation unification validation
#######################################################

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/00_core.sh"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors for test output
TEST_PASS="${SUCCESS}"
TEST_FAIL="${ERROR}"
TEST_INFO="${INFO}"

#######################################################
# Test Helper Functions
#######################################################

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    echo -n "${TEST_INFO}Testing: ${test_name}${NC} ... "
    
    if eval "$test_command" >/dev/null 2>&1; then
        echo "${TEST_PASS}PASS${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo "${TEST_FAIL}FAIL${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

#######################################################
# Phase 8 Specific Tests
#######################################################

echo ""
echo "${HIGHLIGHT}========================================${NC}"
echo "${HIGHLIGHT}  Phase 8 Test Suite${NC}"
echo "${HIGHLIGHT}  Volume Operation Unification${NC}"
echo "${HIGHLIGHT}========================================${NC}"
echo ""

#######################################################
# 1. Verify get_volume_device_or_fail usage increased
#######################################################

echo "${HIGHLIGHT}[1] get_volume_device_or_fail Usage Tests${NC}"
echo ""

run_test "get_volume_device_or_fail exists in 00_core.sh" \
    "grep -q 'get_volume_device_or_fail()' '${SCRIPT_DIR}/lib/00_core.sh'"

run_test "get_volume_device_or_fail used in mount_app_volume" \
    "grep -q 'get_volume_device_or_fail.*mount_app_volume' '${SCRIPT_DIR}/lib/02_volume.sh' || \
     grep -A10 'mount_app_volume()' '${SCRIPT_DIR}/lib/02_volume.sh' | grep -q 'get_volume_device_or_fail'"

run_test "get_volume_device_or_fail used in delete_app_volume" \
    "grep -A10 'delete_app_volume()' '${SCRIPT_DIR}/lib/02_volume.sh' | grep -q 'get_volume_device_or_fail'"

run_test "get_volume_device_or_fail used in eject_disk" \
    "grep -A15 'eject_disk()' '${SCRIPT_DIR}/lib/02_volume.sh' | grep -q 'get_volume_device_or_fail'"

# Count usage (excluding function definition itself)
USAGE_COUNT=$(grep -rn "get_volume_device_or_fail" "${SCRIPT_DIR}/lib/" | grep -v "^.*:.*#" | grep -v "^.*:get_volume_device_or_fail()" | wc -l | tr -d ' ')
run_test "get_volume_device_or_fail used at least 4 times (was 1 in Phase 7)" \
    "[[ $USAGE_COUNT -ge 4 ]]"

echo ""

#######################################################
# 2. Verify old patterns are reduced
#######################################################

echo "${HIGHLIGHT}[2] Old Pattern Reduction Tests${NC}"
echo ""

# Pattern: Verify delete_app_volume kept intentional early-exit volume_exists check
# (This is correct design for early return on non-existent volumes)
DELETE_APP_EARLY_EXIT=$(grep -A6 "delete_app_volume()" "${SCRIPT_DIR}/lib/02_volume.sh" | \
    grep -c "if ! volume_exists")

run_test "delete_app_volume has intentional early-exit check (design choice)" \
    "[ $DELETE_APP_EARLY_EXIT -eq 1 ]"

# Pattern: volume_exists check followed by get_volume_device in mount_app_volume
run_test "mount_app_volume no longer has separate volume_exists check before device retrieval" \
    "! grep -A8 'mount_app_volume()' '${SCRIPT_DIR}/lib/02_volume.sh' | \
       grep -B2 'get_volume_device_or_fail' | grep -q 'if ! volume_exists'"

# Pattern: eject_disk simplified
run_test "eject_disk simplified (no nested if statements for device retrieval)" \
    "! grep -A15 'eject_disk()' '${SCRIPT_DIR}/lib/02_volume.sh' | \
       grep -A5 'volume_exists' | grep -q 'if \[\[ -n.*volume_device \]\]'"

echo ""

#######################################################
# 3. Verify Phase 7 functions still exist
#######################################################

echo "${HIGHLIGHT}[3] Phase 7 Function Persistence Tests${NC}"
echo ""

run_test "get_volume_mount_point still exists" \
    "grep -q '^get_volume_mount_point()' '${SCRIPT_DIR}/lib/00_core.sh'"

run_test "get_volume_device_node still exists" \
    "grep -q '^get_volume_device_node()' '${SCRIPT_DIR}/lib/00_core.sh'"

run_test "ensure_volume_mounted still exists" \
    "grep -q '^ensure_volume_mounted()' '${SCRIPT_DIR}/lib/00_core.sh'"

run_test "print_success_ln still exists" \
    "grep -q '^print_success_ln()' '${SCRIPT_DIR}/lib/00_core.sh'"

run_test "print_debug still exists" \
    "grep -q '^print_debug()' '${SCRIPT_DIR}/lib/00_core.sh'"

echo ""

#######################################################
# 4. Code Quality Tests
#######################################################

echo "${HIGHLIGHT}[4] Code Quality Tests${NC}"
echo ""

run_test "No syntax errors in 02_volume.sh" \
    "bash -n '${SCRIPT_DIR}/lib/02_volume.sh'"

run_test "No syntax errors in 00_core.sh" \
    "bash -n '${SCRIPT_DIR}/lib/00_core.sh'"

run_test "All modules load successfully" \
    "bash -c 'source \"${SCRIPT_DIR}/lib/00_core.sh\" && \
             source \"${SCRIPT_DIR}/lib/02_volume.sh\"'"

echo ""

#######################################################
# 5. Function Count Verification
#######################################################

echo "${HIGHLIGHT}[5] Function Count Tests${NC}"
echo ""

# Count functions in 00_core.sh (should still be 41 from Phase 7)
CORE_FUNC_COUNT=$(grep -c "() {" "${SCRIPT_DIR}/lib/00_core.sh")
run_test "00_core.sh still has 41 functions" \
    "test ${CORE_FUNC_COUNT} -eq 41"

# Total function count across all modules (should be 107 from Phase 7)
TOTAL_FUNC_COUNT=$(grep -h "() {" "${SCRIPT_DIR}/lib/"*.sh | wc -l | tr -d ' ')
run_test "Total function count is 107 (unchanged from Phase 7)" \
    "test ${TOTAL_FUNC_COUNT} -eq 107"

echo ""

#######################################################
# Test Summary
#######################################################

echo ""
echo "${HIGHLIGHT}========================================${NC}"
echo "${HIGHLIGHT}  Test Summary${NC}"
echo "${HIGHLIGHT}========================================${NC}"
echo ""
echo "Tests Run:    ${TESTS_RUN}"
echo "Tests Passed: ${TEST_PASS}${TESTS_PASSED}${NC}"
echo "Tests Failed: ${TEST_FAIL}${TESTS_FAILED}${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo "${TEST_PASS}✅ All tests passed!${NC}"
    echo ""
    exit 0
else
    echo "${TEST_FAIL}❌ Some tests failed!${NC}"
    echo ""
    exit 1
fi
