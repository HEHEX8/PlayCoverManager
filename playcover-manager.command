#!/bin/zsh
#######################################################
# PlayCover Manager
# macOS Sequoia 15.1+ Compatible
# Version: 5.2.0
#######################################################

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Execute main.sh (which loads all modules and runs the application)
# Single instance checking is handled by main.sh itself
exec "${SCRIPT_DIR}/main.sh"
