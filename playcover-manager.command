#!/bin/zsh
#######################################################
# PlayCover Manager
# macOS Sequoia 15.1+ Compatible
# Version: 5.2.0
#######################################################

#######################################################
# Single Instance Check
#######################################################

# Check if already running by process name
if pgrep -f "playcover-manager.command" | grep -v $$ >/dev/null 2>&1; then
    # Already running - activate Terminal
    osascript <<'EOF' 2>/dev/null
tell application "Terminal"
    activate
    repeat with w in windows
        if (name of w) contains "PlayCover" then
            set index of w to 1
            exit repeat
        end if
    end repeat
end tell
EOF
    exit 0
fi

#######################################################
# Launch Application
#######################################################

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Execute main.sh (which loads all modules and runs the application)
exec "${SCRIPT_DIR}/main.sh"
