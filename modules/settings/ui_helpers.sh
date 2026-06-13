#!/bin/bash

# ========================================
# Settings UI Helpers Module
# ========================================
# This module provides reusable UI interaction helpers for settings screens
# Usage: source modules/settings/ui_helpers.sh

# Function to scan a directory for folders and let user select one
# Parameters: projects_root
# Returns: selected folder name via echo (to stdout), or empty if cancelled
# NOTE: All UI output goes to stderr (>&2) so only the selected folder goes to stdout
scan_and_display_available_folders() {
    local projects_root="$1"

    echo "" >&2
    print_color "$BRIGHT_CYAN" "Scanning projects directory: $projects_root" >&2
    echo "" >&2

    # Check if directory exists
    if [ ! -d "$projects_root" ]; then
        print_error "Projects directory does not exist: $projects_root" >&2
        wait_for_enter
        return 1
    fi

    # Find all subdirectories
    local -a available_folders=()

    while IFS= read -r -d '' dir; do
        local folder_name=$(basename "$dir")

        # Skip hidden directories
        if [[ ! "$folder_name" =~ ^\. ]]; then
            available_folders+=("$folder_name")
        fi
    done < <(find "$projects_root" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)

    if [ ${#available_folders[@]} -eq 0 ]; then
        print_error "No folders found in projects directory: $projects_root" >&2
        wait_for_enter
        return 1
    fi

    # Display folders
    for i in "${!available_folders[@]}"; do
        local counter=$((i + 1))
        local folder="${available_folders[i]}"

        # Truncate long folder names
        local truncated_folder=$(printf "%.50s" "$folder")
        [ ${#folder} -gt 50 ] && truncated_folder="${truncated_folder}.."

        printf "  ${BRIGHT_CYAN}%-2s${NC}  ${BRIGHT_WHITE}%s${NC}\n" "$counter" "$truncated_folder" >&2
    done

    echo "" >&2
    echo -e "${BRIGHT_WHITE}Select a folder (enter number), or press Enter/ESC to go back${NC}" >&2
    echo -ne "${BRIGHT_CYAN}>${NC} " >&2

    # Read with ESC support
    folder_choice=""
    while true; do
        IFS= read -r -s -n 1 char
        # ESC key
        if [[ "$char" == $'\x1b' ]]; then
            # Consume any escape sequence chars
            read -r -s -n 2 -t 0.01 _ 2>/dev/null || true
            echo "" >&2
            return 1
        fi
        # Enter key
        if [[ -z "$char" ]]; then
            echo "" >&2
            break
        fi
        # Backspace
        if [[ "$char" == $'\x7f' ]] || [[ "$char" == $'\x08' ]]; then
            if [[ -n "$folder_choice" ]]; then
                folder_choice="${folder_choice%?}"
                echo -ne "\b \b" >&2
            fi
            continue
        fi
        # Only accept digits
        if [[ "$char" =~ ^[0-9]$ ]]; then
            folder_choice+="$char"
            echo -n "$char" >&2
        fi
    done

    # Handle empty input (go back)
    if [ -z "$folder_choice" ]; then
        return 1
    fi

    # Validate choice is a number
    if ! [[ "$folder_choice" =~ ^[0-9]+$ ]]; then
        print_error "Invalid choice. Please enter a number." >&2
        wait_for_enter
        return 1
    fi

    # Validate choice is in range
    if [ "$folder_choice" -lt 1 ] || [ "$folder_choice" -gt "${#available_folders[@]}" ]; then
        print_error "Invalid choice. Please select a number between 1 and ${#available_folders[@]}." >&2
        wait_for_enter
        return 1
    fi

    # Get selected folder
    local selected_index=$((folder_choice - 1))
    local selected_folder="${available_folders[selected_index]}"

    # Return selected folder name to stdout
    echo "$selected_folder"
    return 0
}

# Function to parse projects from a workspace file
# Parameters: workspace_file
# Returns: array variable name to populate (pass by reference)
# Usage: parse_workspace_projects "$workspace_file" workspace_projects
parse_workspace_projects() {
    local workspace_file="$1"
    local -n result_array=$2  # nameref to array

    result_array=()
    if command -v jq >/dev/null 2>&1 && [ -f "$workspace_file" ]; then
        while IFS= read -r line; do
            result_array+=("$line")
        done < <(jq -r '.[] | "\(.displayName):\(.projectName):\(.startupCmd):\(.shutdownCmd)"' "$workspace_file" 2>/dev/null)
    fi
}


# Function to prompt for all project input fields
# Parameters: folder_name
# Outputs to stdout: display_name, startup_cmd, shutdown_cmd (one per line)
# Returns: 0 on success, 2 if ESC pressed (cancelled)
# Usage:
#   IFS=$'\n' read -r display_name startup_cmd shutdown_cmd < <(prompt_project_input_fields "$folder_name")
prompt_project_input_fields() {
    local folder_name="$1"
    local display_name startup_cmd shutdown_cmd

    echo -e "${DIM}(ESC to cancel)${NC}" >&2
    echo "" >&2

    # Get display name (required, loops until valid)
    while true; do
        echo -e "${BRIGHT_WHITE}Enter display name for this project:${NC}" >&2
        echo -ne "${DIM}(Enter to use '$folder_name')${NC} ${BRIGHT_CYAN}>${NC} " >&2
        read_with_esc_cancel display_name
        [[ $? -eq 2 ]] && return 2

        # Default to folder name if empty
        if [ -z "$display_name" ]; then
            display_name="$folder_name"
        fi

        # Trim whitespace and validate
        display_name=$(echo "$display_name" | xargs)
        if [ -n "$display_name" ]; then
            break
        fi

        echo -e "${RED}Display name cannot be empty.${NC}" >&2
        echo "" >&2
    done

    # Get startup command
    echo "" >&2
    echo -e "${BRIGHT_WHITE}Enter startup command:${NC}" >&2
    echo -ne "${DIM}(e.g., 'npm start', 'yarn dev')${NC} ${BRIGHT_CYAN}>${NC} " >&2
    read_with_esc_cancel startup_cmd
    [[ $? -eq 2 ]] && return 2

    # Get shutdown command
    echo "" >&2
    echo -e "${BRIGHT_WHITE}Enter shutdown command:${NC}" >&2
    echo -ne "${DIM}(e.g., 'npm run stop', 'pkill -f node')${NC} ${BRIGHT_CYAN}>${NC} " >&2
    read_with_esc_cancel shutdown_cmd
    [[ $? -eq 2 ]] && return 2

    # Output the three values to stdout (one per line)
    echo "$display_name"
    echo "$startup_cmd"
    echo "$shutdown_cmd"
}
