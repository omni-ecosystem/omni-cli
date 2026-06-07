#!/bin/bash

# Detect if running from installed location or development directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Determine installation type first
if [[ "$SCRIPT_DIR" == *"/usr/lib/"* ]]; then
    export IS_INSTALLED=true
    # For installed, BASE_DIR is the script directory
    export BASE_DIR="$SCRIPT_DIR"
else
    export IS_INSTALLED=false
    export BASE_DIR="$(dirname "${BASH_SOURCE[0]}")"
fi
export ECOSYSTEM="$HOME/.omni-ecosystem"

# Load .env early to get project variables
if [ -f "$BASE_DIR/.env" ]; then
    source "$BASE_DIR/.env"
fi

# Project naming (from .env or defaults)
PROJECT_FOLDER_NAME="${PROJECT_FOLDER_NAME}"
PROJECT_DISPLAY_NAME="${PROJECT_DISPLAY_NAME}"

# Function to set up configuration paths
setup_config_paths() {
    # Load .env file if it exists
    if [ -f "$BASE_DIR/.env" ]; then
        source "$BASE_DIR/.env"
    fi
    
    # Set default values if not in .env
    SESSION_NAME="${SESSION_NAME}"
    
    # Set JSON_CONFIG_FOLDER based on installation type
    if [ "$IS_INSTALLED" = true ]; then
        # Installed: use user cache directory
        JSON_CONFIG_FOLDER="$HOME/.config/$PROJECT_FOLDER_NAME"
        if ! mkdir -p "$JSON_CONFIG_FOLDER" 2>/dev/null; then
            echo "Error: Failed to create cache directory: $JSON_CONFIG_FOLDER" >&2
            echo "Please check permissions or try running: mkdir -p $JSON_CONFIG_FOLDER" >&2
            exit 1
        fi
    else
        # Development: use relative to script directory
        JSON_CONFIG_FOLDER="$BASE_DIR/config"
        if ! mkdir -p "$JSON_CONFIG_FOLDER" 2>/dev/null; then
            echo "Error: Failed to create config directory: $JSON_CONFIG_FOLDER" >&2
            exit 1
        fi
    fi

    # Determine active configuration from .workspaces.json or fallback to default
    local workspaces_file="$JSON_CONFIG_FOLDER/.workspaces.json"
    if [ -f "$workspaces_file" ] && command -v jq >/dev/null 2>&1; then
        # Get the first active workspace from the activeConfig array
        local active_config=$(jq -r '.activeConfig[0] // empty' "$workspaces_file" 2>/dev/null)
        if [ -n "$active_config" ] && [ -f "$active_config" ]; then
            JSON_CONFIG_FILE="$active_config"
        fi
    fi
    
    # Export for use by other modules
    export BASE_DIR
    export PROJECT_FOLDER_NAME
    export PROJECT_DISPLAY_NAME
    export SESSION_NAME
    export JSON_CONFIG_FOLDER
    export JSON_CONFIG_FILE
}

check_ecosystem_deps() {
    local pkgs=(
        "omni-ui-kit|https://raw.githubusercontent.com/nickojs/omni-ui-kit/main/install.sh"
        "omni-navigator|https://raw.githubusercontent.com/omni-ecosystem/omni-navigator/refs/heads/main/install.sh"
        "omni-secrets|https://raw.githubusercontent.com/omni-ecosystem/omni-secrets/refs/heads/main/install.sh"
    )
    for entry in "${pkgs[@]}"; do
        local pkg="${entry%%|*}"
        local url="${entry##*|}"
        if [ ! -d "$ECOSYSTEM/$pkg" ]; then
            echo "Installing missing dependency: $pkg..."
            curl -fsSL "$url" | bash
        fi
    done
}

# Import all modules after setting up paths
setup_config_paths
check_ecosystem_deps
source "$ECOSYSTEM/omni-ui-kit/index.sh"
source "$BASE_DIR/modules/index.sh"

main() {
    # Check if already inside a tmux session
    if [ -n "$TMUX" ]; then
        # Already in tmux - load config and show menu
        load_config
        show_project_menu_tmux
    else
        # Not in tmux - create/attach to session
        check_tmux
        setup_tmux_session
        tmux attach-session -t "$SESSION_NAME"
    fi
}

main "$@"