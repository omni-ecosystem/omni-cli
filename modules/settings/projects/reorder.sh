#!/bin/bash

# ========================================
# Projects Reorder Module
# ========================================
# Handles moving projects/commands up and down within a workspace
# Usage: source modules/settings/projects/reorder.sh

# Function to interactively move a project within a workspace
# Nothing is written until Enter - Esc leaves the workspace file untouched
# Parameters: workspace_file, start_index (0-based)
reorder_project_in_workspace() {
    local workspace_file="$1"
    local from_index="$2"

    local display_name
    format_workspace_display_name_ref "$workspace_file" display_name

    # Load entries once - the loop reorders this array in memory for rendering
    local entries=()
    parse_workspace_projects "$workspace_file" entries
    local entry_count=${#entries[@]}

    if [ "$entry_count" -lt 2 ]; then
        print_error "Nothing to reorder"
        sleep 1
        return 0
    fi

    local to_index="$from_index"

    printf '\033[?25l'  # Hide cursor for the whole move mode
    clear

    while true; do
        # Build the frame off-screen and paint in one write - arrow keys repeat
        # fast here, and a clear-per-keypress flickers badly
        local frame
        frame=$(
            print_header "Move Project: $display_name"
            echo ""
            display_projects_list_reorder entries "$to_index"
            show_reorder_mode_commands
        )
        printf '\033[H%s\033[K\n\033[0J' "${frame//$'\n'/$'\033[K\n'}"

        local char
        IFS= read -r -s -n 1 char

        # Enter - commit
        if [[ -z "$char" ]]; then
            break
        fi

        case "$char" in
            $'\e')
                # Escape sequence - arrow keys send \e[A / \e[B
                local seq1 seq2
                read -r -n1 -s -t 0.01 seq1
                read -r -n1 -s -t 0.01 seq2

                if [[ "$seq1" == "[" ]]; then
                    case "$seq2" in
                        A) _reorder_move_up entries to_index ;;
                        B) _reorder_move_down entries to_index "$entry_count" ;;
                    esac
                    continue
                fi

                # Esc alone - cancel without writing
                printf '\033[?25h'
                return 0
                ;;
            w|W|k|K)
                _reorder_move_up entries to_index
                ;;
            s|S|j|J)
                _reorder_move_down entries to_index "$entry_count"
                ;;
            $'\x03')
                # Ctrl+C - cancel without writing
                printf '\033[?25h'
                return 0
                ;;
        esac
    done

    printf '\033[?25h'  # Restore cursor

    # No movement - nothing to write
    if [ "$to_index" -eq "$from_index" ]; then
        return 0
    fi

    # Single atomic write: pull the entry out, splice it back at its new index.
    # $to is the final displayed index; since $rest already has the entry
    # deleted, this is correct for both upward and downward moves.
    if json_update_file "$workspace_file" \
        '. as $a | [$a[$from]] as $item | ($a | del(.[$from])) as $rest |
         $rest[0:$to] + $item + $rest[$to:]' \
        --argjson from "$from_index" --argjson to "$to_index"; then
        return 0
    fi

    print_error "Failed to update workspace file"
    wait_for_enter
    return 1
}

# Helper to swap the moving entry with the one above it
# Clamps at the top - no wrapping, which would be a footgun in a move mode
# Parameters: entries array (by reference), current index (by reference)
_reorder_move_up() {
    local -n move_entries=$1
    local -n move_index=$2

    [ "$move_index" -le 0 ] && return 0

    local above=$((move_index - 1))
    local swap="${move_entries[$above]}"
    move_entries[$above]="${move_entries[$move_index]}"
    move_entries[$move_index]="$swap"
    move_index=$above
}

# Helper to swap the moving entry with the one below it
# Parameters: entries array (by reference), current index (by reference), entry count
_reorder_move_down() {
    local -n move_entries=$1
    local -n move_index=$2
    local count="$3"

    [ "$move_index" -ge $((count - 1)) ] && return 0

    local below=$((move_index + 1))
    local swap="${move_entries[$below]}"
    move_entries[$below]="${move_entries[$move_index]}"
    move_entries[$move_index]="$swap"
    move_index=$below
}
