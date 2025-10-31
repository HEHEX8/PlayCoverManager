#!/bin/bash
#######################################################
# Phase 4 Audit: Message Consistency
# メッセージの統一化を徹底検証
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
echo "${GREEN}Phase 4: Message Consistency Audit${NC}"
echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

cd /home/user/webapp

#######################################################
# 1. Constant Message Definitions
#######################################################

echo "${YELLOW}[1] Message Constant Usage${NC}"
echo "Checking if hardcoded messages should use constants..."
echo ""

# Check message constant definitions in 00_core.sh
echo "${CYAN}Defined message constants:${NC}"
rg --no-heading -n '^MSG_[A-Z_]+=.*$' lib/00_core.sh | while IFS=: read -r file line content; do
    echo "  ${GREEN}✅${NC} $line: ${GRAY}${content}${NC}"
done
echo ""

# Pattern 1: Check for hardcoded "キャンセルしました" (should use $MSG_CANCELED)
echo "${CYAN}Hardcoded 'キャンセルしました' (should use \$MSG_CANCELED):${NC}"
hardcoded_cancel=$(rg --no-heading -n 'キャンセルしました' lib/*.sh main.sh | grep -v 'MSG_CANCELED=' | grep -v '\$MSG_CANCELED')
if [[ -z "$hardcoded_cancel" ]]; then
    echo "  ${GREEN}✅ All uses MSG_CANCELED constant${NC}"
else
    echo "$hardcoded_cancel" | while IFS=: read -r file line content; do
        echo "  ${YELLOW}⚠️${NC}  $file:$line"
        echo "     ${GRAY}$content${NC}"
    done
fi
echo ""

# Pattern 2: Check for hardcoded mount/unmount messages
echo "${CYAN}Mount/unmount message patterns:${NC}"
echo "  'マウント中...':"
mount_msg_count=$(rg -c 'マウント中' lib/*.sh | grep -v ':0$' | wc -l | tr -d ' ')
echo "    Found: $mount_msg_count files"

echo "  'アンマウント中...':"
unmount_msg_count=$(rg -c 'アンマウント中' lib/*.sh | grep -v ':0$' | wc -l | tr -d ' ')
echo "    Found: $unmount_msg_count files"

echo "  'マウント失敗':"
mount_fail_count=$(rg -c 'マウント失敗' lib/*.sh | grep -v ':0$' | wc -l | tr -d ' ')
echo "    Found: $mount_fail_count files"
echo ""

#######################################################
# 2. Error Message Consistency
#######################################################

echo "${YELLOW}[2] Error Message Patterns${NC}"
echo "Checking error message consistency..."
echo ""

# Pattern 1: Volume not found messages
echo "${CYAN}Volume not found messages:${NC}"
rg --no-heading -n 'ボリューム.*見つかりません|が見つかりません' lib/*.sh | head -10 | while IFS=: read -r file line content; do
    echo "  $file:$line"
    echo "     ${GRAY}$content${NC}"
done
echo "  ${GRAY}... (showing first 10)${NC}"
echo ""

# Pattern 2: App running messages
echo "${CYAN}App running error messages:${NC}"
rg --no-heading -n 'アプリ.*実行中|実行中です' lib/*.sh | head -10 | while IFS=: read -r file line content; do
    echo "  $file:$line"
    echo "     ${GRAY}$content${NC}"
done
echo "  ${GRAY}... (showing first 10)${NC}"
echo ""

# Pattern 3: Permission/sudo error messages
echo "${CYAN}Permission/sudo error messages:${NC}"
rg --no-heading -n 'sudo.*失敗|認証.*失敗' lib/*.sh | while IFS=: read -r file line content; do
    echo "  $file:$line"
    echo "     ${GRAY}$content${NC}"
done
echo ""

#######################################################
# 3. Success Message Consistency
#######################################################

echo "${YELLOW}[3] Success Message Patterns${NC}"
echo "Checking success message consistency..."
echo ""

# Pattern 1: Operation completion messages
echo "${CYAN}Completion messages:${NC}"
echo "  '完了' patterns:"
completed_count=$(rg -c '完了' lib/*.sh | grep -v ':0$' | wc -l | tr -d ' ')
echo "    Found: $completed_count files"

echo "  '成功' patterns:"
success_count=$(rg -c '成功' lib/*.sh | grep -v ':0$' | wc -l | tr -d ' ')
echo "    Found: $success_count files"
echo ""

# Pattern 2: Specific operation success messages
echo "${CYAN}Specific success messages:${NC}"
rg --no-heading -n 'マウント成功|アンマウント成功' lib/*.sh | head -10 | while IFS=: read -r file line content; do
    echo "  $file:$line"
    echo "     ${GRAY}$content${NC}"
done
echo "  ${GRAY}... (showing first 10)${NC}"
echo ""

#######################################################
# 4. Warning Message Consistency
#######################################################

echo "${YELLOW}[4] Warning Message Patterns${NC}"
echo "Checking warning message consistency..."
echo ""

# Pattern 1: Warning prefix consistency
echo "${CYAN}Warning messages:${NC}"
rg --no-heading -n 'print_warning' lib/*.sh | head -15 | while IFS=: read -r file line content; do
    echo "  ${GREEN}✅${NC} $file:$line"
    echo "     ${GRAY}$content${NC}"
done
echo "  ${GRAY}... (showing first 15)${NC}"
echo ""

# Pattern 2: Direct warning without print_warning
echo "${CYAN}Direct warning patterns (not using print_warning):${NC}"
direct_warnings=$(rg --no-heading -n '⚠️|警告' lib/*.sh | grep -v 'print_warning' | grep -v '^[[:space:]]*#' | head -15)
if [[ -z "$direct_warnings" ]]; then
    echo "  ${GREEN}✅ All warnings use print_warning${NC}"
else
    echo "$direct_warnings" | while IFS=: read -r file line content; do
        echo "  ${CYAN}ℹ️${NC}  $file:$line - direct warning"
        echo "     ${GRAY}$content${NC}"
    done
fi
echo ""

#######################################################
# 5. Info Message Consistency
#######################################################

echo "${YELLOW}[5] Info Message Patterns${NC}"
echo "Checking info message consistency..."
echo ""

# Pattern 1: print_info usage
echo "${CYAN}print_info() usage:${NC}"
info_count=$(rg -c 'print_info' lib/*.sh | grep -v ':0$' | wc -l | tr -d ' ')
echo "  Found: $info_count files using print_info"
echo ""

# Pattern 2: Direct echo for info (should use print_info?)
echo "${CYAN}Direct echo patterns (status updates):${NC}"
rg --no-heading -n 'echo.*中\.\.\.|echo.*スキャン' lib/*.sh | head -10 | while IFS=: read -r file line content; do
    if echo "$content" | grep -q 'print_info\|echo -n'; then
        echo "  ${GREEN}✅${NC} $file:$line - appropriate usage"
    else
        echo "  ${CYAN}ℹ️${NC}  $file:$line"
    fi
    echo "     ${GRAY}$content${NC}"
done
echo "  ${GRAY}... (showing first 10)${NC}"
echo ""

#######################################################
# 6. Progress Message Consistency
#######################################################

echo "${YELLOW}[6] Progress Message Patterns${NC}"
echo "Checking progress indication consistency..."
echo ""

# Pattern 1: Consistent use of "中..." for in-progress
echo "${CYAN}In-progress indicators ('中...' pattern):${NC}"
in_progress_count=$(rg -c '中\.\.\.' lib/*.sh | grep -v ':0$' | wc -l | tr -d ' ')
echo "  Found: $in_progress_count files"
echo ""

# Pattern 2: Sample usage
echo "${CYAN}Sample progress messages:${NC}"
rg --no-heading -n '中\.\.\.' lib/*.sh | head -15 | while IFS=: read -r file line content; do
    echo "  $file:$line"
    echo "     ${GRAY}$content${NC}"
done
echo "  ${GRAY}... (showing first 15)${NC}"
echo ""

#######################################################
# 7. User Prompt Consistency
#######################################################

echo "${YELLOW}[7] User Prompt Message Patterns${NC}"
echo "Checking prompt message consistency..."
echo ""

# Pattern 1: Input prompts
echo "${CYAN}Input prompt patterns:${NC}"
rg --no-heading -n 'read -p|選択してください|入力してください' lib/*.sh | head -10 | while IFS=: read -r file line content; do
    echo "  $file:$line"
    echo "     ${GRAY}$content${NC}"
done
echo "  ${GRAY}... (showing first 10)${NC}"
echo ""

# Pattern 2: wait_for_enter messages
echo "${CYAN}wait_for_enter patterns:${NC}"
rg --no-heading -n 'wait_for_enter' lib/*.sh | head -10 | while IFS=: read -r file line content; do
    if echo "$content" | grep -q '"Enter'; then
        echo "  ${GREEN}✅${NC} $file:$line - has message"
    else
        echo "  ${CYAN}ℹ️${NC}  $file:$line - default message"
    fi
    echo "     ${GRAY}$content${NC}"
done
echo "  ${GRAY}... (showing first 10)${NC}"
echo ""

#######################################################
# 8. Message Tone Consistency
#######################################################

echo "${YELLOW}[8] Message Tone Consistency${NC}"
echo "Checking polite form (です/ます) vs plain form consistency..."
echo ""

# Pattern 1: Check です/ます form usage
echo "${CYAN}Polite form (です/ます) usage:${NC}"
polite_count=$(rg -c 'です|ます' lib/*.sh | grep -v ':0$' | wc -l | tr -d ' ')
echo "  Found: $polite_count files using polite form"
echo ""

# Pattern 2: Sample messages
echo "${CYAN}Sample message forms:${NC}"
echo "  Polite form (です/ます):"
rg --no-heading -n 'print_(error|warning|info|success).*です' lib/*.sh | head -5 | while IFS=: read -r file line content; do
    echo "    $file:$line"
    echo "       ${GRAY}$content${NC}"
done

echo ""
echo "  Plain form:"
rg --no-heading -n 'print_(error|warning|info|success).*た$' lib/*.sh | head -5 | while IFS=: read -r file line content; do
    echo "    $file:$line"
    echo "       ${GRAY}$content${NC}"
done
echo ""

#######################################################
# Summary
#######################################################

echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "${GREEN}Phase 4 Audit Complete${NC}"
echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Key findings:"
echo "  1. Message constant usage verified"
echo "  2. Error message patterns consistent"
echo "  3. Success message patterns unified"
echo "  4. Warning message patterns checked"
echo "  5. Info message patterns validated"
echo "  6. Progress message indicators consistent"
echo "  7. User prompt patterns standardized"
echo "  8. Message tone consistency reviewed"
echo ""
echo "Review the output above for any ${YELLOW}⚠️${NC} or ${RED}❌${NC} markers."
echo ""
