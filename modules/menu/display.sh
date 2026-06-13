#!/bin/bash

# ========================================
# Menu Display Module
# ========================================
# This module handles menu display and UI functionality
# Usage: source modules/menu/display.sh

# Function to display menu and start project (for tmux session)
show_project_menu_tmux() {
    # Check if this is first-time setup and show welcome screen
    if is_first_time_setup; then
        show_first_time_welcome
    fi

    while true; do
        printf '\033[?25l'  # Hide cursor during redraw
        clear

        # Clean header
        print_header "Project Manager"

        # Display workspaces
        display_workspaces

        # Commands section with better formatting and grouping
        echo ""

        local n=${#projects[@]}
        local has_running=$(list_project_panes)
        local layout_cmd=""
        [[ -z "$has_running" ]] && layout_cmd="$(menu_cmd 'l' 'layout' "$MENU_COLOR_OPEN")"

        menu_line \
            "$(menu_num_cmd '' "$n" 'start' "$MENU_COLOR_ADD")" \
            "$(menu_num_cmd 'c' "$n" 'terminal' "$MENU_COLOR_OPEN")" \
            "$(menu_num_cmd 'r' "$n" 'restart' "$MENU_COLOR_ACTION")" \
            "$(menu_num_cmd 'k' "$n" 'kill' "$MENU_COLOR_DELETE")" \
            "$([[ $n -gt 1 ]] && menu_cmd 'ka' 'kill all' "$MENU_COLOR_DELETE")" \
            "$layout_cmd" \
            "$(menu_cmd 's' 'settings' "$MENU_COLOR_NAV")" \
            "$(menu_cmd 'h' 'help' "$MENU_COLOR_NAV")" \
            "$(menu_cmd 'q' 'quit' "$MENU_COLOR_NAV")"

        # Get user input with clean prompt
        echo ""
        printf '\033[?25h'  # Show cursor for input
        echo -ne "${BRIGHT_CYAN}>${NC} "

        # Custom read: L is instant (when no projects running), others need Enter
        choice=""
        while true; do
            IFS= read -r -s -n 1 char

            # Enter - submit what we have
            if [[ -z "$char" ]]; then
                echo ""
                break
            fi

            # Backspace
            if [[ "$char" == $'\x7f' ]] || [[ "$char" == $'\x08' ]]; then
                if [[ -n "$choice" ]]; then
                    choice="${choice%?}"
                    echo -ne "\b \b"
                fi
                continue
            fi

            choice+="$char"
            echo -n "$char"

            # L is instant only when no projects running
            if [[ "$choice" =~ ^[Ll]$ ]] && [[ -z "$has_running" ]]; then
                echo ""
                break
            fi
        done

        # Handle user input
        handle_menu_choice "$choice"
    done
}

# Function to display workspaces and their projects with global numbering
display_workspaces() {
    # Check if any projects are loaded globally
    if [ ${#projects[@]} -eq 0 ]; then
        echo ""
        echo -e "${WHITE}No workspaces configured.${NC}"
        echo ""
        echo -e "${DIM}Configure workspaces in ${BRIGHT_PURPLE}s${NC} ${DIM}settings menu${NC}"
        echo ""
        return 0
    fi

    # Get active workspace files using shared component
    local workspace_files=()
    if ! get_workspace_files "active" workspace_files; then
        return 0
    fi

    local global_counter=1

    for workspace_file in "${workspace_files[@]}"; do
        local display_name
        format_workspace_display_name_ref "$workspace_file" display_name

        # Find projects belonging to this workspace
        local workspace_project_indices=()
        for i in "${!project_workspaces[@]}"; do
            if [[ "${project_workspaces[i]}" == "$workspace_file" ]]; then
                workspace_project_indices+=($i)
            fi
        done

        render_workspace_header "menu" "$display_name"

        # Display projects or empty message
        if [ ${#workspace_project_indices[@]} -eq 0 ]; then
            echo -e "  ${DIM}No projects configured${NC}"
        else
            render_table_header "menu"
            for j in "${!workspace_project_indices[@]}"; do
                local project_index=${workspace_project_indices[j]}
                IFS=':' read -r project_display_name folder_name startup_cmd shutdown_cmd <<< "${projects[project_index]}"

                # Get status using shared component
                local status_result=$(get_project_status "$project_display_name" "$folder_name")
                local status_text="${status_result%%|*}"
                local status_color="${status_result#*|}"

                # Render row
                render_menu_project_row "$global_counter" "$project_display_name" "$status_text" "$status_color"
                global_counter=$((global_counter + 1))
            done
        fi
        echo ""
    done
}

