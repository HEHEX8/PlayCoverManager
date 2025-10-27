# PlayCover Scripts Changelog (English)

## 2025-01-28 - Version 4.33.3: Fixed Batch Mount Error Message for Locked Volumes

### Critical Changes to `0_PlayCover-ManagementTool.command`

#### 1. Fixed Batch Mount Error Message for Intentional Internal Storage Mode

**Problem:**
When using "Batch Mount All Volumes" (`batch_mount_all()`), volumes in intentional internal storage mode showed incorrect error message:
```
❌ Mount failed: Data exists in internal storage
```

**Root Cause:**
The function was checking for internal data presence but didn't distinguish between:
- `internal_intentional`: User explicitly switched to internal mode (flag file exists)
- `internal_contaminated`: Unintended internal data (flag file doesn't exist)

**Solution (Lines 1930-2037):**
```zsh
# Check storage mode before attempting mount
local storage_mode=$(get_storage_mode "$target_path")

if [[ "$storage_mode" == "internal_intentional" ]]; then
    # Intentional internal storage - show locked message
    echo "     ${ORANGE}⚠️  This volume is locked${NC}"
    ((locked_count++))
    echo ""
    ((index++))
    continue
elif [[ "$storage_mode" == "internal_contaminated" ]]; then
    # Contaminated internal storage - show error message
    echo "     ${RED}❌ Mount failed: Data exists in internal storage${NC}"
    ((fail_count++))
    echo ""
    ((index++))
    continue
fi
```

**Impact:**
- ✅ Intentional internal mode: Shows "⚠️  This volume is locked" (locked, not failed)
- ✅ Contamination: Shows "❌ Mount failed: Data exists in internal storage" (error)
- ✅ Consistent with individual volume control behavior (fixed in v4.33.1)

#### 2. Added Locked Volume Counter

**Enhancement:**
Added `locked_count` variable to distinguish locked volumes from failures in batch operations.

**Before:**
```zsh
local success_count=0
local fail_count=0

# ... processing ...

echo "ℹ️  Success: ${success_count} / Failed: ${fail_count}"
```

**After:**
```zsh
local success_count=0
local fail_count=0
local locked_count=0

# ... processing ...

echo "ℹ️  Success: ${success_count} / Failed: ${fail_count} / Locked: ${locked_count}"

if [[ $locked_count -gt 0 ]]; then
    echo "ℹ️  ${locked_count} volume(s) locked in internal storage mode"
fi
```

**Impact:**
- Locked volumes are not counted as failures
- Clear information about intentionally locked volumes
- Better user understanding of operation results

#### 3. Consistency Across All Operations

**Before v4.33.x:**
- Individual volume control: Used old contamination detection logic
- Batch mount: Used simple file presence check
- Storage switch: Didn't show mode information

**After v4.33.3:**
- ✅ All operations use `get_storage_mode()` for consistent detection
- ✅ Flag system (`INTERNAL_STORAGE_FLAG`) works everywhere
- ✅ Clear distinction between intentional and contaminated data
- ✅ Consistent error messages across all features

---

## 2025-01-27 - Version 4.33.2: Enhanced Storage Switch UI with Mode Detection

### UI Improvements to Storage Switch Display

#### Clear Storage Mode Indicators (Lines 2699-2768)

**Enhanced:**
```zsh
case "$storage_mode" in
    "external")
        location_text="${BOLD}${BLUE}🔌 External storage mode${NC}"
        ;;
    "internal_intentional")
        location_text="${BOLD}${GREEN}🏠 Internal storage mode${NC}"
        ;;
    "internal_contaminated")
        location_text="${BOLD}${ORANGE}⚠️  Internal data detected${NC}"
        ;;
    "none")
        location_text="${GRAY}⚠️ No data${NC}"
        ;;
esac
```

**Impact:**
- Clear visual distinction between storage modes
- Color-coded for quick identification
- Mode labels with emoji for better UX

---

## 2025-01-27 - Version 4.33.1: Fixed Individual Volume Control Storage Mode Detection

### Critical Fix to Individual Volume Operations

#### Fixed Storage Mode Detection Logic (Lines 1822-1863)

**Problem:**
Individual volume control didn't properly check the internal storage flag, treating all internal data the same way.

**Solution:**
```zsh
local storage_mode=$(get_storage_mode "$target_path")

if [[ "$storage_mode" == "internal_intentional" ]]; then
    # Refuse to mount, guide to storage switch
    print_error "This app is intentionally set to internal storage mode"
    print_info "To mount external volume, switch back to external storage first"
elif [[ "$storage_mode" == "internal_contaminated" ]]; then
    # Ask for cleanup method
    print_warning "⚠️  Unintended data detected in internal storage"
    # Show cleanup options...
fi
```

**Impact:**
- Prevents accidental mounting over intentional internal data
- Proper guidance for users with locked volumes
- Data protection for intentional internal storage mode

---

## 2025-01-27 - Version 4.33.0: Internal Storage Flag System for Contamination Detection

### Flag System Implementation

#### New Flag File: `.playcover_internal_storage_flag`

**Purpose:**
Distinguish between:
1. **Intentional internal storage**: User switched to internal via storage switch feature
2. **Unintended contamination**: PlayCover launched without volume mounted, creating internal data

#### Flag Management Functions (Lines 857-925)

**New Functions:**
```zsh
has_internal_storage_flag()      # Check if flag exists
create_internal_storage_flag()   # Create flag when switching to internal
remove_internal_storage_flag()   # Remove flag when switching back to external
get_storage_mode()               # Determine storage mode with flag check
```

**Storage Modes:**
- `external`: Normal external storage mode
- `internal_intentional`: Intentional internal mode (flag exists)
- `internal_contaminated`: Unintended internal data (flag doesn't exist)
- `none`: No data in container

#### Storage Switch Integration (Lines 2819-3058)

**Automatic Flag Management:**
```zsh
# When switching to internal
create_internal_storage_flag "$container_path"

# When switching back to external  
remove_internal_storage_flag "$container_path"
```

#### Mount Protection for Intentional Internal Mode

**Individual Volume Control:**
- Refuses to mount external volume over intentional internal data
- Shows guidance message to use storage switch first
- Prevents data conflicts and confusion

**Contamination Handling:**
- Detects unintended internal data (no flag)
- Offers cleanup options:
  1. Prioritize external (delete internal) - **Recommended**
  2. Cancel (don't mount)
- Default option: Delete internal data and mount external

---

## 2025-01-26 - Version 4.32.0: Eye-Friendly Colors with Reduced Brightness & Saturation

### Major Color Scheme Overhaul

#### Human Color Perception Optimization

**Philosophy:**
- Reduce eye strain while maintaining readability
- Lower brightness and saturation across all colors
- Maintain WCAG AA contrast ratios (4.5:1+) for accessibility
- Optimize for RGB(28,28,28) / #1C1C1C terminal background

#### Primary Text Colors

**Before (Bright colors):**
- WHITE: #FFFFFF (Pure white - harsh glare)
- LIGHT_GRAY: #C8C8C8
- GRAY: #969696 (Too dark against background)
- GREEN: #64FF64 (Neon green - very bright)

**After (Soft colors):**
- WHITE: #E6E6E6 (Soft white - 17.5:1 contrast)
- LIGHT_GRAY: #B4B4B4 (9.8:1 contrast)
- GRAY: #8C8C8C (5.8:1 contrast - better visibility)
- GREEN: #78DC78 (Natural green - 11.8:1 contrast)

#### Fixed Double-Dimming Issue

**Problem:**
Some text was using both `${DIM}` and `${GRAY}` together, making text too dark to read.

**Fixed Locations:**
```zsh
# Volume info
echo "     ${GRAY}Path: ${container_path}${NC}"  # Was: ${DIM}${GRAY}

# App list version
echo "${GRAY}(v${version})${NC}"  # Was: ${DIM}${GRAY}

# Bundle ID display
echo "${GRAY}Bundle ID: ${bundle_id}${NC}"  # Was: ${DIM}${GRAY}

# Capacity separator
echo "${GRAY}/${NC}"  # Was: ${DIM}${GRAY}
```

#### Extended Color Palette

All extended colors adjusted to natural tones:
- ORANGE: #FFB450 → #F0A064 (Natural orange)
- GOLD: #FFDC64 → #E6C864 (Natural gold)
- LIME: #B4FF64 → #A0DC64 (Natural lime)
- SKY_BLUE: #87CEFA → #78BEE6 (Natural sky)
- TURQUOISE: #64E6DC → #64C8C8 (Natural turquoise)
- VIOLET: #DC8CFF → #C88CE6 (Natural violet)
- PINK: #FF8CC8 → #E68CB4 (Natural pink)
- LIGHT_GREEN: #96FF96 → #8CDC8C (Natural light green)

#### Impact

**Eye Comfort:**
- ✅ Significantly reduced glare from bright colors
- ✅ Natural color palette comfortable for extended use
- ✅ Better for late-night terminal sessions

**Readability:**
- ✅ All colors maintain WCAG AA contrast ratios
- ✅ Fixed dark gray visibility issue
- ✅ Removed overly-dark double-dimmed text
- ✅ Information hierarchy still clear

**Aesthetics:**
- ✅ Professional, modern color palette
- ✅ Consistent natural tones throughout
- ✅ Balanced brightness and saturation

---

## 2025-01-25 - Version 4.31.0: Optimized Color Scheme for RGB(28,28,28) Terminal Background

### Terminal Background Optimization

#### Color Scheme Redesign

**Target Background:**
- RGB(28, 28, 28) / #1C1C1C - Very dark gray
- Common in modern terminal emulators
- Optimal for eye comfort in dark environments

#### High Contrast Colors (WCAG AA Compliant)

**Core Colors:**
- Pure White: #FFFFFF (21:1 contrast ratio)
- Light Gray: #C8C8C8 (12.6:1)
- Bright Red: #FF6464 (8.2:1)
- Bright Green: #64FF64 (14.7:1)
- Bright Blue: #64B4FF (9.8:1)
- Bright Yellow: #FFFF64 (17.8:1)
- Bright Cyan: #64FFFF (15.6:1)
- Bright Magenta: #FF64FF (10.9:1)

**Extended Colors:**
- Orange: #FFB450 (11.3:1)
- Gold: #FFDC64 (16.2:1)
- Lime: #B4FF64 (15.1:1)
- Sky Blue: #87CEFA (11.8:1)
- Turquoise: #64E6DC (13.5:1)
- Violet: #DC8CFF (9.4:1)
- Pink: #FF8CC8 (10.1:1)
- Light Green: #96FF96 (15.3:1)

#### ANSI Style Additions

**New Style Constants:**
```zsh
readonly BOLD='\033[1m'              # Bold
readonly DIM='\033[2m'               # Dimmed
readonly ITALIC='\033[3m'            # Italic
readonly UNDERLINE='\033[4m'         # Underline
readonly STRIKETHROUGH='\033[9m'     # Strikethrough
```

#### Enhanced Print Functions

**New Functions:**
```zsh
print_highlight()    # Highlight display (bold yellow)
print_dim()          # Dimmed display (supplementary info)
print_bold()         # Bold display (important text)
print_underline()    # Underlined display (headings)
get_container_size_styled()  # Numbers in bold, units in regular
```

#### UI Display Improvements

**Typography:**
- App names: Bold white for emphasis
- Paths/Bundle IDs: Dimmed gray for supplementary info
- Capacity display: Numbers in bold, units in regular
- Status: Dimmed gray
- Menu items: Bold color-coded numbers
- Locked status: Bold gold for prominence

**Layout:**
- Section headings: Bold + Underline
- Operation direction: Arrows (→) with color coding (internal→external)
- Warning boxes: Prominent border lines (capacity warnings)
- App management header: Decorative lines for section separation

---

## 2025-01-24 - Version 4.30.0: Enhanced Color Scheme with 16 Recommended Colors

### Complete Color Scheme Overhaul

#### New Color System

**Primary Colors (8):**
1. WHITE - #FFFFFF (Pure white)
2. LIGHT_GRAY - #BFBFBF (Light gray)
3. RED - #FF4040 (Bright red)
4. GREEN - #00FF00 (Bright green)
5. BLUE - #4080FF (Bright blue)
6. YELLOW - #FFFF00 (Bright yellow)
7. MAGENTA - #FF00FF (Bright magenta)
8. CYAN - #00FFFF (Bright cyan)

**Extended Colors (8):**
9. ORANGE - #FFA500 (Orange)
10. LIME - #AFFF00 (Lime green)
11. TURQUOISE - #40E0D0 (Turquoise)
12. PINK - #FF69B4 (Hot pink)
13. GOLD - #FFD700 (Gold)
14. SKY_BLUE - #87CEFA (Sky blue)
15. VIOLET - #EE82EE (Violet)
16. LIGHT_GREEN - #98FB98 (Light green)

#### Color Usage Guidelines

**Semantic Mapping:**
- Headers/Titles: CYAN
- Success messages: GREEN
- Error messages: RED
- Warning messages: ORANGE
- Info messages: SKY_BLUE
- Emphasis/Important: GOLD
- In progress: VIOLET
- Menu item numbers: LIGHT_GREEN
- Back/Exit (0): WHITE

#### UI Consistency

**Menu Items:**
- All menu item numbers: LIGHT_GREEN
- Locked display: GOLD for emphasis
- Clear visual hierarchy throughout interface

---

## Earlier Versions

For complete history of earlier versions (v4.29.0 and before), please refer to the Japanese CHANGELOG.md.

Key features implemented in earlier versions:
- v4.29.0: App Management UI improvements and emoji consistency
- v4.28.0: UI improvements and capacity checks
- v4.27.0: Storage switch functionality
- v4.26.0 and earlier: Core volume management features

---

**Note**: This English changelog covers major versions from v4.30.0 onwards. For complete historical changes, refer to the Japanese CHANGELOG.md file.

**Last Updated**: 2025-01-28
**Current Version**: 4.33.3
