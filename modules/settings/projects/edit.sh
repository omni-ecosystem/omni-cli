#!/bin/bash

# ========================================
# Projects Edit Module
# ========================================
# Handles editing projects in workspaces
# Usage: source modules/settings/projects/edit.sh

# Function to edit a project in a workspace
# Parameters: workspace_file, project_index
edit_project_in_workspace() {
    local workspace_file="$1"
    local selected_index="$2"

    # Set the JSON_CONFIG_FILE for utils functions
    export JSON_CONFIG_FILE="$workspace_file"
    export BACKUP_JSON=false

    # Get selected project info
    local workspace_projects=()
    parse_workspace_projects "$workspace_file" workspace_projects
    local selected_project="${workspace_projects[selected_index]}"
    IFS="$OMNI_FIELD_SEP" read -r current_display current_name current_start current_stop <<< "$selected_project"

    # Show edit screen
    show_edit_project_screen "$current_display" "$current_start" "$current_stop"

    # Get new display name
    echo -e "${BRIGHT_WHITE}Enter new display name:${NC}"
    echo -ne "${DIM}(press Enter to keep '$current_display')${NC} ${BRIGHT_CYAN}>${NC} "
    local new_display
    read_with_esc_cancel new_display
    if [ $? -eq 2 ]; then
        unset JSON_CONFIG_FILE
        return 0
    fi

    if [ -z "$new_display" ]; then
        new_display="$current_display"
    fi

    # Get new startup command
    echo ""
    echo -e "${BRIGHT_WHITE}Enter new startup command:${NC}"
    echo -ne "${DIM}(press Enter to keep current)${NC} ${BRIGHT_CYAN}>${NC} "
    local new_startup
    read_with_esc_cancel new_startup
    if [ $? -eq 2 ]; then
        unset JSON_CONFIG_FILE
        return 0
    fi

    if [ -z "$new_startup" ]; then
        new_startup="$current_start"
    fi

    # Get new shutdown command
    echo ""
    echo -e "${BRIGHT_WHITE}Enter new shutdown command:${NC}"
    echo -ne "${DIM}(press Enter to keep current)${NC} ${BRIGHT_CYAN}>${NC} "
    local new_shutdown
    read_with_esc_cancel new_shutdown
    if [ $? -eq 2 ]; then
        unset JSON_CONFIG_FILE
        return 0
    fi

    if [ -z "$new_shutdown" ]; then
        new_shutdown="$current_stop"
    fi

    # Show confirmation screen with diff
    show_edit_project_confirmation_screen "$current_display" "$current_start" "$current_stop" "$new_display" "$new_startup" "$new_shutdown"

    local confirm_result
    prompt_yes_no_confirmation "Save changes?"
    confirm_result=$?

    if [ $confirm_result -eq 0 ]; then
        if json_update_file "$workspace_file" \
              ".[$selected_index].displayName = \$display_name | .[$selected_index].startupCmd = \$startup_cmd | .[$selected_index].shutdownCmd = \$shutdown_cmd" \
              --arg display_name "$new_display" \
              --arg startup_cmd "$new_startup" \
              --arg shutdown_cmd "$new_shutdown"; then
            echo ""
            print_success "Project updated successfully"
        else
            print_error "Failed to update workspace file"
        fi
        wait_for_enter
    elif [ $confirm_result -eq 2 ]; then
        # Esc pressed - just return silently
        unset JSON_CONFIG_FILE
        return 0
    else
        echo ""
        print_info "Cancelled"
        wait_for_enter
    fi

    unset JSON_CONFIG_FILE
    return 0
}
