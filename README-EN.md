# PlayCover Manager (CLI Version)

<div align="center">

![Version](https://img.shields.io/badge/version-5.0.0-blue.svg)
![Platform](https://img.shields.io/badge/platform-macOS%20Sequoia%2015.1%2B-lightgrey.svg)
![Architecture](https://img.shields.io/badge/architecture-Apple%20Silicon-orange.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

**APFS Volume Management Tool for PlayCover - Command Line Interface**

🌟 **[GUI Version (Super-evolved) Available Here](https://github.com/HEHEX8/PlayCoverManagerGUI)** 🌟

English | [日本語](README.md)

</div>

---

## 🎯 GUI Version Available!

**Based on this CLI version, a fully-featured superior GUI version has been developed:**

### 🌟 [PlayCover Manager GUI](https://github.com/HEHEX8/PlayCoverManagerGUI)

> **Project Evolution**: This is a complete reimplementation of all features from this CLI version (9,000+ lines of Zsh scripts) as a native SwiftUI application - a super-evolved version.

#### GUI Version Features:
- 🖥️ **Native SwiftUI Implementation** - Modern macOS app experience
- 🎨 **Intuitive Interface** - Visual and easy-to-understand operations
- ⚡ **High Performance** - Same performance as CLI version
- 🔄 **Real-time Updates** - Instant state change reflection
- 📊 **Visual Feedback** - Progress bars and animations
- 🚀 **One-Click Operations** - All features accessible from GUI

#### 🔄 Project Relationship and Implementation Differences:

| Aspect | CLI Version (This Repository) | GUI Version (Super-evolved) |
|--------|------------------------------|----------------------------|
| **Language** | Zsh (Shell Script) | Swift |
| **Framework** | - | SwiftUI |
| **UI** | Terminal (Text-based) | Native GUI |
| **Code Size** | 9,000+ lines | Complete reimplementation |
| **Architecture** | 8-module structure (Shell scripts) | MVVM + Swift Concurrency |
| **Data Persistence** | File system | UserDefaults + CoreData candidate |
| **Concurrency** | Subprocesses | async/await + Actor |
| **Error Handling** | exit code + trap | Swift Error Protocol |
| **Dependencies** | System commands (diskutil, rsync, etc.) | Foundation + AppKit/SwiftUI |
| **Distribution** | .command file | .app bundle |
| **Compatibility** | ❌ **None** (Completely independent) | ❌ **None** (Completely independent) |

> **Important**: CLI and GUI versions are **completely independent at the implementation level**. There is no code sharing or compatibility. The GUI version inherits the **concept and feature specifications** of the CLI version and is completely reimplemented from scratch in Swift/SwiftUI.

#### 📋 Detailed Implementation Differences:

**1. APFS Operations**
- **CLI Version**: Execute system commands like `diskutil apfs addVolume`, `diskutil mount/unmount` from shell
- **GUI Version**: Combination of `DiskArbitration.framework` and `diskutil` process execution, wrapped in Swift

**2. Data Transfer**
- **CLI Version**: Execute `rsync` via pipe, parse stdout for progress bar display
- **GUI Version**: `FileManager` + `rsync` process, monitor progress with async/await, display in SwiftUI

**3. State Management**
- **CLI Version**: Text-based mapping file (`~/.playcover_volumes`), read/write on each operation
- **GUI Version**: Swift Codable, ObservableObject pattern, reactive state management

**4. Volume Detection**
- **CLI Version**: Parse `diskutil list` output for state determination, with caching
- **GUI Version**: Real-time detection via `DiskArbitration` callbacks, Publisher pattern

**5. Error Handling**
- **CLI Version**: Exit-time cleanup with `set -e` and `trap`, stderr output
- **GUI Version**: Swift Error Protocol, Result type, structured concurrency

**6. UI Updates**
- **CLI Version**: Clear screen with `clear`, ANSI escape sequences for colors, complete redraw
- **GUI Version**: SwiftUI declarative UI, automatic updates on state changes, animations

**Common Ground**: Both versions share the same fundamental APFS operation logic (external volume creation, data transfer, symbolic link management).

**The GUI version is strongly recommended.** This CLI version is maintained for users who prefer command-line interfaces or developers interested in the original implementation.

---

## 🎉 v5.0.0 - Stable Release

The first stable release of PlayCover Manager is now available. All critical bugs have been fixed and it is ready for production use.

**Release Details**: [RELEASE_NOTES_v5.2.0.md](RELEASE_NOTES_v5.2.0.md)

---

## 📖 Overview

PlayCover Manager is a macOS command-line tool for migrating and managing iOS app data running on PlayCover to external storage. It automates APFS volume creation and mount management to save internal storage space.

### Key Features

- ✅ **External Storage Migration**: Safely move game data to external drives
- ✅ **Internal⇄External Switching**: One-click storage mode change
- ✅ **Batch Operations**: Bulk mount/unmount multiple volumes
- ✅ **Data Protection**: Capacity checks, running app checks, rsync synchronization
- ✅ **Complete Cleanup**: Safely delete all data (hidden option)

---

## 🚀 Quick Start

### Prerequisites

- macOS Sequoia 15.1 or later
- Apple Silicon Mac (M1/M2/M3/M4)
- PlayCover 3.0 or later
- External storage (APFS compatible)

### Installation

```bash
# Clone repository
git clone https://github.com/HEHEX8/PlayCoverManager.git
cd PlayCoverManager

# Grant execution permission
chmod +x playcover-manager.command

# Launch
./playcover-manager.command
```

### Initial Setup

1. Initial setup starts automatically when you launch the tool
2. Select external storage (USB/Thunderbolt/SSD)
3. APFS volume for PlayCover is created automatically
4. Main menu appears after setup completion

---

## 📚 Usage

### Main Menu

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  📱 PlayCover Volume Manager v5.0.0
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  1. App Management
  2. Volume Operations
  3. Storage Switch (Internal⇄External)
  4. Eject Disk
  0. Exit

Select (0-4):
```

### 1. App Management

- **IPA Install**: Bulk install multiple IPA files (with progress display)
- **Uninstall**: Delete apps and related volumes

### 2. Volume Operations

- **Mount All Volumes**: Bulk mount registered volumes
- **Unmount All Volumes**: Safely bulk unmount
- **Individual Operations**: Mount/unmount/remount specific volumes

### 3. Storage Switch

- **Internal → External**: Migrate internal data to external volume
- **External → Internal**: Move external data back to internal storage
- Includes capacity checks, running app checks, and data protection

### 4. Eject Disk

Safely eject external storage (unmounts all volumes)

---

## 🏗️ Architecture

### Module Structure

```
PlayCoverManager/
├── main.sh                    # Main entry point
├── playcover-manager.command  # GUI launcher script
├── lib/                       # Modules
│   ├── 00_core.sh            # Core functions & utilities
│   ├── 01_mapping.sh         # Mapping file management
│   ├── 02_volume.sh          # APFS volume operations
│   ├── 03_storage.sh         # Storage switching
│   ├── 04_app.sh             # App installation & management
│   ├── 05_cleanup.sh         # Cleanup functions
│   ├── 06_setup.sh           # Initial setup
│   └── 07_ui.sh              # UI & menu display
├── README.md                  # Japanese README
├── CHANGELOG.md               # Change history (old version)
└── RELEASE_NOTES_5.0.0.md    # v5.0.0 Release Notes
```

### Technical Details

- **Total Lines of Code**: 6,000+ lines
- **Number of Modules**: 8
- **Language**: Zsh (macOS standard shell)
- **Number of Functions**: 91
- **Testing**: Comprehensively verified

---

## 🐛 Bug Reports

If you find a bug, please create an Issue with the following information:

- macOS version
- Mac model (M1/M2/M3/M4)
- PlayCover version
- Steps to reproduce
- Error messages

---

## 📝 Known Limitations

1. **APFS Capacity Display**: Due to macOS specifications, capacity may appear different in Finder
   - The tool works correctly
   - Check actual effect in "Used" (top number) of Macintosh HD

2. **Intel Mac Not Supported**: Apple Silicon only

3. **PlayCover Dependency**: PlayCover must be installed

---

## 🔐 Security

- Uses sudo privileges only when absolutely necessary
- Multiple checks to prevent data corruption
- Confirmation prompts for destructive operations
- Safe data transfer via rsync

---

## 📜 License

MIT License

---

## 🙏 Acknowledgments

This tool was developed for users who enjoy iOS games on PlayCover.
All critical bugs have been fixed and it is ready for production use.

---

## 📮 Contact

- **GitHub**: [HEHEX8/PlayCoverManager](https://github.com/HEHEX8/PlayCoverManager)
- **Issues**: [Bug Reports](https://github.com/HEHEX8/PlayCoverManager/issues)

---

**Last Updated**: November 7, 2025 | **Version**: 5.2.0 (CLI)
