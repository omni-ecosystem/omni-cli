#!/bin/bash

# ========================================
# Settings Module Index
# ========================================
# Main entry point for all settings modules
# This file imports and makes available all settings functions
# Usage: source modules/settings/index.sh

# Get the directory where this script is located
SETTINGS_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Import all settings modules
source "$SETTINGS_DIR/utils.sh"          # Configuration utilities (shared functions)
source "$SETTINGS_DIR/ui_helpers.sh"     # UI interaction helpers
source "$SETTINGS_DIR/state.sh"          # Workspace state management
source "$SETTINGS_DIR/workspaces/index.sh" # Workspace management operations
source "$SETTINGS_DIR/projects/index.sh" # Project management operations
source "$SETTINGS_DIR/display.sh"        # Settings menu display
source "$SETTINGS_DIR/commands.sh"       # Settings command handling

# Export a function to verify settings modules are loaded
settings_modules_loaded() {
    echo "✓ Settings modules loaded successfully"
    echo "  - Display: $(type show_settings_menu &>/dev/null && echo "✓" || echo "✗")"
    echo "  - Commands: $(type handle_settings_choice &>/dev/null && echo "✓" || echo "✗")"
}
