#!/bin/bash

# ========================================
# Workspaces Toggle Module
# ========================================
# Handles toggling workspace active/inactive status
# Usage: source modules/settings/workspaces/toggle.sh

# Check if a workspace has any running projects
# Parameters: workspace_file
# Returns: 0 if any project is running, 1 if none
workspace_has_running_projects() {
    local workspace_file="$1"

    # Get all displayNames from workspace JSON
    local display_names
    display_names=$(jq -r '.[].displayName' "$workspace_file" 2>/dev/null)

    # Check each project
    while IFS= read -r display_name; do
        if [[ -n "$display_name" ]] && is_project_running "$display_name"; then
            return 0  # Has running project
        fi
    done <<< "$display_names"

    return 1  # No running projects
}

# Function to toggle workspace active/inactive status
# Parameters: workspace_file, restricted_mode (optional, kept for compatibility)
toggle_workspace() {
    local workspace_file="$1"
    local restricted_mode="${2:-false}"
    local display_name
    format_workspace_display_name_ref "$workspace_file" display_name

    # Check current state
    if is_workspace_active "$workspace_file"; then
        # Attempting to deactivate - check if THIS workspace has running projects
        if workspace_has_running_projects "$workspace_file"; then
            print_error "Cannot deactivate workspace '$display_name' while its projects are running"
            wait_for_enter
            return 1
        fi

        # Deactivate (no running projects in this workspace)
        if deactivate_workspace "$workspace_file"; then
            print_success "Workspace '$display_name' deactivated"
        else
            print_error "Failed to deactivate workspace"
        fi
    else
        # Activate - always allowed
        local projects_folder=$(get_workspace_projects_folder "$workspace_file")
        if [ -z "$projects_folder" ]; then
            projects_folder=$(dirname "$workspace_file")
        fi

        if activate_workspace "$workspace_file" "$projects_folder"; then
            print_success "Workspace '$display_name' activated"
        else
            print_error "Failed to activate workspace"
        fi
    fi

    return 0
}
