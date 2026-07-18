#!/bin/bash

# ========================================
# Tmux Project Module
# ========================================
# This module handles project-specific tmux operations
# Usage: source modules/tmux/project.sh

# Function to check if project is running
# Uses the per-render pane snapshot when valid (no tmux call); falls back to
# a live query otherwise.
is_project_running() {
    local display_name="$1"

    if [ "$_pane_snapshot_valid" = 1 ]; then
        [[ -n "${_pane_snapshot[$display_name]:-}" ]]
        return
    fi

    local pane_id
    pane_id=$(get_project_pane "$display_name")
    [[ -n "$pane_id" ]]
}

# Function to start project in new tmux pane
start_project_in_tmux() {
    local display_name="$1"
    local folder_name="$2"
    local startup_command="$3"

    # Determine the project directory (absolute or relative path)
    local project_dir
    if [[ "$folder_name" = /* ]]; then
        # Absolute path - use directly
        project_dir="$folder_name"
    else
        # Relative path - prepend PWD
        project_dir="$PWD/$folder_name"
    fi

    # Check if folder exists
    if [ ! -d "$project_dir" ]; then
        print_error "Project folder '$project_dir' not found"
        return 1
    fi

    print_info "Starting $display_name in new tmux pane..."

    # Count existing project panes (excluding the main menu pane)
    local project_pane_count
    project_pane_count=$(tmux list-panes -t "$SESSION_NAME" -F "#{pane_id}" 2>/dev/null | grep -v "^$(get_menu_pane_id)$" | wc -l)

    local new_pane_id
    if [[ "$project_pane_count" -eq 0 ]]; then
        # First project: create below the main menu (vertical split)
        new_pane_id=$(tmux split-window -v -t "$SESSION_NAME:0.0" -c "$project_dir" -P -F "#{pane_id}")
    else
        # Subsequent projects: split horizontally from the last project pane
        local last_project_pane
        last_project_pane=$(tmux list-panes -t "$SESSION_NAME" -F "#{pane_id}" 2>/dev/null | grep -v "^$(get_menu_pane_id)$" | tail -n1)
        new_pane_id=$(tmux split-window -h -t "$last_project_pane" -c "$project_dir" -P -F "#{pane_id}")
    fi

    # Set pane title FIRST (important!)
    tmux select-pane -t "$new_pane_id" -T "$display_name"

    # Send the startup command to the new pane
    tmux send-keys -t "$new_pane_id" "$startup_command" Enter

    # Apply main-horizontal layout to keep manager on top and projects evenly distributed below
    # Set main pane to 60% height so projects get 40%
    tmux set-window-option -t "$SESSION_NAME" main-pane-height 60%
    tmux select-layout -t "$SESSION_NAME" main-horizontal

    # Switch back to the main pane (menu pane)
    tmux select-pane -t "$SESSION_NAME:0.0"

    return 0
}
