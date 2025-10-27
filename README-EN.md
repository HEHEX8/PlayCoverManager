# PlayCover External Storage Management Tool

macOS Sequoia 15.1+ (Tahoe 26.0.1) Compatible Integrated Management Tool

## 🎯 Overview

An **all-in-one management tool** for running PlayCover with external storage.
Integrates all functionality from initial setup to app installation, volume management, and complete reset.

## 📦 Main Tool

### `0_PlayCover-ManagementTool.command`
**PlayCover Integrated Management Tool (v4.33.3)**

All features integrated into a single script.

**Note**: Currently, the main script interface is in Japanese. An English version (`0_PlayCover-ManagementTool-EN.command`) is being developed. The core functionality works the same regardless of language.

#### 🎛️ Main Features

1. **Initial Setup**
   - Apple Silicon Mac verification
   - Full Disk Access permission check
   - Xcode Command Line Tools check and installation
   - Homebrew check and installation
   - PlayCover check and installation (`brew install --cask playcover-community`)
   - External storage selection
   - PlayCover main volume creation and mounting
   - Mapping file creation

2. **IPA Installation**
   - IPA file selection (Finder dialog)
   - App information extraction (Japanese name support)
   - Dedicated app volume creation
   - Pre-creation confirmation prompt
   - Existing app detection and version comparison
   - Update confirmation prompt
   - Automatic mounting (to correct location)
   - Launch PlayCover for installation
   - Registration to mapping file

3. **Volume Management**
   - **Mount All Volumes**
     - Priority mounting of PlayCover main volume
     - Batch mounting of all app volumes
     - Automatic remounting of incorrectly placed volumes
     - Cleanup confirmation for non-existent volumes
   
   - **Unmount All Volumes**
     - Batch unmounting of app volumes
     - Unmounting of PlayCover main volume
     - Result summary display
   
   - **Individual Volume Control**
     - Real-time status display
       - ✅ Properly mounted
       - ⚠️  Mounted at different location
       - ⭕ Unmounted
       - ❌ Volume not found
       - 🔒 Locked (intentional internal storage)
     - Individual mount/unmount/remount
     - Mapping deletion for non-existent volumes
   
   - **Volume Status Check**
     - PlayCover main volume status check
     - Detailed status check of all app volumes
     - Clear display with Japanese/English names
   
   - **Eject Entire Disk**
     - Automatic unmounting of all volumes
     - Disk information display
     - Safe ejection confirmation
     - Physical device ejection preparation

4. **🔥 Nuclear Cleanup (Complete Reset)**
   - Unmount all volumes
   - Complete deletion of all containers
   - Uninstall PlayCover (`brew uninstall --cask playcover-community`)
   - Delete PlayTools.framework
   - Delete cache, settings, and logs
   - Delete APFS volumes (both internal and external)
   - Delete mapping file
   - Double confirmation system (yes + DELETE ALL)
   - Complete preview before deletion

**⚠️ Warning**: This operation is irreversible! All PlayCover data will be deleted.

---

## 🚀 Usage

### Initial Setup
1. Double-click `0_PlayCover-ManagementTool.command`
2. Select **[1] Initial Setup** from main menu
3. Enter administrator password
4. Select external storage
5. Confirm installation of required software
6. Wait for completion

### App Installation
1. Double-click `0_PlayCover-ManagementTool.command`
2. Select **[2] IPA Install** from main menu
3. Enter administrator password
4. Select IPA file
5. Confirm volume creation
6. Confirm update if existing app found
7. Complete installation in PlayCover

### Daily Management
1. Double-click `0_PlayCover-ManagementTool.command`
2. Select **[3] Volume Management** from main menu
3. Select operation from submenu
   - **[1] Mount All Volumes**: Run after Mac startup
   - **[2] Unmount All Volumes**: Run before Mac shutdown
   - **[3] Individual Volume Control**: When individual management needed
   - **[4] Volume Status Check**: To check current status
   - **[5] Eject Entire Disk**: Before removing external storage

### 🔥 Complete Reset (For Troubleshooting)
1. Double-click `0_PlayCover-ManagementTool.command`
2. Select **[3] Volume Management** from main menu
3. Select **[6] Nuclear Cleanup** from submenu
4. Review complete preview of deletion targets
5. Type `yes`
6. Type `DELETE ALL` to execute
7. Terminal closes automatically after completion
8. **Re-setup required**: Run [1] from main menu again

---

## 📄 Mapping File

`playcover-map.txt` - Records volume and app correspondence

