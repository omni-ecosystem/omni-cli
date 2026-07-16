#!/bin/bash

# ========================================
# Tmux Session Module
# ========================================
# This module handles tmux session management
# Usage: source modules/tmux/session.sh

# Tmux session name (use environment variable if set, otherwise default)
SESSION_NAME="${SESSION_NAME}"

# Function to create or attach to tmux session
setup_tmux_session() {
    # Check if session already exists (exact name match - tmux -t does prefix
    # matching by default, which would let a plain run grab a -local-* session)
    if tmux has-session -t "=$SESSION_NAME" 2>/dev/null; then
        # Session exists, just return (will attach in main)
        return 0
    fi

    # Create new session (detached) and start the menu in it
    local relaunch_cmd
    relaunch_cmd="$(printf '%q' "$0")"
    local new_session_args=(-d -s "$SESSION_NAME")
    if [ -n "$OMNI_LOCAL_CONFIG_DIR" ]; then
        # Forward --localConfig (path as typed) to the re-invocation inside tmux;
        # pin the start directory to where the user ran the script so the
        # relative path resolves the same in there
        new_session_args+=(-c "$PWD")
        relaunch_cmd+=" --localConfig=$(printf '%q' "$OMNI_LOCAL_CONFIG_DIR")"
    fi
    tmux new-session "${new_session_args[@]}" "$relaunch_cmd"

    # Configure session for better scrolling and usability
    tmux set-option -t "$SESSION_NAME" mouse on
    tmux set-option -t "$SESSION_NAME" history-limit 10000
    tmux set-option -t "$SESSION_NAME" mode-keys vi

    # Show project names on pane borders
    tmux set-option -t "$SESSION_NAME" pane-border-status top
    tmux set-option -t "$SESSION_NAME" pane-border-format " #{pane_title} "
}

# Function to check if tmux is available
check_tmux() {
    if ! command -v tmux &> /dev/null; then
        print_error "tmux is not installed. Please install tmux to use this script."
        exit 1
    fi
}
