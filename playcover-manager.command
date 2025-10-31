#!/bin/zsh
#######################################################
# PlayCover Manager
# macOS Sequoia 15.1+ Compatible
# Version: 5.2.0
#######################################################

#######################################################
# Single Instance Lock
#######################################################

# Lock file location
LOCK_FILE="${TMPDIR:-/tmp}/playcover-manager.lock"
LOCK_PID_FILE="${TMPDIR:-/tmp}/playcover-manager.pid"

# Check if already running
if [[ -f "$LOCK_FILE" ]]; then
    # Read the PID from lock file
    if [[ -f "$LOCK_PID_FILE" ]]; then
        EXISTING_PID=$(cat "$LOCK_PID_FILE" 2>/dev/null)
        
        # Check if the process is actually running
        if kill -0 "$EXISTING_PID" 2>/dev/null; then
            # Process is running - bring Terminal to front and exit
            osascript <<EOF 2>/dev/null
tell application "Terminal"
    activate
end tell
EOF
            exit 0
        else
            # Stale lock file - remove it
            rm -f "$LOCK_FILE" "$LOCK_PID_FILE"
        fi
    fi
fi

# Create lock file with current PID
echo $$ > "$LOCK_PID_FILE"
touch "$LOCK_FILE"

# Clean up lock on exit
cleanup_lock() {
    rm -f "$LOCK_FILE" "$LOCK_PID_FILE"
}

trap cleanup_lock EXIT INT TERM

#######################################################
# Launch Application
#######################################################

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Execute main.sh (which loads all modules and runs the application)
exec "${SCRIPT_DIR}/main.sh"
