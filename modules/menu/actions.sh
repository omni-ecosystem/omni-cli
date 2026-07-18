#!/bin/bash

# ========================================
# Menu Actions Module
# ========================================
# This module handles menu action implementations
# Usage: source modules/menu/actions.sh

# Helper function to temporarily switch workspace context for operations
with_workspace_context() {
    local workspace_file="$1"
    local callback_function="$2"
    shift 2  # Remove workspace_file and callback_function, rest are callback args

    # Save current context
    local original_json_config="$JSON_CONFIG_FILE"

    # Switch to target workspace
    export JSON_CONFIG_FILE="$workspace_file"

    # Execute callback with remaining arguments
    "$callback_function" "$@"
    local result=$?

    # Restore original context
    export JSON_CONFIG_FILE="$original_json_config"

    return $result
}

# Function to handle quit command
handle_quit_command() {
    echo ""
    show_loading "bye bye!" 1
    tmux kill-session
    exit 0
}


# Function to handle kill command with global project array
handle_kill_command() {
    local kill_choice="$1"

    if [ "$kill_choice" -ge 1 ] && [ "$kill_choice" -le "${#projects[@]}" ]; then
        local project_index=$((kill_choice - 1))
        IFS=':' read -r display_name folder_name startup_command shutdown_command <<< "${projects[$project_index]}"
        local workspace_file="${project_workspaces[$project_index]}"

        if is_project_running "$display_name"; then
            with_workspace_context "$workspace_file" kill_project "$display_name" "$shutdown_command"
        fi
    fi
}

# Function to handle restart command with global project array
handle_restart_command() {
    local restart_choice="$1"

    if [ "$restart_choice" -ge 1 ] && [ "$restart_choice" -le "${#projects[@]}" ]; then
        local project_index=$((restart_choice - 1))
        IFS=':' read -r display_name folder_name startup_command shutdown_command <<< "${projects[$project_index]}"

        if is_project_running "$display_name"; then
            restart_project "$display_name" "$startup_command" "$shutdown_command"
        fi
    fi
}

# Backwards-compatible entry point: single number is just a one-item batch.
handle_start_command() {
    handle_start_batch "$1"
}

# Starts a project by its 1-based menu number. No prints, no wait.
# Sets START_RESULT_NAME to the resolved display name (or "#N" when out of range).
# Returns: 0 started, 1 out-of-range, 2 already running, 3 start failed.
_start_project_core() {
    local choice="$1"

    if [ "$choice" -lt 1 ] || [ "$choice" -gt "${#projects[@]}" ]; then
        START_RESULT_NAME="#$choice"
        return 1
    fi

    local i=$((choice - 1))
    IFS=':' read -r display_name folder_name startup_command shutdown_command <<< "${projects[$i]}"
    START_RESULT_NAME="$display_name"

    if is_project_running "$display_name"; then
        return 2
    fi

    with_workspace_context "${project_workspaces[$i]}" \
        start_project_in_tmux "$display_name" "$folder_name" "$startup_command" >/dev/null 2>&1 \
        || return 3

    return 0
}

# Function to handle batch start ("1, 3, 5" / "1 3 5" / "1,3,5")
handle_start_batch() {
    local raw="$1"
    local -a nums=()
    local tok n seen

    # Split on comma/space, keep only numbers, dedupe preserving order
    for tok in ${raw//,/ }; do
        [[ "$tok" =~ ^[0-9]+$ ]] || continue
        seen=0
        for n in "${nums[@]}"; do
            [[ "$n" == "$tok" ]] && { seen=1; break; }
        done
        [[ $seen -eq 0 ]] && nums+=("$tok")
    done

    [ ${#nums[@]} -eq 0 ] && return

    local summary="${BRIGHT_WHITE}Run:${NC}"
    for tok in "${nums[@]}"; do
        _start_project_core "$tok"
        case $? in
            0) summary+=" ${BRIGHT_GREEN}✓${START_RESULT_NAME}${NC}" ;;
            1) summary+=" ${BRIGHT_RED}✗#${tok}${NC}" ;;               # out of range
            2) summary+=" ${DIM}⊘${START_RESULT_NAME}(running)${NC}" ;;
            3) summary+=" ${BRIGHT_RED}✗${START_RESULT_NAME}${NC}" ;;  # start failed
        esac
    done

    echo -e "\n$summary"
    sleep 1.5   # glanceable, no keypress; menu loop's clear() then redraws
}

# Function to handle settings command
handle_settings_command() {
    show_settings_menu
    # Reload configuration after returning from settings
    # This ensures the main menu reflects any changes made in settings
    reload_config
}

# Function to handle layout command
handle_layout_command() {
    show_layout_menu
    # Reload configuration after returning from layouts
    reload_config
}

# Function to handle kill all command
handle_kill_all_command() {
    # Check if there are any running projects
    local running_projects
    running_projects=$(list_project_panes)

    if [[ -z "$running_projects" ]]; then
        print_warning "No projects are currently running"
        wait_for_enter
        return
    fi

    kill_all_projects
}

# Function to handle help command
handle_help_command() {
    show_menu_help
}

# Function to handle custom command (open terminal in project folder)
handle_custom_command() {
    local choice="$1"

    if [ "$choice" -ge 1 ] && [ "$choice" -le "${#projects[@]}" ]; then
        local project_index=$((choice - 1))
        IFS=':' read -r display_name folder_name startup_command shutdown_command <<< "${projects[$project_index]}"

        # Check if folder exists
        if [ ! -d "$folder_name" ]; then
            print_error "Project folder '$folder_name' not found"
            wait_for_enter
            return 1
        fi

        print_info "Opening terminal for $display_name in $folder_name"

        local terminal_file="$(get_config_directory)/terminal"
        local terminal_emulator=""
        if [[ -f "$terminal_file" ]]; then
            terminal_emulator=$(< "$terminal_file")
        fi

        # No terminal configured
        if [[ -z "$terminal_emulator" ]]; then
            print_warning "No terminal configured. Use settings > configure terminal."
            wait_for_enter
            return 1
        fi

        # Verify binary exists
        if ! command -v "$terminal_emulator" >/dev/null 2>&1; then
            print_warning "Terminal '$terminal_emulator' not found on PATH"
            wait_for_enter
            return 1
        fi

        case "$terminal_emulator" in
            konsole)
                konsole --workdir="$folder_name" &
                ;;
            gnome-terminal|kgx|xfce4-terminal|lxterminal|terminator|alacritty|foot)
                "$terminal_emulator" --working-directory="$folder_name" &
                ;;
            kitty)
                kitty --directory="$folder_name" &
                ;;
            wezterm)
                wezterm start --cwd "$folder_name" &
                ;;
            xterm)
                (cd "$folder_name" && xterm) &
                ;;
            *)
                # Unknown terminal -- attempt generic --working-directory flag
                "$terminal_emulator" --working-directory="$folder_name" &
                ;;
        esac
        
        print_success "Terminal opened for $display_name"
        sleep 1
    else
        print_error "Please enter a number between 1 and ${#projects[@]}"
        wait_for_enter
    fi
}
