#!/bin/bash

# ========================================
# Modules Index
# ========================================
# Main entry point for all business logic modules
# This file imports and makes available all module functions
# Usage: source modules/index.sh

# Get the directory where this script is located
MODULES_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Import all modules in dependency order
source "$MODULES_DIR/config/index.sh"     # Configuration and JSON parsing
source "$MODULES_DIR/tmux/index.sh"       # Tmux session management
source "$MODULES_DIR/ui/table.sh"         # Shared table UI components
source "$ECOSYSTEM/omni-navigator/index.sh" # Filesystem navigation
source "$MODULES_DIR/docs.sh"             # Help documentation screens
source "$MODULES_DIR/menu/index.sh"       # Interactive menu system
source "$MODULES_DIR/settings/index.sh"   # Settings menu and configuration management

# Export a function to verify modules are loaded
modules_loaded() {
    echo "✓ Business logic modules loaded successfully"
    echo "  - Config: $(type load_config &>/dev/null && echo "✓" || echo "✗")"
    echo "  - Tmux: $(type check_tmux &>/dev/null && echo "✓" || echo "✗")"
    echo "  - Navigator: $(type show_path_selector &>/dev/null && echo "✓" || echo "✗")"
    echo "  - Menu: $(type show_project_menu_tmux &>/dev/null && echo "✓" || echo "✗")"
    echo "  - Settings: $(type show_settings_menu &>/dev/null && echo "✓" || echo "✗")"

    # Also check config sub-modules
    if type config_modules_loaded &>/dev/null; then
        echo ""
        config_modules_loaded
    fi

    # Also check tmux sub-modules
    if type tmux_modules_loaded &>/dev/null; then
        echo ""
        tmux_modules_loaded
    fi

    # Also check navigator sub-modules
    if type navigator_modules_loaded &>/dev/null; then
        echo ""
        navigator_modules_loaded
    fi

    # Also check menu sub-modules
    if type menu_modules_loaded &>/dev/null; then
        echo ""
        menu_modules_loaded
    fi

    # Also check settings sub-modules
    if type settings_modules_loaded &>/dev/null; then
        echo ""
        settings_modules_loaded
    fi
}
