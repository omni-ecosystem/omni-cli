#!/bin/bash

# ========================================
# Settings Commands Module
# ========================================
# This module handles settings menu command routing and processing
# Usage: source modules/settings/commands.sh

# Function to handle settings menu choices
handle_settings_choice() {
    local choice="$1"
    local restricted_mode="${2:-false}"

    # Handle back command
    if [[ $choice =~ ^[Bb]$ ]]; then
        return 1  # Return to previous menu
    fi

    # Handle help command
    if [[ $choice =~ ^[Hh]$ ]]; then
        show_settings_help
        return 0
    fi

    # Handle configure terminal command
    if [[ $choice =~ ^[Cc]$ ]]; then
        echo ""
        local config_dir=$(get_config_directory)
        local terminal_file="$config_dir/terminal"
        if [[ -f "$terminal_file" ]] && [[ -s "$terminal_file" ]]; then
            echo -e "Current terminal: ${BRIGHT_CYAN}$(< "$terminal_file")${NC}"
        else
            echo -e "No terminal configured"
        fi
        echo -ne "Enter terminal binary name (e.g. konsole, kgx): "
        local term_input
        read -r term_input
        if [[ -n "$term_input" ]]; then
            printf '%s' "$term_input" > "$config_dir/terminal"
            print_success "Terminal set to: $term_input"
        else
            print_warning "No input provided, terminal unchanged"
        fi
        wait_for_enter
        return 0
    fi

    # Handle secrets command - always available
    if [[ $choice =~ ^[Ss]$ ]]; then
        if ensure_secrets_loaded; then
            show_secrets_menu
        else
            print_error "Failed to load secrets module"
            wait_for_enter
        fi
        return 0
    fi

    # Handle add workspace command - blocked in restricted mode
    if [[ $choice =~ ^[Aa]$ ]]; then
        if [[ "$restricted_mode" == true ]]; then
            print_error "Cannot add workspaces while projects are running"
            sleep 1
            return 0
        fi
        show_add_workspace_screen
        return 0
    fi

    # Handle manage workspace commands (m1, m2, etc.) - allowed with restrictions
    if [[ $choice =~ ^[Mm]([0-9]+)$ ]]; then
        local workspace_choice="${BASH_REMATCH[1]}"
        handle_manage_workspace_command "$workspace_choice" "$restricted_mode"
        return 0
    fi

    # Handle toggle workspace commands (t1, t2, etc.) - allowed with restrictions
    if [[ $choice =~ ^[Tt]([0-9]+)$ ]]; then
        local workspace_choice="${BASH_REMATCH[1]}"
        handle_toggle_workspace_command "$workspace_choice" "$restricted_mode"
        return 0
    fi
}

# Function to handle manage workspace command with workspace number
handle_manage_workspace_command() {
    local workspace_choice="$1"
    local restricted_mode="${2:-false}"

    # Validate workspace number
    if [ "$workspace_choice" -lt 1 ] || [ "$workspace_choice" -gt "${#settings_workspaces[@]}" ]; then
        return 1
    fi

    # Get selected workspace
    local selected_index=$((workspace_choice - 1))
    local selected_workspace_basename="${settings_workspaces[selected_index]}"

    # Construct full path from config_dir and basename
    local config_dir=$(get_config_directory)
    local selected_workspace="$config_dir/$selected_workspace_basename"

    # Open workspace management screen
    manage_workspace "$selected_workspace" "$restricted_mode"

    return 0
}

# Function to handle toggle workspace command with workspace number
handle_toggle_workspace_command() {
    local workspace_choice="$1"
    local restricted_mode="${2:-false}"

    # Validate workspace number
    if [ "$workspace_choice" -lt 1 ] || [ "$workspace_choice" -gt "${#settings_workspaces[@]}" ]; then
        return 1
    fi

    # Get selected workspace
    local selected_index=$((workspace_choice - 1))
    local selected_workspace_basename="${settings_workspaces[selected_index]}"

    # Construct full path from config_dir and basename
    local config_dir=$(get_config_directory)
    local selected_workspace="$config_dir/$selected_workspace_basename"

    # Toggle the workspace - pass restricted_mode flag
    toggle_workspace "$selected_workspace" "$restricted_mode"

    return 0
}
