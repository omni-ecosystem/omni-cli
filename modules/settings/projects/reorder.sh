#!/bin/bash

# ========================================
# Projects Reorder Module
# ========================================
# Handles moving projects/commands up and down within a workspace
# Usage: source modules/settings/projects/reorder.sh

# Function to interactively reorder the projects in a workspace
# Nothing is written until the move is confirmed - Esc leaves the file untouched
# Parameters: workspace_file
reorder_workspace_projects() {
    local workspace_file="$1"

    local display_name
    format_workspace_display_name_ref "$workspace_file" display_name

    local entries=()
    parse_workspace_projects "$workspace_file" entries

    # Plain-text labels - the reorder component does all the colouring
    local labels=()
    local entry
    for entry in "${entries[@]}"; do
        IFS="$OMNI_FIELD_SEP" read -r proj_display proj_name proj_start proj_stop <<< "$entry"
        # Command entries have no folder - tag them instead of an empty parenthetical
        labels+=("${proj_display} (${proj_name:-command})")
    done

    local moved_from moved_to
    if ! reorder_list_interactive labels "Reorder Projects: $display_name" moved_from moved_to; then
        return 0
    fi

    if json_update_file "$workspace_file" "$REORDER_SPLICE_FILTER" \
        --argjson from "$moved_from" --argjson to "$moved_to"; then
        return 0
    fi

    print_error "Failed to update workspace file"
    wait_for_enter
    return 1
}
