#!/bin/bash

# ========================================
# Projects Add Module
# ========================================
# Handles adding projects and command entries to workspaces
# Usage: source modules/settings/projects/add.sh

# Function to add an entry (project or command) to a workspace
# Command entries have no project folder - they run in the workspace root.
# Stored as a project object with empty projectName (the command marker).
# Parameters: workspace_file, projects_root, entry_type ("project" default, or "command")
add_project_to_workspace() {
    local workspace_file="$1"
    local projects_root="$2"
    local entry_type="${3:-project}"

    # Set the JSON_CONFIG_FILE for utils functions
    export JSON_CONFIG_FILE="$workspace_file"
    export BACKUP_JSON=false

    clear

    local selected_folder=""
    if [ "$entry_type" = "command" ]; then
        print_header "Add Command to Workspace"
        echo ""
        echo -e "${DIM}Runs in: ${projects_root}${NC}"
        echo ""
    else
        print_header "Add Project to Workspace"

        # Scan and let user select a folder
        selected_folder=$(scan_and_display_available_folders "$projects_root")
        local scan_result=$?

        if [ $scan_result -ne 0 ] || [ -z "$selected_folder" ]; then
            unset JSON_CONFIG_FILE
            return 1
        fi

        # Show configuration screen
        show_project_configuration_screen "$selected_folder" "$projects_root"
    fi

    # Prompt for entry fields (empty folder name = command entry mode)
    local temp_config_file=$(mktemp)
    prompt_project_input_fields "$selected_folder" > "$temp_config_file"
    local prompt_result=$?

    # Handle ESC cancellation
    if [ $prompt_result -eq 2 ]; then
        rm -f "$temp_config_file"
        unset JSON_CONFIG_FILE
        return 1
    fi

    # Read the three lines from temp file
    local display_name startup_cmd shutdown_cmd
    {
        read -r display_name
        read -r startup_cmd
        read -r shutdown_cmd
    } < "$temp_config_file"
    rm -f "$temp_config_file"

    # Show confirmation screen
    show_project_confirmation_screen "$display_name" "$selected_folder" "$startup_cmd" "$shutdown_cmd"

    # Confirm
    if prompt_yes_no_confirmation "Add this ${entry_type} to workspace?"; then
        echo ""
        add_project_to_config "$display_name" "$selected_folder" "$projects_root" "$startup_cmd" "$shutdown_cmd"
    else
        echo ""
        print_info "Cancelled"
    fi

    unset JSON_CONFIG_FILE
    wait_for_enter
    return 0
}

# Function to add a command entry to a workspace
# Parameters: workspace_file, projects_root
add_command_to_workspace() {
    add_project_to_workspace "$1" "$2" "command"
}
