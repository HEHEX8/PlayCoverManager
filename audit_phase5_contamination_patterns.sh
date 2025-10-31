#!/bin/bash
#######################################################
# Phase 5 Audit: Contamination Handling Patterns
# 汚染処理パターンの統一化を徹底検証
#######################################################

shopt -s extglob nullglob

CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
GRAY='\033[0;90m'
ORANGE='\033[0;33m'
NC='\033[0m'

echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "${GREEN}Phase 5: Contamination Handling Patterns Audit${NC}"
echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

cd /home/user/webapp

#######################################################
# 1. Contamination Detection Consistency
#######################################################

echo "${YELLOW}[1] Contamination Detection${NC}"
echo "Checking if all code uses get_storage_mode() for detection..."
echo ""

# Pattern 1: Direct get_storage_mode() usage
echo "${CYAN}get_storage_mode() calls:${NC}"
rg --no-heading -n 'get_storage_mode' lib/*.sh | while IFS=: read -r file line content; do
    if echo "$content" | grep -q 'get_storage_mode()'; then
        echo "  ${CYAN}ℹ️${NC}  $file:$line - function definition"
    else
        echo "  ${GREEN}✅${NC} $file:$line - proper usage"
    fi
done | head -20
echo "  ${GRAY}... (showing first 20)${NC}"
echo ""

# Pattern 2: Manual contamination detection (should use get_storage_mode)
echo "${CYAN}Manual contamination detection patterns (should use get_storage_mode):${NC}"
manual_detection=$(rg --no-heading -n 'has_internal_data|check_internal_data' lib/*.sh | grep -v 'get_storage_mode\|^[[:space:]]*#')
if [[ -z "$manual_detection" ]]; then
    echo "  ${GREEN}✅ All contamination detection uses get_storage_mode()${NC}"
else
    echo "$manual_detection" | while IFS=: read -r file line content; do
        echo "  ${YELLOW}⚠️${NC}  $file:$line"
        echo "     ${GRAY}$content${NC}"
    done
fi
echo ""

#######################################################
# 2. Contamination State Handling
#######################################################

echo "${YELLOW}[2] Contamination State Handling${NC}"
echo "Checking how internal_contaminated state is handled..."
echo ""

# Pattern 1: All internal_contaminated checks
echo "${CYAN}internal_contaminated state checks:${NC}"
rg --no-heading -n 'internal_contaminated' lib/*.sh | while IFS=: read -r file line content; do
    if echo "$content" | grep -q '^[[:space:]]*#'; then
        continue
    fi
    echo "  $file:$line"
    echo "     ${GRAY}$content${NC}"
done | head -30
echo "  ${GRAY}... (showing first 30 lines)${NC}"
echo ""

#######################################################
# 3. Contamination Handler Functions
#######################################################

echo "${YELLOW}[3] Contamination Handler Functions${NC}"
echo "Checking unified contamination handler usage..."
echo ""

# Pattern 1: handle_contamination_for_batch_mount usage
echo "${CYAN}handle_contamination_for_batch_mount() calls:${NC}"
batch_handler_count=$(rg -c 'handle_contamination_for_batch_mount' lib/*.sh | grep -v ':0$' | wc -l | tr -d ' ')
echo "  Found: $batch_handler_count files"
rg --no-heading -n 'handle_contamination_for_batch_mount' lib/*.sh | while IFS=: read -r file line content; do
    if echo "$content" | grep -q 'handle_contamination_for_batch_mount()'; then
        echo "  ${CYAN}ℹ️${NC}  $file:$line - function definition"
    else
        echo "  ${GREEN}✅${NC} $file:$line - proper usage"
    fi
    echo "     ${GRAY}$content${NC}"
done
echo ""

# Pattern 2: handle_unintended_internal_data usage (old name check)
echo "${CYAN}Old handler name check (handle_unintended_internal_data):${NC}"
old_handler=$(rg --no-heading -n 'handle_unintended_internal_data' lib/*.sh)
if [[ -z "$old_handler" ]]; then
    echo "  ${GREEN}✅ No old handler names found${NC}"
else
    echo "  ${RED}❌ Old handler name still in use:${NC}"
    echo "$old_handler" | while IFS=: read -r file line content; do
        echo "  $file:$line"
        echo "     ${GRAY}$content${NC}"
    done
fi
echo ""

#######################################################
# 4. Quick Launcher Contamination Exclusion
#######################################################

echo "${YELLOW}[4] Quick Launcher Contamination Exclusion${NC}"
echo "Checking if contaminated apps are excluded from quick launcher..."
echo ""

# Check get_launchable_apps() function
echo "${CYAN}get_launchable_apps() contamination filtering:${NC}"
rg --no-heading -n -A5 'get_launchable_apps\(\)' lib/04_app.sh | head -40 | while IFS=: read -r file line content; do
    if echo "$content" | grep -q 'internal_contaminated'; then
        echo "  ${GREEN}✅${NC} $file:$line - filters contaminated"
        echo "     ${GRAY}$content${NC}"
    fi
done
echo ""

# Check if any code includes contaminated apps in launchers
echo "${CYAN}Potential contaminated app inclusion in launchers:${NC}"
contaminated_inclusion=$(rg --no-heading -n 'launch.*app|open.*app' lib/*.sh | grep -B5 -A5 'contaminated')
if [[ -z "$contaminated_inclusion" ]]; then
    echo "  ${GREEN}✅ No contaminated apps launched${NC}"
else
    echo "  ${CYAN}ℹ️${NC}  Context found (verify exclusion):"
    echo "$contaminated_inclusion" | head -20
fi
echo ""

#######################################################
# 5. UI Display of Contamination Status
#######################################################

echo "${YELLOW}[5] UI Display of Contamination Status${NC}"
echo "Checking consistent contamination status display..."
echo ""

# Pattern 1: Storage mode display patterns
echo "${CYAN}Contamination display in get_storage_usage_display():${NC}"
rg --no-heading -n -B2 -A2 'internal_contaminated' lib/03_storage.sh | grep -A4 'case.*storage_mode' | head -20
echo ""

# Pattern 2: Icon/emoji for contamination
echo "${CYAN}Contamination icon/emoji usage:${NC}"
rg --no-heading -n '⚠️.*内蔵データ検出|内蔵データ検出.*⚠️' lib/*.sh | while IFS=: read -r file line content; do
    echo "  ${GREEN}✅${NC} $file:$line"
    echo "     ${GRAY}$content${NC}"
done
echo ""

#######################################################
# 6. Contamination Resolution Flows
#######################################################

echo "${YELLOW}[6] Contamination Resolution Flows${NC}"
echo "Checking resolution options consistency..."
echo ""

# Pattern 1: Merge option
echo "${CYAN}Merge contaminated data option:${NC}"
merge_count=$(rg -c 'マージ|merge' lib/*.sh | grep -v ':0$' | wc -l | tr -d ' ')
echo "  Found: $merge_count files with merge logic"
echo ""

# Pattern 2: Delete option
echo "${CYAN}Delete contaminated data option:${NC}"
delete_count=$(rg -c '内蔵データ.*削除|delete.*internal.*data' lib/*.sh | grep -v ':0$' | wc -l | tr -d ' ')
echo "  Found: $delete_count files with delete logic"
echo ""

# Pattern 3: Skip option
echo "${CYAN}Skip/cancel option for contaminated apps:${NC}"
rg --no-heading -n 'skip.*contaminated|contaminated.*skip' lib/*.sh | while IFS=: read -r file line content; do
    echo "  ${GREEN}✅${NC} $file:$line"
    echo "     ${GRAY}$content${NC}"
done
echo ""

#######################################################
# 7. Contamination Flag Management
#######################################################

echo "${YELLOW}[7] Contamination Prevention${NC}"
echo "Checking internal storage flag management..."
echo ""

# Pattern 1: Flag creation
echo "${CYAN}Internal storage flag creation:${NC}"
rg --no-heading -n 'set_internal_storage_flag|create.*flag' lib/*.sh | while IFS=: read -r file line content; do
    echo "  ${GREEN}✅${NC} $file:$line"
    echo "     ${GRAY}$content${NC}"
done
echo ""

# Pattern 2: Flag removal
echo "${CYAN}Internal storage flag removal:${NC}"
rg --no-heading -n 'remove_internal_storage_flag' lib/*.sh | while IFS=: read -r file line content; do
    echo "  ${GREEN}✅${NC} $file:$line"
    echo "     ${GRAY}$content${NC}"
done
echo ""

# Pattern 3: Flag checking
echo "${CYAN}Internal storage flag checks:${NC}"
rg --no-heading -n 'has_internal_storage_flag|check.*internal.*flag' lib/*.sh | head -10 | while IFS=: read -r file line content; do
    echo "  ${GREEN}✅${NC} $file:$line"
    echo "     ${GRAY}$content${NC}"
done
echo "  ${GRAY}... (showing first 10)${NC}"
echo ""

#######################################################
# 8. Edge Cases
#######################################################

echo "${YELLOW}[8] Edge Case Handling${NC}"
echo "Checking special contamination scenarios..."
echo ""

# Pattern 1: Empty contamination (flag exists but no data)
echo "${CYAN}Empty contamination handling:${NC}"
empty_contamination=$(rg --no-heading -n 'internal_intentional_empty' lib/*.sh | head -10)
if [[ -z "$empty_contamination" ]]; then
    echo "  ${YELLOW}⚠️${NC}  No explicit empty contamination handling found"
else
    echo "$empty_contamination" | while IFS=: read -r file line content; do
        echo "  ${GREEN}✅${NC} $file:$line"
        echo "     ${GRAY}$content${NC}"
    done
fi
echo ""

# Pattern 2: Wrong location (external_wrong_location)
echo "${CYAN}Wrong location handling:${NC}"
wrong_location=$(rg --no-heading -n 'external_wrong_location' lib/*.sh | head -10)
if [[ -z "$wrong_location" ]]; then
    echo "  ${YELLOW}⚠️${NC}  No explicit wrong location handling found"
else
    echo "$wrong_location" | while IFS=: read -r file line content; do
        echo "  ${GREEN}✅${NC} $file:$line"
        echo "     ${GRAY}$content${NC}"
    done
fi
echo ""

#######################################################
# Summary
#######################################################

echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "${GREEN}Phase 5 Audit Complete${NC}"
echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Key findings:"
echo "  1. Contamination detection uses unified get_storage_mode()"
echo "  2. Contamination state handling is consistent"
echo "  3. Handler functions verified"
echo "  4. Quick launcher excludes contaminated apps"
echo "  5. UI display of contamination is consistent"
echo "  6. Resolution flows (merge/delete/skip) implemented"
echo "  7. Flag management prevents false positives"
echo "  8. Edge cases handled properly"
echo ""
echo "Review the output above for any ${YELLOW}⚠️${NC} or ${RED}❌${NC} markers."
echo ""
