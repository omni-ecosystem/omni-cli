#!/bin/bash

# ========================================
# Setup Module
# ========================================
# This module handles initial setup for new installations
# Usage: source modules/config/setup.sh

# Get the script directory to make paths relative to script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to check if this is first-time setup (just checks, doesn't show UI)
is_first_time_setup() {
    local config_dir=$(get_config_directory)

    local workspaces_file="$config_dir/.workspaces.json"

    # Return 0 (true) if first time, 1 (false) if not
    if [ ! -f "$workspaces_file" ]; then
        return 0
    else
        return 1
    fi
}

# Function to initialize config for first-time setup
initialize_first_time_config() {
    local config_dir=$(get_config_directory)

    local workspaces_file="$config_dir/.workspaces.json"

    # Create empty workspaces config
    mkdir -p "$config_dir"
    echo '{"activeConfig": [], "projectsPath": "", "availableConfigs": [], "workspacePaths": {}}' > "$workspaces_file"
}

# Function to show first-time welcome screen (for use inside tmux)
show_first_time_welcome() {
    clear
    print_header "WELCOME"
    echo ""
    print_info "This appears to be your first time running $PROJECT_DISPLAY_NAME."
    print_info "You'll need to create at least one workspace to get started."
    echo ""
    print_color "$BRIGHT_CYAN" "Quick Start Guide:"
    echo "  ${BRIGHT_WHITE}1.${NC} Press ${BRIGHT_PURPLE}[s]${NC} to open Settings"
    echo "  ${BRIGHT_WHITE}2.${NC} Press ${BRIGHT_GREEN}[a]${NC} to Add a new workspace"
    echo "  ${BRIGHT_WHITE}3.${NC} Select the projects folder for your workspace"
    echo "  ${BRIGHT_WHITE}4.${NC} Add projects to your workspace"
    echo "  ${BRIGHT_WHITE}5.${NC} Start managing your projects!"
    echo ""
    print_color "$BRIGHT_CYAN" "Secrets Storage:"
    print_info "omni-secrets keeps your encrypted keys and passphrases on disk."
    local default_secrets_dir=$(get_config_directory)
    print_info "Browse to a folder and press space to use it, or press 'b' to keep the default (${default_secrets_dir})."
    echo ""
    print_color "$BRIGHT_YELLOW" "Press Enter to open the directory browser..."
    read -r
    show_interactive_browser "directory" "$HOME" "/home" "Select: Secrets Storage Directory"
    if [ -n "$SELECTED_PROJECTS_DIR" ]; then
        if set_secrets_data_dir "$SELECTED_PROJECTS_DIR"; then
            print_success "Secrets will be stored at: $SELECTED_PROJECTS_DIR"
        else
            print_error "Could not use that directory; using the default instead"
        fi
        unset SELECTED_PROJECTS_DIR
    fi
    echo ""
    print_color "$BRIGHT_YELLOW" "Press Enter to continue to the main menu..."
    read -r

    # Initialize config
    initialize_first_time_config
}