**Format (Tab-separated):**
```
VolumeName	BundleID	DisplayName
PlayCover	io.playcover.PlayCover	PlayCover
ZenlessZoneZero	com.HoYoverse.Nap	Zenless Zone Zero
HonkaiStarRail	com.HoYoverse.hkrpgoversea	Honkai: Star Rail
```

**Features:**
- 3-column structure (Volume name, Bundle ID, Display name)
- Stores Japanese or English names
- Automatically utilized by volume management functions

---

## 🎨 UI Design

Unified UI design across all features (Optimized for RGB(28,28,28) background):

### Color Scheme (High Contrast)
- 🟢 **Green** (#78DC78): Success messages, internal storage
- 🔴 **Red** (#FF7878): Error messages, delete operations
- 🟡 **Yellow** (#E6DC64): Warning messages, operation arrows
- 🔵 **Blue** (#78B4F0): Info messages, external storage
- 💠 **Cyan** (#64DCDC): Section headers, menu numbers
- ⚪ **White** (#E6E6E6): Important text, app names
- 🌫️ **Light Gray** (#B4B4B4): Normal text
- 🌑 **Gray** (#8C8C8C): Supplementary info, paths

### Text Styles
- **Bold**: Important elements (app names, numbers, menu numbers)
- **Underline**: Section headers
- **Dim**: Supplementary info (paths, Bundle IDs, status)
- **Strikethrough**: Deleted/not found items

### Message Icons
- ✅ Success
- ❌ Error
- ⚠️  Warning
- ℹ️  Info
- ▶ Highlight

### Status Icons
- 🟢 Normal operation (green circle + mounted)
- ⚠️  Abnormal state (yellow triangle + incorrect mount location)
- ⚪️ Unmounted (white circle)
- ❌ Not found (red X)
- 🔒 Locked (padlock + gold highlight)

### Storage Display
- 🏠 Internal Storage (green highlight)
- 🔌 External Storage (blue highlight)
- → Direction of movement (yellow arrow)

### Layout Elements
- **Section divider**: Decorative lines (━━━)
- **Warning box**: Enclosed with prominent border (════)
- **Information hierarchy**: Hierarchy expressed with indentation and color depth

### Exit Handling
- **On success**: Auto-close after 3 seconds
- **On error**: Wait for Enter key (for log review)
- **After cleanup**: Auto-exit after 3 seconds (re-setup required)

---

## 🔧 Technical Details

### PlayCover External App Installation System

#### Previous Problem
When PlayCover starts with the volume unmounted, data is created in the internal storage container, preventing external volume mounting.

#### Solution
Place PlayCover.app itself on external storage, with only a symbolic link in /Applications:

```bash
# Actual location
~/Library/Containers/io.playcover.PlayCover/PlayCover.app

# Symbolic link
/Applications/PlayCover.app -> ~/Library/Containers/io.playcover.PlayCover/PlayCover.app
```

#### Benefits
- ✅ PlayCover automatically unable to launch when external drive disconnected
- ✅ Spotlight and Launchpad search works normally
- ✅ Complete prevention of internal storage data creation from accidental launch
- ✅ Automatic verification and recreation of symbolic link on mount

### Mount Options
All volumes are mounted with `nobrowse` option, preventing display in Finder sidebar and desktop.

```bash
sudo mount -t apfs -o nobrowse /dev/diskXsY ~/Library/Containers/[BundleID]
```

### Volume Layout
- **PlayCover main volume**: `~/Library/Containers/io.playcover.PlayCover`
- **PlayCover app itself**: `~/Library/Containers/io.playcover.PlayCover/PlayCover.app`
- **App volumes**: `~/Library/Containers/[Each app's BundleID]`

### Auto-Correction Features
Volume management detects volumes mounted at incorrect locations and automatically remounts them correctly. Also automatically detects and repairs broken symbolic links.

### Management via Homebrew
PlayCover itself is installed/uninstalled using official methods:
```bash
# Installation
brew install --cask playcover-community

# Uninstallation (during nuclear cleanup)
brew uninstall --cask playcover-community
```

---

## 🔄 Storage Mode System (v4.33.x)

### Internal Storage Flag System

**Purpose**: Distinguish between intentional internal storage and unintended contamination.

#### Storage Modes

1. **External Storage Mode** (`external`)
   - Normal operation mode
   - Data stored on external volume
   - Display: 🔌 External storage mode (blue)

2. **Intentional Internal Storage Mode** (`internal_intentional`)
   - User explicitly switched to internal storage
   - Flag file exists: `.playcover_internal_storage_flag`
   - Volume is locked - cannot mount external volume
   - Display: 🏠 Internal storage mode (green) / 🔒 Locked
   - Protection: Prevents accidental mounting over internal data

3. **Contaminated Internal Storage** (`internal_contaminated`)
   - Unintended internal data (PlayCover launched without volume)
   - No flag file present
   - Display: ⚠️  Internal data detected (orange)
   - Action: Offers cleanup options when mounting

4. **No Data** (`none`)
   - Container is empty
   - Display: ⚠️ No data (gray)

#### Flag Management

**Automatic flag management:**
- Created when switching to internal storage
- Deleted when switching back to external storage
- Checked before all mount operations

**Individual Volume Control:**
- Intentional internal: Refuses to mount, guides to storage switch
- Contaminated: Offers cleanup options with default recommendation

**Batch Mount All:**
- Intentional internal: Shows "⚠️  This volume is locked" (not counted as failure)
- Contaminated: Shows "❌ Mount failed: Data exists in internal storage"
- Summary displays: "Success: X / Failed: Y / Locked: Z"

#### Cleanup Options for Contaminated Data

When contaminated internal data is detected:
```
⚠️  Unintended data detected in internal storage

Select processing method:
  1. Prioritize external volume (delete internal data) [Recommended - Default]
  2. Cancel (do not mount)

Selection (1-2) [Default: 1]:
```

---

## ⚠️ Important Notes

### Requirements
- Apple Silicon Mac (M1/M2/M3/M4 series)
- macOS Sequoia 15.1 (Tahoe 26.0.1) or later
- Full Disk Access permission (Terminal.app)
- External storage (USB/Thunderbolt/SSD)

### Recommendations
- Always mount volumes before using PlayCover
- Always unmount volumes before Mac shutdown
- Run "Eject Entire Disk" before physically removing external storage
- **When external drive disconnected**: PlayCover.app cannot launch due to symbolic link (normal behavior)

### Troubleshooting
- **Volume not found**: Volume Management → Status Check
- **Mount error**: Volume Management → Individual Control for remount
- **Appears on desktop**: Unmount existing mount and remount
- **App won't launch**: Verify volume is properly mounted
- **Can't launch PlayCover**: Verify external storage is connected
- **Data in internal storage**: Unmount PlayCover volume and delete internal data
- **🔥 All apps crashing**: Run nuclear cleanup (see `docs/guides/NUCLEAR_CLEANUP_GUIDE.md`)
- **Crashes after remounting external volume**: Use nuclear cleanup to completely delete old data on external volume

---

## 📂 Project Structure

```
webapp/
├── 0_PlayCover-ManagementTool.command     # Main integrated tool (Japanese)
├── 0_PlayCover-ManagementTool-EN.command  # English version (in development)
├── README.md                               # Japanese documentation
├── README-EN.md                            # This file (English documentation)
├── CHANGELOG.md                            # Detailed update history
├── docs/                                   # Documentation
│   ├── archive/                            # Old bug fixes and change history
│   ├── guides/                             # User guides
│   └── development/                        # Development documentation
├── debug/                                  # Debug tools and log files
└── archive/                                # Old releases and backups
```

---

## 🔄 Update History (Recent Major Versions)

### v4.33.3 (Latest) - Fixed Batch Mount Error Message for Locked Volumes
- 🔧 **Fixed batch mount error message**: Shows correct message for intentional internal storage mode volumes
  * Before: "❌ Mount failed: Data exists in internal storage"
  * After: "⚠️ This volume is locked"
- 📊 **Added locked volume counter**: Added "Locked" count to batch mount results
  * Display example: "ℹ️  Success: 2 / Failed: 0 / Locked: 1"
  * Locked volumes are not counted as failures
- 🎯 **Integrated storage mode detection**: Uses `get_storage_mode()` for consistent behavior
  * `internal_intentional`: Shows locked message, skips mount
  * `internal_contaminated`: Shows contamination error message, skips mount
  * Others: Normal mount processing
- ✅ **Consistency with individual operations**: Uses same detection logic as individual volume control

### v4.33.2 - Enhanced Storage Switch UI with Mode Detection
- 🎨 **Enhanced storage switch UI**: Clear storage mode display
  * 🔌 External storage mode (blue)
  * 🏠 Internal storage mode (green)
  * ⚠️  Internal data detected (orange)
  * ⚠️ No data (gray)
- 📊 **Improved capacity display**: Appropriate capacity info for each mode
  * External/Internal: Used space + Free space
  * Contaminated: Internal storage free space only
  * No data: N/A display
- 🎯 **At-a-glance status**: Icons, colors, and labels for better UX

### v4.33.1 - Fixed Individual Volume Control Storage Mode Detection
- 🔧 **Fixed individual volume operations**: Correctly uses flag system
  * Uses `get_storage_mode()` detection to distinguish intentional vs contaminated
  * Intentional internal: Refuses mount, shows storage switch guidance
  * Contaminated data: Offers cleanup method choices

### v4.33.0 - Internal Storage Flag System for Contamination Detection
- 🚩 **Internal storage flag system**: Distinguishes intentional switch vs unintended contamination
  * Flag file: `.playcover_internal_storage_flag`
  * Automatically created on intentional switch, deleted on return to external
  * Different handling based on flag presence
- 🔒 **Intentional internal storage mode**:
  * With flag = Displayed and locked as "🔒 Internal storage mode"
  * Refuses mount operation (guides to switch feature to return to external)
  * Prevents accidental mounting and data conflicts
- ⚠️ **Unintended contamination detection**:
  * Without flag = Warning display as "⚠️ Internal data detected (unmounted)"
  * Confirms processing method on mount (selectable)
  * Default: Prioritize external (delete internal data) ← **Recommended**
- 📋 **Mount processing choices**:
  ```
  1. Prioritize external volume (delete internal data) [Recommended - Default]
  2. Cancel (do not mount)
  ```
- 🎯 **Use cases**:
  * PlayCover unmounted launch → Creates contamination data in internal → Detects and handles appropriately
  * Storage switch to internal → Creates flag → Prevents mount misoperation
  * Return to external → Deletes flag → Returns to normal external storage mode
- 🛡️ **Data protection**:
  * Complete prevention of mount misoperation in intentional internal mode
  * Contamination data not deleted without confirmation, user selectable
  * Default selection allows safe processing with just Enter key

### v4.32.0 - Eye-Friendly Colors with Reduced Brightness & Saturation
- 👁️ **Human color perception considered**: Balance of reduced glare and visibility
- 🎨 **All colors adjusted**: Changed to eye-friendly colors with reduced brightness and saturation
  * Soft White (WHITE) - #E6E6E6 (17.5:1) - Adjusted from pure white, significantly reduced glare
  * Light Gray (LIGHT_GRAY) - #B4B4B4 (9.8:1) - For standard text
  * Medium Gray (GRAY) - #8C8C8C (5.8:1) - For supplementary info, enhanced visibility (brighter than before)
  * Dark Gray (DIM_GRAY) - #6E6E6E (4.6:1) - Minimum contrast
  * Soft Red (RED) - #FF7878 (9.5:1) - Reduced saturation red
  * Soft Green (GREEN) - #78DC78 (11.8:1) - From bright green to natural green
  * Soft Blue (BLUE) - #78B4F0 (10.2:1) - Gentle blue
  * Soft Yellow (YELLOW) - #E6DC64 (14.5:1) - Reduced glare
  * Soft Cyan (CYAN) - #64DCDC (12.2:1) - Reduced saturation
  * Soft Magenta (MAGENTA) - #DC78DC (9.8:1) - Gentle purple
- 🔧 **Removed DIM + GRAY doubling**: Fixed overly dark display
  * Volume info "unmounted" display: `${DIM}${GRAY}` → `${GRAY}`
  * App list version display: `${DIM}${GRAY}(v1.4.0)` → `${GRAY}(v1.4.0)`
  * Bundle ID display: `${DIM}${GRAY}Bundle ID:` → `${GRAY}Bundle ID:`
  * Capacity separator: `${DIM}${GRAY}/` → `${GRAY}/`
- 🌿 **Natural extended colors**: Natural tones that don't tire eyes even with long use
  * Natural Orange #F0A064 (10.5:1)
  * Natural Gold #E6C864 (13.8:1)
  * Natural Lime #A0DC64 (12.5:1)
  * Natural Sky #78BEE6 (10.8:1)
  * Natural Turquoise #64C8C8 (11.2:1)
  * Natural Violet #C88CE6 (8.9:1)
  * Natural Pink #E68CB4 (9.5:1)
  * Natural Light Green #8CDC8C (12.8:1)
- ✅ **Enhanced visibility**: Changed dark gray (#969696) to medium gray (#8C8C8C), clarifying distinction from background
- 😌 **Long-term use support**: Design with reduced glare while keeping necessary information clearly visible

---

## 📝 License

This tool is provided as-is for managing PlayCover external storage. Use at your own risk.

---

## 🙏 Acknowledgments

- PlayCover community for the excellent iOS app compatibility layer
- Homebrew project for package management
- Apple Silicon Mac users providing feedback and testing

---

## 📞 Support

For issues, questions, or contributions:
1. Check the troubleshooting section above
2. Review the documentation in `docs/` directory
3. Check existing issues in the repository
4. Create a new issue with detailed information about your problem

---

**Last Updated**: 2025-01-28
**Version**: 4.33.3
