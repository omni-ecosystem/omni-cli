#!/bin/bash

# ========================================
# JSON Parser Module
# ========================================
# This module handles JSON parsing functionality
# Usage: source modules/config/json.sh

# Field separator used to pack a project record into a single string.
# ASCII Unit Separator: commands legitimately contain ':' (ports, URLs, ssh
# targets), so a colon here truncates them when the record is split back apart.
declare -g OMNI_FIELD_SEP=$'\x1f'

# Global projects array
declare -g -a projects=()
# Global workspace tracking array (parallel to projects array)
declare -g -a project_workspaces=()

# Function to get the config directory path
# Returns: config directory path via echo
# Uses IS_INSTALLED and BASE_DIR variables set in startup.sh
get_config_directory() {
    if [ -n "$OMNI_LOCAL_CONFIG_DIR" ]; then
        echo "$OMNI_LOCAL_CONFIG_DIR"
    elif [ "$IS_INSTALLED" = true ]; then
        echo "$HOME/.config/$PROJECT_FOLDER_NAME"
    else
        echo "$BASE_DIR/config"
    fi
}

# Function to load projects from active workspaces only
load_projects_from_json() {
    # Clear global arrays
    projects=()
    project_workspaces=()

    # Get config directory
    local config_dir=$(get_config_directory)

    # Check for workspaces configuration file
    local workspaces_file="$config_dir/.workspaces.json"
    local workspace_files=()

    if [ -f "$workspaces_file" ] && command -v jq >/dev/null 2>&1; then
        # Load only active workspaces from workspaces configuration
        while IFS= read -r active_workspace; do
            # Construct full path from config_dir and workspace filename
            local full_workspace_path="$config_dir/$active_workspace"
            if [ -f "$full_workspace_path" ]; then
                workspace_files+=("$full_workspace_path")
            fi
        done < <(jq -r '.activeConfig[]? // empty' "$workspaces_file" 2>/dev/null)
    fi

    if [ ${#workspace_files[@]} -eq 0 ]; then
        return 1
    fi

    # Load projects from each active workspace
    for workspace_file in "${workspace_files[@]}"; do
        load_projects_from_workspace "$workspace_file"
    done

    # Validate that we actually loaded some projects
    if [ ${#projects[@]} -eq 0 ]; then
        return 1
    fi
    return 0
}

# Helper function to load projects from a single workspace file
load_projects_from_workspace() {
    local json_file="$1"

    if [ ! -f "$json_file" ]; then
        return 1
    fi

    if ! command -v jq >/dev/null 2>&1; then
        return 1
    fi

    # Read each project object with jq - regex parsing mangles commands that
    # contain escaped double quotes or braces. One field per line, fed straight
    # into the loop: a command substitution would swallow a trailing empty
    # shutdown command and drop the last entry of the file.
    local loaded=0
    local display_name folder_path startup_cmd shutdown_cmd
    while IFS= read -r display_name \
       && IFS= read -r folder_path \
       && IFS= read -r startup_cmd \
       && IFS= read -r shutdown_cmd; do
        # Only a display name is required - startup and shutdown commands are
        # both optional, and command entries have no project folder
        [ -z "$display_name" ] && continue

        projects+=("${display_name}${OMNI_FIELD_SEP}${folder_path}${OMNI_FIELD_SEP}${startup_cmd}${OMNI_FIELD_SEP}${shutdown_cmd}")
        project_workspaces+=("$json_file")
        loaded=$((loaded + 1))
    done < <(jq -r '
        .[]?
        | select((.displayName // "") != "")
        | .displayName,
          (if (.relativePath // "") != "" then .relativePath
           elif (.projectName // "") != "" then .projectName
           else (.folderPath // "") end),
          (.startupCmd // ""),
          (.shutdownCmd // "")
    ' "$json_file" 2>/dev/null)

    [ "$loaded" -eq 0 ] && return 1
    return 0
}

# Load the project configuration (silent - no user prompts)
load_config() {
    # Try to load projects, but don't show errors
    if ! load_projects_from_json 2>/dev/null; then
        # Set empty projects array to allow menu to load
        projects=()
        project_workspaces=()
    fi

    # Return success regardless - menu will handle empty state
    return 0
}


reload_config() {
    if load_projects_from_json; then
        return 0
    else
        return 1
    fi
}

