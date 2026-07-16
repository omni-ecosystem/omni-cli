#!/bin/bash

# ========================================
# Tmux Pane Module
# ========================================
# This module handles tmux pane management
# Usage: source modules/tmux/pane.sh

# Function to get the menu pane id of the current session (pane ids are
# server-global, so %0 is only the menu pane in the first session ever
# created on the server - the menu is always window 0, pane index 0)
get_menu_pane_id() {
    tmux display-message -p -t "$SESSION_NAME:0.0" '#{pane_id}' 2>/dev/null
}

# Function to get pane info for a specific project
get_project_pane() {
    local display_name="$1"
    local pane_id pane_title

    while IFS=':' read -r pane_id pane_title; do
        if [[ "$pane_title" == "$display_name" ]]; then
            echo "$pane_id"
            return 0
        fi
    done < <(tmux list-panes -t "$SESSION_NAME" -F "#{pane_id}:#{pane_title}" 2>/dev/null)

    return 1
}

# Function to kill a specific project pane
kill_project() {
    local display_name="$1"
    local shutdown_cmd="$2"
    local pane_id
    pane_id=$(get_project_pane "$display_name")

    if [[ -n "$pane_id" ]]; then
        tmux send-keys -t "$pane_id" C-c 2>/dev/null

        if [[ -n "$shutdown_cmd" ]] && [[ "$shutdown_cmd" != "null" ]]; then
            tmux send-keys -t "$pane_id" "$shutdown_cmd; tmux send-keys -t $SESSION_NAME:0.0 '' Enter; exit" Enter 2>/dev/null
        else
            tmux send-keys -t "$pane_id" "tmux send-keys -t $SESSION_NAME:0.0 '' Enter; exit" Enter 2>/dev/null
        fi
        return 0
    fi
    return 1
}

# Function to restart a project (kill process but keep pane, then re-run startup command)
restart_project() {
    local display_name="$1"
    local startup_command="$2"
    local shutdown_cmd="$3"

    local pane_id
    pane_id=$(get_project_pane "$display_name")

    if [[ -z "$pane_id" ]]; then
        return 1
    fi

    tmux send-keys -t "$pane_id" C-c 2>/dev/null

    if [[ -n "$shutdown_cmd" ]] && [[ "$shutdown_cmd" != "null" ]]; then
        tmux send-keys -t "$pane_id" "$shutdown_cmd; $startup_command" Enter 2>/dev/null
    else
        tmux send-keys -t "$pane_id" "$startup_command" Enter 2>/dev/null
    fi

    return 0
}

# Function to list all project panes
list_project_panes() {
    tmux list-panes -t "$SESSION_NAME" -F "#{pane_id}:#{pane_title}" 2>/dev/null | grep -v "^$(get_menu_pane_id):"
}

# Function to kill all project panes (except main menu)
kill_all_projects() {
    local pane_info
    mapfile -t pane_info < <(tmux list-panes -t "$SESSION_NAME" -F "#{pane_id}:#{pane_title}" 2>/dev/null | grep -v "^$(get_menu_pane_id):")

    for info in "${pane_info[@]}"; do
        IFS=':' read -r pane_id pane_title <<< "$info"

        # Find the shutdown command for this project
        local shutdown_cmd=""
        for i in "${!projects[@]}"; do
            IFS=':' read -r display_name folder_name startup_cmd project_shutdown_cmd <<< "${projects[i]}"
            if [[ "$display_name" == "$pane_title" ]]; then
                shutdown_cmd="$project_shutdown_cmd"
                break
            fi
        done

        tmux send-keys -t "$pane_id" C-c 2>/dev/null

        if [[ -n "$shutdown_cmd" ]] && [[ "$shutdown_cmd" != "null" ]]; then
            tmux send-keys -t "$pane_id" "$shutdown_cmd; tmux send-keys -t $SESSION_NAME:0.0 '' Enter; exit" Enter 2>/dev/null
        else
            tmux send-keys -t "$pane_id" "tmux send-keys -t $SESSION_NAME:0.0 '' Enter; exit" Enter 2>/dev/null
        fi
    done
}
