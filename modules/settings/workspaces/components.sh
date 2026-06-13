#!/bin/bash

# ========================================
# Workspaces UI Components Module
# ========================================
# This module handles UI display components for workspace operations
# Usage: source modules/settings/workspaces/components.sh

# Function to show workspace name prompt screen
# Parameters: projects_folder, default_name
show_workspace_name_prompt() {
    local projects_folder="$1"
    local default_name="$2"

    # Convert path to use ~ for home directory
    local display_path="${projects_folder/#$HOME/\~}"

    clear
    print_header "Create Workspace"
    echo ""
    echo -e "${BRIGHT_WHITE}Selected directory:${NC} ${DIM}${display_path}${NC}"
    echo ""
    echo -e "${DIM}Spaces will be converted to hyphens (e.g., 'My Projects' → 'my-projects')${NC}"
    echo ""
    echo -e "${DIM}Press Esc to cancel${NC}"
    echo ""
    echo -e "${BRIGHT_WHITE}Enter name for this workspace:${NC}"
    echo -ne "${DIM}(press Enter to use '$default_name')${NC} ${BRIGHT_CYAN}>${NC} "
}

# Function to show workspace created success screen
# Parameters: workspace_name, projects_folder
show_workspace_created_screen() {
    local workspace_name="$1"
    local projects_folder="$2"

    clear
    print_header "Workspace Created"
    echo ""
    print_success "Workspace '$workspace_name' created successfully!"
    echo ""
    print_info "Projects folder: $projects_folder"
    print_info "You can now add projects to this workspace."
    echo ""
}

# Function to show workspace management menu header
# Parameters: display_name, projects_root, project_count
show_workspace_management_header() {
    local display_name="$1"
    local projects_root="$2"
    local project_count="$3"

    printf '\033[?25l'  # Hide cursor during redraw
    clear
    print_header "Manage Workspace: $display_name"
    echo ""
}

# Function to display projects list
# Parameters: workspace_projects (array passed by reference), workspace_file, projects_root
display_projects_list() {
    local -n projects_list=$1
    local workspace_file="$2"
    local projects_root="$3"
    local project_count=${#projects_list[@]}

    if [ $project_count -gt 0 ]; then
        local counter=1
        for project_info in "${projects_list[@]}"; do
            IFS=':' read -r proj_display proj_name proj_start proj_stop <<< "$project_info"
            echo -e "  ${BRIGHT_CYAN}${counter}.${NC} ${BRIGHT_WHITE}${proj_display}${NC} ${DIM}(${proj_name})${NC}"
            counter=$((counter + 1))
        done
        echo ""
    else
        echo -e "  ${DIM}No projects configured yet${NC}"
        echo ""
    fi
}

# Function to show workspace management menu commands
# Parameters: project_count, restricted_mode (optional)
show_workspace_management_commands() {
    local project_count="$1"
    local restricted_mode="${2:-false}"

    echo ""
    if [[ "$restricted_mode" == true ]]; then
        # Restricted: only a, v, r, b
        menu_line \
            "$(menu_cmd 'a' 'add project' "$MENU_COLOR_ADD")" \
            "$(menu_num_cmd 'v' "$project_count" 'secure files' "$MENU_COLOR_ACTION")" \
            "$(menu_cmd 'r' 'rename workspace' "$MENU_COLOR_EDIT")" \
            "$(menu_cmd 'b' 'back' "$MENU_COLOR_NAV")"
    else
        menu_line \
            "$(menu_cmd 'a' 'add project' "$MENU_COLOR_ADD")" \
            "$(menu_num_cmd 'e' "$project_count" 'edit project' "$MENU_COLOR_EDIT")" \
            "$(menu_num_cmd 'v' "$project_count" 'secure files' "$MENU_COLOR_ACTION")" \
            "$(menu_num_cmd 'x' "$project_count" 'remove project' "$MENU_COLOR_DELETE")" \
            "$(menu_cmd 'r' 'rename workspace' "$MENU_COLOR_EDIT")" \
            "$(menu_cmd 'd' 'delete workspace' "$MENU_COLOR_DELETE")" \
            "$(menu_cmd 'b' 'back' "$MENU_COLOR_NAV")"
    fi
    echo ""
}

# Function to show delete workspace warning
# Parameters: display_name, workspace_file
show_delete_workspace_warning() {
    local display_name="$1"
    local workspace_file="$2"

    clear
    print_header "Delete Workspace"
    echo ""
    print_warning_box
    echo -e "${BRIGHT_RED}You are about to DELETE workspace${NC}"
    echo -e "  ${BRIGHT_WHITE}${display_name}${NC}"
    echo ""
    echo -e "${DIM}Workspace file:${NC} ${BRIGHT_WHITE}${workspace_file}${NC}"
    echo ""
}

# Function to show workspace selection menu header
show_workspace_selection_header() {
    clear
    print_header "Select Workspace to Manage"
    echo ""
}

# Function to display workspace list
# Parameters: available_workspaces (array)
display_workspace_list() {
    local -n workspaces_list=$1

    # Get config directory for constructing full paths
    local config_dir=$(get_config_directory)

    local counter=1
    for workspace_basename in "${workspaces_list[@]}"; do
        # Construct full path from config_dir and basename
        local workspace_file="$config_dir/$workspace_basename"
        local display_name
        format_workspace_display_name_ref "$workspace_file" display_name

        # Count projects
        local workspace_projects=()
        parse_workspace_projects "$workspace_file" workspace_projects
        local project_count=${#workspace_projects[@]}

        echo -e "  ${BRIGHT_CYAN}${counter}.${NC} ${BRIGHT_WHITE}${display_name}${NC} ${DIM}(${project_count} projects)${NC}"

        counter=$((counter + 1))
    done
    echo ""
}
