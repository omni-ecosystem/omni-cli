#!/bin/bash

# ========================================
# UI Components Module
# ========================================
# This module provides UI components like headers, separators, and message functions
# Usage: source libs/omni-ui-kit/ui.sh

# Ensure colors are available
if [[ -z "$BRIGHT_CYAN" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/colors.sh"
fi

# Function to get terminal width
get_terminal_width() {
    local width
    if command -v tput &> /dev/null; then
        width=$(tput cols 2>/dev/null) || width=80
    else
        width=${COLUMNS:-80}
    fi
    # Ensure minimum width and maximum width for readability
    if [ "$width" -lt 60 ]; then
        width=60
    elif [ "$width" -gt 120 ]; then
        width=120
    fi
    echo "$width"
}

# Function to print a clean header (minimal styling)
print_header() {
    local title="$1"

    echo ""
    echo -e "${BRIGHT_WHITE}${BOLD}${title}${NC}"
    echo -e "${BRIGHT_CYAN}$(printf '─%.0s' $(seq 1 ${#title}))${NC}"
}

# Function to print a clean separator
print_separator() {
    local color="${1:-$DIM}"
    echo -e "${color}$(printf '%.0s─' $(seq 1 40))${NC}"
}

# Function to print success message
print_success() {
    print_color "$BRIGHT_GREEN" "[success] $*"
}

# Function to print error message
print_error() {
    print_color "$BRIGHT_RED" "[error] $*"
}

# Function to print warning message
print_warning() {
    print_color "$BRIGHT_YELLOW" "[warning] $*"
}

# Function to print info message
print_info() {
    print_color "$BRIGHT_WHITE" "[info] $*"
}

# Function to print step message
print_step() {
    print_color "$BLUE" "→ $*"
}

# Function to print a boxed warning header
print_warning_box() {
    echo -e "${BRIGHT_RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BRIGHT_RED}║                        ⚠️  WARNING  ⚠️                        ║${NC}"
    echo -e "${BRIGHT_RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Function to prompt user to press Enter to continue
# Parameters: optional custom message
wait_for_enter() {
    local message="${1:-Press Enter to continue...}"
    echo ""
    echo -ne "${WHITE}${message}${NC}"
    read -r
}

# Function to read user input with instant back key handling
# The 'b' key will trigger immediately without needing Enter
# Handles backspace properly for full editing support
# Returns: user input via variable name passed as parameter
# Usage: read_with_instant_back choice
read_with_instant_back() {
    local -n result_var=$1  # nameref to result variable
    local input=""
    local char

    while true; do
        # Read single character without echo
        IFS= read -r -s -n 1 char

        # Handle Enter (empty char from read -n 1)
        if [[ -z "$char" ]]; then
            echo ""  # Add newline
            result_var="$input"
            return 0
        fi

        # Handle backspace (ASCII 127) or ctrl-H (ASCII 8)
        if [[ "$char" == $'\x7f' ]] || [[ "$char" == $'\x08' ]]; then
            if [[ -n "$input" ]]; then
                # Remove last character from input
                input="${input%?}"
                # Move cursor back, overwrite with space, move back again
                echo -ne "\b \b"
            fi
            continue
        fi

        # Handle Ctrl+C
        if [[ "$char" == $'\x03' ]]; then
            echo ""
            result_var=""
            return 1
        fi

        # If first character is 'b' and input is empty, return immediately
        if [[ -z "$input" ]] && [[ "$char" == "b" ]]; then
            echo "b"  # Echo the character and newline
            result_var="b"
            return 0
        fi

        # Add character to input and echo it
        input+="$char"
        echo -n "$char"
    done
}

# Function to read input with Esc key cancellation support
# Parameters: variable name to store result
# Returns: 0 for normal input, 2 for Esc pressed
# NOTE: All echo output goes to stderr so stdout can be captured separately
# Usage: read_with_esc_cancel result_variable
read_with_esc_cancel() {
    local -n result_var=$1  # nameref to result variable
    local input=""
    local char

    while true; do
        # Read single character without echo
        IFS= read -r -s -n 1 char

        # Handle Escape key (ASCII 27)
        if [[ "$char" == $'\x1b' ]]; then
            # Read any remaining escape sequence characters (for arrow keys, etc.)
            read -r -s -n 2 -t 0.01 _ 2>/dev/null || true
            echo "" >&2
            result_var=""
            return 2
        fi

        # Handle Enter (empty char from read -n 1)
        if [[ -z "$char" ]]; then
            echo "" >&2  # Add newline
            result_var="$input"
            return 0
        fi

        # Handle backspace (ASCII 127) or ctrl-H (ASCII 8)
        if [[ "$char" == $'\x7f' ]] || [[ "$char" == $'\x08' ]]; then
            if [[ -n "$input" ]]; then
                # Remove last character from input
                input="${input%?}"
                # Move cursor back, overwrite with space, move back again
                echo -ne "\b \b" >&2
            fi
            continue
        fi

        # Handle Ctrl+C
        if [[ "$char" == $'\x03' ]]; then
            echo "" >&2
            result_var=""
            return 2
        fi

        # Add character to input and echo it
        input+="$char"
        echo -n "$char" >&2
    done
}

# Function to prompt for yes/no confirmation with Esc support
# Parameters: prompt_message
# Returns: 0 for yes, 1 for no, 2 for Esc/cancel
prompt_yes_no_confirmation() {
    local prompt_message="$1"
    local confirm_input=""

    echo -ne "${BRIGHT_WHITE}${prompt_message} (y/n): ${NC}"

    # Use read_with_esc_cancel to get input with Esc support
    read_with_esc_cancel confirm_input
    local result=$?

    # Handle Esc/Ctrl+C
    if [ $result -eq 2 ]; then
        return 2
    fi

    case "${confirm_input,,}" in
        "y"|"yes")
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}
