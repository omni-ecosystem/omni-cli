#!/bin/bash

# ========================================
# Projects Reorder Module
# ========================================
# Handles moving projects/commands up and down within a workspace
# Usage: source modules/settings/projects/reorder.sh

# Function to interactively reorder the projects in a workspace
# Two phases: browse to pick the project, then move it to its new spot.
# Nothing is written until the move is confirmed - Esc leaves the file untouched
# Parameters: workspace_file
reorder_workspace_projects() {
    local workspace_file="$1"

    local display_name
    format_workspace_display_name_ref "$workspace_file" display_name

    # Load entries once - the loop reorders this array in memory for rendering
    local entries=()
    parse_workspace_projects "$workspace_file" entries
    local entry_count=${#entries[@]}

    if [ "$entry_count" -lt 2 ]; then
        print_error "Need at least two entries to reorder"
        sleep 1
        return 0
    fi

    # Pristine copy so Esc during the move phase can put things back
    local original_entries=("${entries[@]}")

    local cursor=0        # Row the cursor sits on (also the moving row once grabbed)
    local grabbed=false   # false = picking a project, true = moving it
    local from_index=-1   # Where the grabbed project started

    printf '\033[?25l'  # Hide cursor for the whole reorder mode
    clear

    while true; do
        # Build the frame off-screen and paint in one write - arrow keys repeat
        # fast here, and a clear-per-keypress flickers badly
        local frame
        frame=$(
            print_header "Reorder: $display_name"
            echo ""
            display_projects_list_reorder entries "$cursor" "$grabbed"
            show_reorder_mode_commands "$grabbed"
        )
        printf '\033[H%s\033[K\n\033[0J' "${frame//$'\n'/$'\033[K\n'}"

        local char
        IFS= read -r -s -n 1 char

        # Enter - pick the project, or confirm the move
        if [[ -z "$char" ]]; then
            if [[ "$grabbed" == false ]]; then
                grabbed=true
                from_index=$cursor
                continue
            fi
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
                        A) _reorder_step_up entries cursor "$grabbed" ;;
                        B) _reorder_step_down entries cursor "$grabbed" "$entry_count" ;;
                    esac
                    continue
                fi

                # Esc alone - drop the grabbed project back where it was, or leave
                if [[ "$grabbed" == true ]]; then
                    entries=("${original_entries[@]}")
                    cursor=$from_index
                    grabbed=false
                    from_index=-1
                    continue
                fi

                printf '\033[?25h'
                return 0
                ;;
            w|W|k|K)
                _reorder_step_up entries cursor "$grabbed"
                ;;
            s|S|j|J)
                _reorder_step_down entries cursor "$grabbed" "$entry_count"
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
    if [ "$cursor" -eq "$from_index" ]; then
        return 0
    fi

    # Single atomic write: pull the entry out, splice it back at its new index.
    # $to is the final displayed index; since $rest already has the entry
    # deleted, this is correct for both upward and downward moves.
    if json_update_file "$workspace_file" \
        '. as $a | [$a[$from]] as $item | ($a | del(.[$from])) as $rest |
         $rest[0:$to] + $item + $rest[$to:]' \
        --argjson from "$from_index" --argjson to "$cursor"; then
        return 0
    fi

    print_error "Failed to update workspace file"
    wait_for_enter
    return 1
}

# Helper to step the cursor up one row, dragging the project along if grabbed
# Clamps at the top - no wrapping, which would be a footgun while moving
# Parameters: entries array (by reference), cursor (by reference), grabbed
_reorder_step_up() {
    local -n move_entries=$1
    local -n move_cursor=$2
    local is_grabbed="$3"

    [ "$move_cursor" -le 0 ] && return 0

    local above=$((move_cursor - 1))

    if [[ "$is_grabbed" == true ]]; then
        local swap="${move_entries[$above]}"
        move_entries[$above]="${move_entries[$move_cursor]}"
        move_entries[$move_cursor]="$swap"
    fi

    move_cursor=$above
}

# Helper to step the cursor down one row, dragging the project along if grabbed
# Parameters: entries array (by reference), cursor (by reference), grabbed, entry count
_reorder_step_down() {
    local -n move_entries=$1
    local -n move_cursor=$2
    local is_grabbed="$3"
    local count="$4"

    [ "$move_cursor" -ge $((count - 1)) ] && return 0

    local below=$((move_cursor + 1))

    if [[ "$is_grabbed" == true ]]; then
        local swap="${move_entries[$below]}"
        move_entries[$below]="${move_entries[$move_cursor]}"
        move_entries[$move_cursor]="$swap"
    fi

    move_cursor=$below
}
