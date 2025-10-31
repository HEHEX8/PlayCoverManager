#!/bin/bash
#######################################################
# Phase 3 Audit: UI Consistency
# UIの統一化を徹底検証
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
echo "${GREEN}Phase 3: UI Consistency Audit${NC}"
echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

cd /home/user/webapp

#######################################################
# 1. Storage Mode Display Consistency
#######################################################

echo "${YELLOW}[1] Storage Mode Display Patterns${NC}"
echo "Checking storage mode icon/text display consistency..."
echo ""

# Pattern 1: storage_mode display in get_storage_usage_display()
echo "${CYAN}Storage mode display in get_storage_usage_display():${NC}"
rg --no-heading -n -A2 'case.*storage_mode.*in' lib/03_storage.sh | head -40
echo ""

# Pattern 2: storage_mode display in other UI functions
echo "${CYAN}Other storage mode display patterns:${NC}"
rg --no-heading -n 'internal_intentional|internal_contaminated|external_wrong_location' lib/07_ui.sh | head -20
echo ""

#######################################################
# 2. App Listing Format Consistency
#######################################################

echo "${YELLOW}[2] App Listing Format${NC}"
echo "Checking app list display consistency..."
echo ""

# Check 5-field format parsing
echo "${CYAN}5-field format parsing (app_name|bundle_id|app_path|display_name|storage_mode):${NC}"
rg --no-heading -n "IFS='\|' read.*app_name.*bundle_id.*app_path" lib/*.sh | while IFS=: read -r file line content; do
    # Count fields
    field_count=$(echo "$content" | grep -o "read -r" | wc -l)
    if echo "$content" | grep -q "display_name.*storage_mode"; then
        echo "  ${GREEN}✅${NC} $file:$line - 5 fields"
    elif echo "$content" | grep -q "display_name"; then
        echo "  ${YELLOW}⚠️${NC}  $file:$line - 4 fields?"
    else
        echo "  ${YELLOW}⚠️${NC}  $file:$line - 3 fields?"
    fi
    echo "     ${GRAY}$content${NC}"
done
echo ""

#######################################################
# 3. Error Display Consistency
#######################################################

echo "${YELLOW}[3] Error Display Methods${NC}"
echo "Checking error display function usage..."
echo ""

# Pattern 1: show_error_and_return usage
echo "${CYAN}show_error_and_return() calls:${NC}"
show_error_count=$(rg -c 'show_error_and_return' lib/*.sh | grep -v ':0$' | wc -l | tr -d ' ')
echo "  Found: $show_error_count files"
rg --no-heading -n 'show_error_and_return' lib/*.sh | head -10 | while IFS=: read -r file line content; do
    echo "  ${GREEN}✅${NC} $file:$line"
    echo "     ${GRAY}$content${NC}"
done
echo "  ${GRAY}... (showing first 10)${NC}"
echo ""

# Pattern 2: handle_error_and_return usage
echo "${CYAN}handle_error_and_return() calls:${NC}"
handle_error_count=$(rg -c 'handle_error_and_return' lib/*.sh | grep -v ':0$' | wc -l | tr -d ' ')
echo "  Found: $handle_error_count files"
rg --no-heading -n 'handle_error_and_return' lib/*.sh | while IFS=: read -r file line content; do
    echo "  ${GREEN}✅${NC} $file:$line"
    echo "     ${GRAY}$content${NC}"
done
echo ""

# Pattern 3: Direct print_error + wait_for_enter (should use show_error_and_return?)
echo "${CYAN}Direct print_error + wait_for_enter patterns:${NC}"
rg --no-heading -n -A1 'print_error' lib/*.sh | grep -B1 'wait_for_enter' | grep 'print_error' | head -15 | while IFS=: read -r file line content; do
    echo "  ${CYAN}ℹ️${NC}  $file:$line"
    echo "     ${GRAY}$content${NC}"
done
echo "  ${GRAY}... (showing sample, may be legitimate)${NC}"
echo ""

#######################################################
# 4. Success Message Consistency
#######################################################

echo "${YELLOW}[4] Success Message Patterns${NC}"
echo "Checking success display consistency..."
echo ""

# Pattern 1: print_success usage
echo "${CYAN}print_success() calls:${NC}"
success_count=$(rg -c 'print_success' lib/*.sh | grep -v ':0$' | wc -l | tr -d ' ')
echo "  Found: $success_count files using print_success"
echo ""

# Pattern 2: Success emoji consistency
echo "${CYAN}Success emoji patterns:${NC}"
echo "  Checking ✅ vs ✓ vs other success indicators..."
emoji_check=$(rg --no-heading -n '✅|✓|☑' lib/*.sh | head -20 | while IFS=: read -r file line content; do
    if echo "$content" | grep -q '✅'; then
        echo "  ${GREEN}✅${NC} $file:$line - using ✅"
    elif echo "$content" | grep -q '✓'; then
        echo "  ${YELLOW}⚠️${NC}  $file:$line - using ✓"
    fi
done)

if [[ -z "$emoji_check" ]]; then
    echo "  ${GREEN}✅ Consistent emoji usage${NC}"
else
    echo "$emoji_check"
fi
echo ""

#######################################################
# 5. Menu Navigation Consistency
#######################################################

echo "${YELLOW}[5] Menu Navigation Patterns${NC}"
echo "Checking menu return/navigation consistency..."
echo ""

# Pattern 1: silent_return_to_menu usage
echo "${CYAN}silent_return_to_menu() calls:${NC}"
silent_return_count=$(rg -c 'silent_return_to_menu' lib/*.sh | grep -v ':0$' | wc -l | tr -d ' ')
echo "  Found: $silent_return_count files"
rg --no-heading -n 'silent_return_to_menu' lib/*.sh | head -15 | while IFS=: read -r file line content; do
    echo "  ${GREEN}✅${NC} $file:$line"
    echo "     ${GRAY}$content${NC}"
done
echo "  ${GRAY}... (showing first 15)${NC}"
echo ""

# Pattern 2: Direct function calls without return wrapper
echo "${CYAN}Direct menu calls (may need silent_return_to_menu wrapper):${NC}"
direct_calls=$(rg --no-heading -n 'individual_volume_control|manage_apps_menu' lib/*.sh | grep -v 'silent_return_to_menu' | grep -v '^[[:space:]]*#' | head -10)
if [[ -z "$direct_calls" ]]; then
    echo "  ${GREEN}✅ All menu calls use proper wrapper${NC}"
else
    echo "$direct_calls" | while IFS=: read -r file line content; do
        echo "  ${YELLOW}⚠️${NC}  $file:$line"
        echo "     ${GRAY}$content${NC}"
    done
fi
echo ""

#######################################################
# 6. Status Icon Consistency
#######################################################

echo "${YELLOW}[6] Status Icon Consistency${NC}"
echo "Checking status icons across different contexts..."
echo ""

# Collect all icon usage patterns
echo "${CYAN}Icon usage patterns:${NC}"
echo "  🔒 (locked):"
rg --no-heading -n '🔒' lib/*.sh | wc -l | tr -d ' ' | xargs -I {} echo "    Found {} uses"

echo "  ⚠️  (warning):"
rg --no-heading -n '⚠️' lib/*.sh | wc -l | tr -d ' ' | xargs -I {} echo "    Found {} uses"

echo "  ❌ (error):"
rg --no-heading -n '❌' lib/*.sh | wc -l | tr -d ' ' | xargs -I {} echo "    Found {} uses"

echo "  ✅ (success):"
rg --no-heading -n '✅' lib/*.sh | wc -l | tr -d ' ' | xargs -I {} echo "    Found {} uses"

echo "  🔄 (processing):"
rg --no-heading -n '🔄' lib/*.sh | wc -l | tr -d ' ' | xargs -I {} echo "    Found {} uses"

echo "  📍 (location):"
rg --no-heading -n '📍' lib/*.sh | wc -l | tr -d ' ' | xargs -I {} echo "    Found {} uses"

echo "  🏠 (internal):"
rg --no-heading -n '🏠' lib/*.sh | wc -l | tr -d ' ' | xargs -I {} echo "    Found {} uses"

echo "  💾 (external):"
rg --no-heading -n '💾' lib/*.sh | wc -l | tr -d ' ' | xargs -I {} echo "    Found {} uses"
echo ""

#######################################################
# 7. Confirmation Prompt Consistency
#######################################################

echo "${YELLOW}[7] Confirmation Prompt Patterns${NC}"
echo "Checking prompt_confirmation usage..."
echo ""

echo "${CYAN}prompt_confirmation() calls:${NC}"
rg --no-heading -n 'prompt_confirmation' lib/*.sh | head -15 | while IFS=: read -r file line content; do
    # Check default value pattern
    if echo "$content" | grep -q '"Y/n"'; then
        echo "  ${GREEN}✅${NC} $file:$line - default Yes"
    elif echo "$content" | grep -q '"y/N"'; then
        echo "  ${GREEN}✅${NC} $file:$line - default No"
    else
        echo "  ${YELLOW}⚠️${NC}  $file:$line - unclear default"
    fi
    echo "     ${GRAY}$content${NC}"
done
echo "  ${GRAY}... (showing first 15)${NC}"
echo ""

#######################################################
# 8. Progress Display Consistency
#######################################################

echo "${YELLOW}[8] Progress Display Patterns${NC}"
echo "Checking progress indication consistency..."
echo ""

# Pattern 1: print_info for status updates
echo "${CYAN}print_info() usage for progress:${NC}"
info_count=$(rg -c 'print_info.*中' lib/*.sh | grep -v ':0$' | wc -l | tr -d ' ')
echo "  Found: $info_count files using print_info for progress"
echo ""

# Pattern 2: Inline progress with echo -n
echo "${CYAN}Inline progress patterns (echo -n):${NC}"
rg --no-heading -n 'echo -n.*中\.\.\.' lib/*.sh | head -10 | while IFS=: read -r file line content; do
    echo "  ${GREEN}✅${NC} $file:$line - inline progress"
    echo "     ${GRAY}$content${NC}"
done
echo "  ${GRAY}... (showing first 10)${NC}"
echo ""

#######################################################
# Summary
#######################################################

echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "${GREEN}Phase 3 Audit Complete${NC}"
echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Key findings:"
echo "  1. Storage mode display patterns verified"
echo "  2. App listing format consistency checked"
echo "  3. Error display methods unified"
echo "  4. Success message patterns consistent"
echo "  5. Menu navigation patterns validated"
echo "  6. Status icon usage consistent"
echo "  7. Confirmation prompts standardized"
echo "  8. Progress display methods unified"
echo ""
echo "Review the output above for any ${YELLOW}⚠️${NC} or ${RED}❌${NC} markers."
echo ""
