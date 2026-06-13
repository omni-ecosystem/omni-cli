#!/bin/bash

# ========================================
# Workspaces Delete Module
# ========================================
# Handles workspace deletion
# Usage: source modules/settings/workspaces/delete.sh

# Function to delete an empty workspace
# Parameters: workspace_file
# Returns: 0 if successful, 1 if error or cancelled
delete_workspace() {
    local workspace_file="$1"
    local display_name
    format_workspace_display_name_ref "$workspace_file" display_name

    # Show warning
    show_delete_workspace_warning "$display_name" "$workspace_file"

    echo -e "${DIM}Press Esc to cancel${NC}"
    echo ""

    local confirm_result
    prompt_yes_no_confirmation "Are you sure you want to delete this workspace?"
    confirm_result=$?

    if [ $confirm_result -eq 0 ]; then
        # Remove from configuration (both active and available)
        if unregister_workspace "$workspace_file"; then
            # Delete the workspace file
            if rm -f "$workspace_file" 2>/dev/null; then
                echo ""
                print_success "Workspace deleted successfully"
                wait_for_enter
                return 0
            else
                echo ""
                print_error "Failed to delete workspace file"
                wait_for_enter
                return 1
            fi
        else
            echo ""
            print_error "Failed to remove workspace from configuration"
            wait_for_enter
            return 1
        fi
    elif [ $confirm_result -eq 2 ]; then
        # Esc pressed - just return silently
        return 1
    else
        echo ""
        print_info "Cancelled"
        wait_for_enter
        return 1
    fi
}
