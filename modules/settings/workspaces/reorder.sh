#!/bin/bash

# ========================================
# Workspaces Reorder Module
# ========================================
# Handles reordering workspaces in the settings list. Workspace order drives
# the section order on the main project manager screen.
# Usage: source modules/settings/workspaces/reorder.sh

# Function to interactively reorder the workspace list
# Reorders .availableConfigs (what the settings screen lists), then re-derives
# .activeConfig from it so the main menu follows the same order.
# Nothing is written until the move is confirmed - Esc leaves the file untouched
reorder_workspaces() {
    local workspaces=()
    if ! get_available_workspaces workspaces; then
        print_error "Could not read workspace list"
        sleep 1
        return 0
    fi

    local config_dir=$(get_config_directory)

    # Plain-text labels - the reorder component does all the colouring
    local labels=()
    local workspace_basename
    for workspace_basename in "${workspaces[@]}"; do
        local workspace_file="$config_dir/$workspace_basename"

        local display_name
        format_workspace_display_name_ref "$workspace_file" display_name

        local workspace_projects=()
        parse_workspace_projects "$workspace_file" workspace_projects

        # Marker instead of colour - every non-cursor row renders dimmed
        local active_marker="○"
        is_workspace_active "$workspace_file" && active_marker="●"

        labels+=("${active_marker} ${display_name} (${#workspace_projects[@]} projects)")
    done

    local moved_from moved_to
    if ! reorder_list_interactive labels "Reorder Workspaces" moved_from moved_to; then
        return 0
    fi

    local workspaces_file=$(get_workspaces_file_path)

    # Splice availableConfigs, then rebuild activeConfig as availableConfigs
    # filtered to the still-active set - that keeps both arrays in one order.
    if json_update_file "$workspaces_file" \
        ".availableConfigs = (.availableConfigs | ${REORDER_SPLICE_FILTER}) |
         .activeConfig = (.activeConfig as \$active |
                          .availableConfigs | map(select(. as \$w | \$active | index(\$w))))" \
        --argjson from "$moved_from" --argjson to "$moved_to"; then
        # The settings render snapshot is now stale
        invalidate_active_ws_snapshot
        return 0
    fi

    print_error "Failed to update workspace list"
    wait_for_enter
    return 1
}
