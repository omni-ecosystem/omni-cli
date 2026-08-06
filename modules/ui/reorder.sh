#!/bin/bash

# ========================================
# Shared Interactive Reorder Component
# ========================================
# Generic two-phase list reordering: browse to pick a row, then move it.
# Callers supply plain-text labels and apply their own persistence.
# Usage: source modules/ui/reorder.sh

# Function to run an interactive two-phase reorder over a list of labels
# Phase 1 browses with the cursor, Enter picks a row. Phase 2 drags that row,
# Enter drops it. Esc backs out of phase 2, or leaves from phase 1.
# Labels must be plain text - this renders all the colouring itself.
# Parameters: labels array (by reference), title, from_var (by ref), to_var (by ref)
# Returns: 0 if a move was confirmed (from/to set), 1 if cancelled or unmoved
reorder_list_interactive() {
    local -n rl_labels=$1
    local rl_title="$2"
    local -n rl_from=$3
    local -n rl_to=$4

    local rl_count=${#rl_labels[@]}

    if [ "$rl_count" -lt 2 ]; then
        print_error "Need at least two entries to reorder"
        sleep 1
        return 1
    fi

    # Pristine copy so Esc during the move phase can put things back
    local rl_original=("${rl_labels[@]}")

    local rl_cursor=0        # Row the cursor sits on (also the moving row once grabbed)
    local rl_grabbed=false   # false = picking a row, true = moving it
    local rl_start=-1        # Where the grabbed row started

    printf '\033[?25l'  # Hide cursor for the whole reorder mode
    clear

    while true; do
        # Build the frame off-screen and paint in one write - arrow keys repeat
        # fast here, and a clear-per-keypress flickers badly
        local rl_frame
        rl_frame=$(
            print_header "$rl_title"
            echo ""
            _reorder_render_rows rl_labels "$rl_cursor" "$rl_grabbed"
            _reorder_render_hints "$rl_grabbed"
        )
        printf '\033[H%s\033[K\n\033[0J' "${rl_frame//$'\n'/$'\033[K\n'}"

        local rl_char
        IFS= read -r -s -n 1 rl_char

        # Enter - pick the row, or confirm the move
        if [[ -z "$rl_char" ]]; then
            if [[ "$rl_grabbed" == false ]]; then
                rl_grabbed=true
                rl_start=$rl_cursor
                continue
            fi
            break
        fi

        case "$rl_char" in
            $'\e')
                # Escape sequence - arrow keys send \e[A / \e[B
                local rl_seq1 rl_seq2
                read -r -n1 -s -t 0.01 rl_seq1
                read -r -n1 -s -t 0.01 rl_seq2

                if [[ "$rl_seq1" == "[" ]]; then
                    case "$rl_seq2" in
                        A) _reorder_step_up rl_labels rl_cursor "$rl_grabbed" ;;
                        B) _reorder_step_down rl_labels rl_cursor "$rl_grabbed" "$rl_count" ;;
                    esac
                    continue
                fi

                # Esc alone - drop the grabbed row back where it was, or leave
                if [[ "$rl_grabbed" == true ]]; then
                    rl_labels=("${rl_original[@]}")
                    rl_cursor=$rl_start
                    rl_grabbed=false
                    rl_start=-1
                    continue
                fi

                printf '\033[?25h'
                return 1
                ;;
            w|W|k|K)
                _reorder_step_up rl_labels rl_cursor "$rl_grabbed"
                ;;
            s|S|j|J)
                _reorder_step_down rl_labels rl_cursor "$rl_grabbed" "$rl_count"
                ;;
            $'\x03')
                # Ctrl+C - cancel without committing
                printf '\033[?25h'
                return 1
                ;;
        esac
    done

    printf '\033[?25h'  # Restore cursor

    # Confirmed without moving - nothing for the caller to persist
    if [ "$rl_cursor" -eq "$rl_start" ]; then
        return 1
    fi

    rl_from=$rl_start
    rl_to=$rl_cursor
    return 0
}

# Render the list rows. The cursor row is highlighted, everything else dimmed.
# Once grabbed the cursor row is the row being dragged, so it gets a marker.
# Parameters: labels array (by reference), cursor_index, grabbed
_reorder_render_rows() {
    local -n render_labels=$1
    local cursor_index="$2"
    local grabbed="$3"

    local index=0
    for label in "${render_labels[@]}"; do
        if [ "$index" -ne "$cursor_index" ]; then
            echo -e "    ${DIM}$((index + 1)). ${label}${NC}"
        elif [[ "$grabbed" == true ]]; then
            echo -e "  ${BRIGHT_YELLOW}▸${NC} ${BRIGHT_CYAN}$((index + 1)).${NC} ${BRIGHT_WHITE}${label}${NC} ${BRIGHT_YELLOW}← moving${NC}"
        else
            echo -e "  ${BRIGHT_CYAN}▸${NC} ${BRIGHT_CYAN}$((index + 1)).${NC} ${BRIGHT_WHITE}${label}${NC}"
        fi
        index=$((index + 1))
    done
    echo ""
}

# Render the key hints for the current phase
# Parameters: grabbed (false = picking a row, true = moving it)
_reorder_render_hints() {
    local grabbed="$1"

    echo ""
    if [[ "$grabbed" == true ]]; then
        menu_line \
            "$(menu_cmd '↑/↓ or w/s' 'move' "$MENU_COLOR_EDIT")" \
            "$(menu_cmd 'enter' 'drop here' "$MENU_COLOR_ADD")" \
            "$(menu_cmd 'esc' 'put back' "$MENU_COLOR_NAV")"
    else
        menu_line \
            "$(menu_cmd '↑/↓ or w/s' 'select' "$MENU_COLOR_EDIT")" \
            "$(menu_cmd 'enter' 'pick' "$MENU_COLOR_ADD")" \
            "$(menu_cmd 'esc' 'back' "$MENU_COLOR_NAV")"
    fi
    echo ""
}

# Helper to step the cursor up one row, dragging the row along if grabbed
# Clamps at the top - no wrapping, which would be a footgun while moving
# Parameters: labels array (by reference), cursor (by reference), grabbed
_reorder_step_up() {
    local -n step_labels=$1
    local -n step_cursor=$2
    local is_grabbed="$3"

    [ "$step_cursor" -le 0 ] && return 0

    local above=$((step_cursor - 1))

    if [[ "$is_grabbed" == true ]]; then
        local swap="${step_labels[$above]}"
        step_labels[$above]="${step_labels[$step_cursor]}"
        step_labels[$step_cursor]="$swap"
    fi

    step_cursor=$above
}

# Helper to step the cursor down one row, dragging the row along if grabbed
# Parameters: labels array (by reference), cursor (by reference), grabbed, count
_reorder_step_down() {
    local -n step_labels=$1
    local -n step_cursor=$2
    local is_grabbed="$3"
    local count="$4"

    [ "$step_cursor" -ge $((count - 1)) ] && return 0

    local below=$((step_cursor + 1))

    if [[ "$is_grabbed" == true ]]; then
        local swap="${step_labels[$below]}"
        step_labels[$below]="${step_labels[$step_cursor]}"
        step_labels[$step_cursor]="$swap"
    fi

    step_cursor=$below
}

# The jq filter every reorder commit uses: pull the entry at $from out, splice
# it back in at $to. Since $rest already has the entry deleted, $to is the
# final displayed index and this is correct for both directions.
readonly REORDER_SPLICE_FILTER='. as $a | [$a[$from]] as $item | ($a | del(.[$from])) as $rest |
     $rest[0:$to] + $item + $rest[$to:]'
