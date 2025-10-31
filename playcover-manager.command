#!/bin/zsh
#######################################################
# PlayCover Manager
# macOS Sequoia 15.1+ Compatible
# Version: 5.2.0
#
# Zsh Entry Point
#######################################################

# Get script directory
SCRIPT_DIR="${0:A:h}"

# Execute main.sh (which loads all modules and runs the application)
# Single instance checking is handled by main.sh itself
exec "${SCRIPT_DIR}/main.sh"
