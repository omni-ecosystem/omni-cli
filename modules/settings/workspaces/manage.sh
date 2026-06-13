#!/bin/bash

# ========================================
# Workspaces Manage Module
# ========================================
# Handles workspace management operations
# Usage: source modules/settings/workspaces/manage.sh

# Function to manage a specific workspace (add projects, etc.)
# Parameters: workspace_file, restricted_mode (optional)
manage_workspace() {
    local workspace_file="$1"
    local restricted_mode="${2:-false}"
    local display_name
    format_workspace_display_name_ref "$workspace_file" display_name

    while true; do
        # Get projects root for this workspace
        local projects_root=$(get_workspace_projects_folder "$workspace_file")

        if [ -z "$projects_root" ]; then
            clear
            print_header "Manage Workspace: $display_name"
            echo ""
            print_error "Could not determine projects folder for this workspace"
            wait_for_enter
            return 1
        fi

        # Count and display projects
        local workspace_projects=()
        parse_workspace_projects "$workspace_file" workspace_projects
        local project_count=${#workspace_projects[@]}

        # Show header
        show_workspace_management_header "$display_name" "$projects_root" "$project_count"

        # Display projects
        display_projects_list workspace_projects "$workspace_file" "$projects_root"

        # Show commands
        show_workspace_management_commands "$project_count" "$restricted_mode"

        # Get user input
        printf '\033[?25h'  # Show cursor for input
        echo -ne "${BRIGHT_CYAN}>${NC} "
        read_with_instant_back choice

        # Handle back command
        if [[ $choice =~ ^[Bb]$ ]]; then
            return 0
        fi

        # Handle add project command
        if [[ $choice =~ ^[Aa]$ ]]; then
            add_project_to_workspace "$workspace_file" "$projects_root"
            continue
        fi

        # Handle edit project commands (e1, e2, etc.) - blocked in restricted mode
        if [[ $choice =~ ^[Ee]([0-9]+)$ ]]; then
            if [[ "$restricted_mode" == true ]]; then
                print_error "Cannot edit projects while projects are running"
                sleep 1
                continue
            fi
            local project_choice="${BASH_REMATCH[1]}"
            if [ "$project_choice" -ge 1 ] && [ "$project_choice" -le "$project_count" ]; then
                local project_index=$((project_choice - 1))
                edit_project_in_workspace "$workspace_file" "$project_index"
            fi
            continue
        fi

        # Handle rename workspace command
        if [[ $choice =~ ^[Rr]$ ]]; then
            rename_workspace "$workspace_file" "$display_name"
            if [ -n "$RENAMED_WORKSPACE_FILE" ] && [ -f "$RENAMED_WORKSPACE_FILE" ]; then
                workspace_file="$RENAMED_WORKSPACE_FILE"
                format_workspace_display_name_ref "$workspace_file" display_name
            fi
            continue
        fi

        # Handle remove project commands (x1, x2, etc.) - blocked in restricted mode
        if [[ $choice =~ ^[Xx]([0-9]+)$ ]]; then
            if [[ "$restricted_mode" == true ]]; then
                print_error "Cannot remove projects while projects are running"
                sleep 1
                continue
            fi
            local project_choice="${BASH_REMATCH[1]}"
            if [ "$project_choice" -ge 1 ] && [ "$project_choice" -le "$project_count" ]; then
                local project_index=$((project_choice - 1))
                remove_project_from_workspace "$workspace_file" "$project_index"
            fi
            continue
        fi

        # Handle secure files commands (v1, v2, etc.)
        if [[ $choice =~ ^[Vv]([0-9]+)$ ]]; then
            local project_choice="${BASH_REMATCH[1]}"
            if [ "$project_choice" -ge 1 ] && [ "$project_choice" -le "$project_count" ]; then
                local project_index=$((project_choice - 1))
                local project_info="${workspace_projects[$project_index]}"
                IFS=':' read -r display_name project_name startup_cmd shutdown_cmd <<< "$project_info"
                local project_path="${projects_root}/${project_name}"
                show_secure_files_flow "$workspace_file" "$display_name" "$project_path"
            fi
            continue
        fi

        # Handle delete workspace command - blocked in restricted mode
        if [[ $choice =~ ^[Dd]$ ]]; then
            if [[ "$restricted_mode" == true ]]; then
                print_error "Cannot delete workspace while projects are running"
                sleep 1
                continue
            fi
            if delete_workspace "$workspace_file"; then
                return 0  # Exit to settings menu
            fi
            continue
        fi
    done
}
