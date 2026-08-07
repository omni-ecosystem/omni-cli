#!/bin/bash

# ========================================
# Projects Remove Module
# ========================================
# Handles removing projects from workspaces
# Usage: source modules/settings/projects/remove.sh

# Function to remove a project from a workspace
# Parameters: workspace_file, project_index
remove_project_from_workspace() {
    local workspace_file="$1"
    local selected_index="$2"

    # Set the JSON_CONFIG_FILE for utils functions
    export JSON_CONFIG_FILE="$workspace_file"
    export BACKUP_JSON=false

    # Get selected project info
    local workspace_projects=()
    parse_workspace_projects "$workspace_file" workspace_projects
    local selected_project="${workspace_projects[selected_index]}"
    IFS="$OMNI_FIELD_SEP" read -r proj_display proj_name proj_start proj_stop <<< "$selected_project"

    clear
    print_header "Remove Project"
    echo ""
    echo -e "  ${BRIGHT_WHITE}${proj_display}${NC} ${DIM}(${proj_name})${NC}"
    echo ""
    echo -e "${DIM}Press Esc to cancel${NC}"
    echo ""

    # Confirm removal
    local confirm_result
    prompt_yes_no_confirmation "${BRIGHT_WHITE}Remove this project?${NC}"
    confirm_result=$?

    if [ $confirm_result -eq 0 ]; then
        if json_update_file "$workspace_file" "del(.[${selected_index}])"; then
            echo ""
            print_success "Project removed successfully"
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
