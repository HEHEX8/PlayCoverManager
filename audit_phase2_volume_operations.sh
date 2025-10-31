#!/bin/bash
#######################################################
# Phase 2 Audit: Volume Operation Patterns
# ボリューム操作関連の統一化を徹底検証
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
echo "${GREEN}Phase 2: Volume Operation Unification Audit${NC}"
echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

cd /home/user/webapp

#######################################################
# 1. Mount Operation Patterns
#######################################################

echo "${YELLOW}[1] Mount Operation Patterns${NC}"
echo "Checking mount_volume() usage consistency..."
echo ""

# Pattern 1: mount_volume calls with proper error handling
echo "${CYAN}mount_volume() calls:${NC}"
rg --no-heading -n 'mount_volume\s+' lib/*.sh | grep -v '^[[:space:]]*#' | while IFS=: read -r file line content; do
    # Check if error handling exists (if statement or || or error assignment)
    context=$(sed -n "$((line-1)),$((line+2))p" "$file")
    
    has_error_check=false
    if echo "$context" | grep -qE '(if\s+.*mount_volume|mount_volume.*\|\||&&\s+echo|local.*=.*mount_volume|\$\?)'; then
        has_error_check=true
    fi
    
    if [[ "$has_error_check" == true ]]; then
        echo "  ${GREEN}✅${NC} $file:$line - proper error handling"
    else
        echo "  ${YELLOW}⚠️${NC}  $file:$line - ${ORANGE}no error handling?${NC}"
        echo "     ${GRAY}$content${NC}"
    fi
done
echo ""

# Pattern 2: Direct /usr/bin/sudo /sbin/mount usage (should use mount_volume)
echo "${CYAN}Direct mount calls (should use mount_volume):${NC}"
direct_mounts=$(rg --no-heading -n '/sbin/mount\s+' lib/*.sh | grep -v '^[[:space:]]*#' | grep -v 'mount_volume')
if [[ -z "$direct_mounts" ]]; then
    echo "  ${GREEN}✅ No direct mount calls found${NC}"
else
    echo "$direct_mounts" | while IFS=: read -r file line content; do
        echo "  ${YELLOW}⚠️${NC}  $file:$line"
        echo "     ${GRAY}$content${NC}"
    done
fi
echo ""

#######################################################
# 2. Unmount Operation Patterns
#######################################################

echo "${YELLOW}[2] Unmount Operation Patterns${NC}"
echo "Checking unmount operation consistency..."
echo ""

# Pattern 1: unmount_volume vs unmount_with_fallback
echo "${CYAN}unmount_volume() calls:${NC}"
unmount_count=$(rg -c 'unmount_volume\s+' lib/*.sh | grep -v ':0$' | wc -l | tr -d ' ')
echo "  Found: $unmount_count files using unmount_volume"

echo ""
echo "${CYAN}unmount_with_fallback() calls:${NC}"
unmount_fallback_count=$(rg -c 'unmount_with_fallback\s+' lib/*.sh | grep -v ':0$' | wc -l | tr -d ' ')
echo "  Found: $unmount_fallback_count files using unmount_with_fallback"

echo ""
echo "${CYAN}Usage contexts:${NC}"
rg --no-heading -n -B2 'unmount_(volume|with_fallback)\s+' lib/*.sh | grep -v '^--$' | while IFS=: read -r file line content; do
    # Show context for analysis
    if [[ "$content" =~ "unmount_" ]]; then
        if [[ "$content" =~ "unmount_with_fallback" ]]; then
            echo "  ${GREEN}✅${NC} $file:$line - using fallback"
        else
            echo "  ${CYAN}ℹ️${NC}  $file:$line - direct unmount"
        fi
        echo "     ${GRAY}$content${NC}"
    fi
done | head -30
echo "  ${GRAY}... (showing first 30 lines, full analysis in files)${NC}"
echo ""

#######################################################
# 3. Volume State Checks Before Operations
#######################################################

echo "${YELLOW}[3] Volume State Verification Patterns${NC}"
echo "Checking pre-operation state validation..."
echo ""

# Pattern 1: Mount operations should check if already mounted
echo "${CYAN}Mount operations with state checks:${NC}"
rg --no-heading -n -B5 'mount_volume' lib/*.sh | grep -v '^--$' | while IFS=: read -r file line content; do
    if [[ "$content" =~ (if.*already.*mount|current_mount|validate_and_get_mount) ]]; then
        echo "  ${GREEN}✅${NC} $file:$line - checks mount state"
        echo "     ${GRAY}$content${NC}"
    fi
done | head -15
echo "  ${GRAY}... (showing sample, full list available)${NC}"
echo ""

# Pattern 2: Unmount operations should check if mounted
echo "${CYAN}Unmount operations with state checks:${NC}"
rg --no-heading -n -B3 'unmount_(volume|with_fallback)' lib/*.sh | grep -v '^--$' | while IFS=: read -r file line content; do
    if [[ "$content" =~ (if.*-z.*mount|current_mount.*==|vol_status.*eq) ]]; then
        echo "  ${GREEN}✅${NC} $file:$line - checks mount state"
        echo "     ${GRAY}$content${NC}"
    fi
done | head -15
echo "  ${GRAY}... (showing sample, full list available)${NC}"
echo ""

#######################################################
# 4. App Running Checks Before Volume Operations
#######################################################

echo "${YELLOW}[4] App Running Checks${NC}"
echo "Checking if operations verify app state..."
echo ""

# Pattern 1: is_app_running usage
echo "${CYAN}is_app_running() checks:${NC}"
rg --no-heading -n 'is_app_running' lib/*.sh | grep -v '^[[:space:]]*#' | while IFS=: read -r file line content; do
    echo "  ${GREEN}✅${NC} $file:$line"
    echo "     ${GRAY}$content${NC}"
done
echo ""

# Pattern 2: Direct pgrep usage (should use is_app_running)
echo "${CYAN}Direct pgrep usage (should use is_app_running):${NC}"
direct_pgrep=$(rg --no-heading -n 'pgrep' lib/*.sh | grep -v '^[[:space:]]*#' | grep -v 'is_playcover_running' | grep -v 'is_app_running')
if [[ -z "$direct_pgrep" ]]; then
    echo "  ${GREEN}✅ No problematic direct pgrep calls${NC}"
else
    echo "$direct_pgrep" | while IFS=: read -r file line content; do
        # Check if it's a legitimate system process check
        if [[ "$content" =~ (pmset|caffeinate|system|kernel) ]]; then
            echo "  ${CYAN}ℹ️${NC}  $file:$line - system process check (OK)"
        else
            echo "  ${YELLOW}⚠️${NC}  $file:$line - ${ORANGE}should use is_app_running?${NC}"
        fi
        echo "     ${GRAY}$content${NC}"
    done
fi
echo ""

#######################################################
# 5. quit_app_if_running Usage
#######################################################

echo "${YELLOW}[5] App Quit Patterns${NC}"
echo "Checking quit_app_if_running consistency..."
echo ""

echo "${CYAN}quit_app_if_running() calls:${NC}"
rg --no-heading -n 'quit_app_if_running' lib/*.sh | while IFS=: read -r file line content; do
    echo "  ${GREEN}✅${NC} $file:$line"
    echo "     ${GRAY}$content${NC}"
done
echo ""

# Check if quit happens before unmount operations
echo "${CYAN}Volume operations with app quit:${NC}"
rg --no-heading -n -B10 'unmount_(volume|with_fallback)' lib/*.sh | grep -v '^--$' | while IFS=: read -r file line content; do
    if [[ "$content" =~ quit_app_if_running ]]; then
        echo "  ${GREEN}✅${NC} $file:$line - quits app before unmount"
        echo "     ${GRAY}$content${NC}"
    fi
done | head -15
echo "  ${GRAY}... (showing sample)${NC}"
echo ""

#######################################################
# 6. Cache Invalidation After Operations
#######################################################

echo "${YELLOW}[6] Cache Invalidation Patterns${NC}"
echo "Checking if cache is invalidated after state changes..."
echo ""

echo "${CYAN}invalidate_volume_cache() calls:${NC}"
invalidate_calls=$(rg --no-heading -n 'invalidate_volume_cache' lib/*.sh | grep -v '^[[:space:]]*#')
if [[ -z "$invalidate_calls" ]]; then
    echo "  ${RED}❌ No cache invalidation found!${NC}"
else
    echo "$invalidate_calls" | while IFS=: read -r file line content; do
        echo "  ${GREEN}✅${NC} $file:$line"
        echo "     ${GRAY}$content${NC}"
    done
fi
echo ""

# Check if mount/unmount operations invalidate cache
echo "${CYAN}Mount operations with cache invalidation:${NC}"
mount_with_invalidate=0
mount_without_invalidate=0

rg --no-heading -n -A5 'mount_volume.*"silent"' lib/*.sh | grep -v '^--$' | while IFS=: read -r file line content; do
    if [[ "$content" =~ invalidate_volume_cache ]]; then
        ((mount_with_invalidate++))
    fi
done

echo "  ${CYAN}Operations with cache invalidation: ${mount_with_invalidate}${NC}"
echo ""

#######################################################
# 7. Error Message Consistency
#######################################################

echo "${YELLOW}[7] Error Message Patterns${NC}"
echo "Checking error message consistency..."
echo ""

# Pattern 1: Mount failure messages
echo "${CYAN}Mount error messages:${NC}"
rg --no-heading -n 'マウント失敗|mount.*fail' lib/*.sh | head -10 | while IFS=: read -r file line content; do
    echo "  $file:$line"
    echo "     ${GRAY}$content${NC}"
done
echo ""

# Pattern 2: Unmount failure messages
echo "${CYAN}Unmount error messages:${NC}"
rg --no-heading -n 'アンマウント失敗|unmount.*fail' lib/*.sh | head -10 | while IFS=: read -r file line content; do
    echo "  $file:$line"
    echo "     ${GRAY}$content${NC}"
done
echo ""

#######################################################
# 8. Contamination Handling in Volume Operations
#######################################################

echo "${YELLOW}[8] Contamination Handling in Volume Ops${NC}"
echo "Checking contamination checks before mounting..."
echo ""

echo "${CYAN}Contamination checks before mount:${NC}"
rg --no-heading -n -B3 'internal_contaminated' lib/02_volume.sh lib/03_storage.sh | grep -v '^--$' | while IFS=: read -r file line content; do
    echo "  $file:$line"
    echo "     ${GRAY}$content${NC}"
done
echo ""

# Check handle_contamination usage in batch operations
echo "${CYAN}handle_contamination_for_batch_mount usage:${NC}"
contamination_handlers=$(rg --no-heading -n 'handle_contamination_for_batch' lib/*.sh)
if [[ -z "$contamination_handlers" ]]; then
    echo "  ${YELLOW}⚠️  No batch contamination handlers found${NC}"
else
    echo "$contamination_handlers" | while IFS=: read -r file line content; do
        echo "  ${GREEN}✅${NC} $file:$line"
        echo "     ${GRAY}$content${NC}"
    done
fi
echo ""

#######################################################
# Summary
#######################################################

echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "${GREEN}Phase 2 Audit Complete${NC}"
echo "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Key findings:"
echo "  1. Mount/unmount operations verified"
echo "  2. State check patterns analyzed"
echo "  3. App running checks validated"
echo "  4. Cache invalidation patterns reviewed"
echo "  5. Error message consistency checked"
echo "  6. Contamination handling in batch ops verified"
echo ""
echo "Review the output above for any ${YELLOW}⚠️${NC} or ${RED}❌${NC} markers."
echo ""
