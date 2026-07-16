#!/bin/bash

# ========================================
# Projects UI Components Module
# ========================================
# This module handles UI display components for project operations
# Usage: source modules/settings/projects/components.sh

# Function to show project configuration input screen
# Parameters: selected_folder
show_project_configuration_screen() {
    local selected_folder="$1"
    local projects_root="$2"

    clear
    print_header "Configure Project"
    echo ""
    echo -e "${BRIGHT_CYAN}Adding project:${NC} ${BRIGHT_WHITE}${selected_folder}${NC}"
    echo -e "${DIM}Location: ${projects_root%/}/${selected_folder}${NC}"
    echo ""
}

# Function to show project/command configuration summary
# Parameters: display_name, selected_folder (empty = command entry), startup_cmd, shutdown_cmd
show_project_confirmation_screen() {
    local display_name="$1"
    local selected_folder="$2"
    local startup_cmd="$3"
    local shutdown_cmd="$4"

    clear
    if [ -n "$selected_folder" ]; then
        print_header "Confirm Project Configuration"
    else
        print_header "Confirm Command Configuration"
    fi
    echo ""
    echo -e "  ${DIM}Display Name${NC}"
    echo -e "  ${BRIGHT_WHITE}${display_name}${NC}"
    echo ""
    if [ -n "$selected_folder" ]; then
        echo -e "  ${DIM}Folder${NC}"
        echo -e "  ${BRIGHT_WHITE}${selected_folder}${NC}"
        echo ""
        echo -e "  ${DIM}Startup Command${NC}"
    else
        echo -e "  ${DIM}Command${NC}"
    fi
    echo -e "  ${BRIGHT_CYAN}${startup_cmd}${NC}"
    echo ""
    echo -e "  ${DIM}Shutdown Command${NC}"
    echo -e "  ${BRIGHT_CYAN}${shutdown_cmd:-—}${NC}"
    echo ""
}

# Function to show edit project screen with current values
# Parameters: current_display, current_start, current_stop
show_edit_project_screen() {
    local current_display="$1"
    local current_start="$2"
    local current_stop="$3"

    clear
    print_header "Edit Project: $current_display"
    echo ""
    echo -e "${BRIGHT_WHITE}Current display name: ${DIM}${current_display}${NC}"
    echo -e "${BRIGHT_WHITE}Current startup cmd:  ${DIM}${current_start}${NC}"
    echo -e "${BRIGHT_WHITE}Current shutdown cmd: ${DIM}${current_stop}${NC}"
    echo ""
}

# Helper function to show a diff line
# Parameters: label, old_value, new_value
show_diff_line() {
    local label="$1"
    local old="$2"
    local new="$3"

    echo -e "  ${BRIGHT_WHITE}${label}${NC}"
    if [ "$old" = "$new" ]; then
        # Unchanged - show value dimmed
        echo -e "  ${DIM}${old:-—}${NC}"
    else
        # Changed - show old (dimmed) → new (green)
        echo -e "  ${DIM}${old:-—}${NC} → ${BRIGHT_GREEN}${new:-—}${NC}"
    fi
    echo ""
}

# Function to show edit project confirmation screen with diff
# Parameters: old_display, old_startup, old_shutdown, new_display, new_startup, new_shutdown
show_edit_project_confirmation_screen() {
    local old_display="$1"
    local old_startup="$2"
    local old_shutdown="$3"
    local new_display="$4"
    local new_startup="$5"
    local new_shutdown="$6"

    clear
    print_header "Confirm Project Changes"
    echo ""
    show_diff_line "Display Name" "$old_display" "$new_display"
    show_diff_line "Startup Command" "$old_startup" "$new_startup"
    show_diff_line "Shutdown Command" "$old_shutdown" "$new_shutdown"
}
