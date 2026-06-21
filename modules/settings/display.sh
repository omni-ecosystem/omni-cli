#!/bin/bash

# ========================================
# Settings Menu Display Module
# ========================================
# This module handles settings menu display and UI functionality
# Usage: source modules/settings/display.sh

# Global array to store available workspaces for command routing
declare -a settings_workspaces=()

# Interactive settings menu with command handling
show_settings_menu() {
    # Check if any projects are running - determines restricted mode
    local running_projects
    running_projects=$(list_project_panes)

    local restricted_mode=false
    if [[ -n "$running_projects" ]]; then
        restricted_mode=true
    fi

    while true; do
        printf '\033[?25l'  # Hide cursor during redraw
        clear
        print_header "Settings"

        # Show restricted mode indicator if applicable
        if [[ "$restricted_mode" == true ]]; then
            echo -e "${BRIGHT_YELLOW}(Restricted Mode - projects running)${NC}"
        fi

        # Display workspaces from .workspaces.json (also populates settings_workspaces)
        display_workspaces_info

        # Build and display menu commands
        local ws_count=${#settings_workspaces[@]}

        echo ""
        if [[ "$restricted_mode" == true ]]; then
            menu_line \
                "$(menu_num_cmd 't' "$ws_count" 'toggle workspace' "$MENU_COLOR_EDIT")" \
                "$(menu_num_cmd 'm' "$ws_count" 'manage workspace' "$MENU_COLOR_ADD")" \
                "$(menu_cmd 'c' 'configure terminal' "$MENU_COLOR_EDIT")" \
                "$(menu_cmd 's' 'secrets' "$MENU_COLOR_NAV")" \
                "$(menu_cmd 'b' 'back' "$MENU_COLOR_NAV")" \
                "$(menu_cmd 'h' 'help' "$MENU_COLOR_NAV")"
        else
            menu_line \
                "$(menu_cmd 'a' 'add workspace' "$MENU_COLOR_ADD")" \
                "$(menu_num_cmd 'm' "$ws_count" 'manage workspace' "$MENU_COLOR_ADD")" \
                "$(menu_num_cmd 't' "$ws_count" 'toggle workspace' "$MENU_COLOR_EDIT")" \
                "$(menu_cmd 'c' 'configure terminal' "$MENU_COLOR_EDIT")" \
                "$(menu_cmd 's' 'secrets' "$MENU_COLOR_NAV")" \
                "$(menu_cmd 'b' 'back' "$MENU_COLOR_NAV")" \
                "$(menu_cmd 'h' 'help' "$MENU_COLOR_NAV")"
        fi
        echo ""

        # Get user input with better prompt
        printf '\033[?25h'  # Show cursor for input
        echo -ne "${BRIGHT_CYAN}>${NC} "
        read_with_instant_back choice

        # Handle user input - pass restricted_mode flag
        handle_settings_choice "$choice" "$restricted_mode"
        local result=$?

        # Exit loop if back was selected
        if [ $result -eq 1 ]; then
            break
        fi
    done
}

# Function to display workspaces information
display_workspaces_info() {
    local config_dir=$(get_config_directory)
    local workspaces_file="$config_dir/.workspaces.json"

    # Reset global workspaces array
    settings_workspaces=()

    # Get all available workspaces
    local available_workspaces=()
    if [ ! -f "$workspaces_file" ] || ! get_available_workspaces available_workspaces || [ ${#available_workspaces[@]} -eq 0 ]; then
        echo ""
        echo -e "${WHITE}No workspaces configured.${NC}"
        echo ""
        echo -e "${DIM}Use ${BRIGHT_GREEN}a${NC} ${DIM}to add a workspace${NC}"
        echo ""
        return 0
    fi

    # Populate global array for command routing
    settings_workspaces=("${available_workspaces[@]}")

    # Pre-load vault assignments from ALL workspaces before rendering so that
    # projects shared across workspaces see each other's vault assignments
    reset_vault_cache
    for workspace_basename in "${available_workspaces[@]}"; do
        load_workspace_vaults "$config_dir/$workspace_basename"
    done

    echo ""

    local counter=1
    local display_name status_icon status_text vault_text

    for workspace_basename in "${available_workspaces[@]}"; do
        local workspace_file="$config_dir/$workspace_basename"

        # Use nameref functions (no subshells)
        format_workspace_display_name_ref "$workspace_file" display_name
        get_workspace_status_ref "$workspace_file" status_icon status_text

        # Parse projects from this workspace file
        local workspace_projects=()
        if command -v jq >/dev/null 2>&1 && [ -f "$workspace_file" ]; then
            while IFS= read -r line; do
                workspace_projects+=("$line")
            done < <(jq -r '.[] | "\(.displayName):\(.projectName):\(.relativePath):\(.startupCmd // ""):\(.shutdownCmd // "")"' "$workspace_file" 2>/dev/null)
        fi

        render_workspace_header "settings" "$display_name" "$counter" "$status_icon" "$status_text"

        # Display projects or empty message
        if [ ${#workspace_projects[@]} -eq 0 ]; then
            echo -e "   ${DIM}No projects configured${NC}"
        else
            render_table_header "settings"
            for project_info in "${workspace_projects[@]}"; do
                IFS=':' read -r project_display_name folder_name relative_path startup_cmd shutdown_cmd <<< "$project_info"

                # Use dash for empty values
                [[ -z "$startup_cmd" || "$startup_cmd" == "null" ]] && startup_cmd="-"
                [[ -z "$shutdown_cmd" || "$shutdown_cmd" == "null" ]] && shutdown_cmd="-"

                # Get vaults from cache (no subshell)
                get_project_vaults_ref "$relative_path" vault_text
                [[ -z "$vault_text" ]] && vault_text="-"

                # Render row (optimized, no subshells)
                render_settings_project_row "$project_display_name" "$folder_name" "$startup_cmd" "$shutdown_cmd" "$vault_text"
            done
        fi
        echo ""
        counter=$((counter + 1))
    done
}
 