#!/bin/bash

# ========================================
# JSON Parser Module
# ========================================
# This module handles JSON parsing functionality
# Usage: source modules/config/json.sh

# Global projects array
declare -g -a projects=()
# Global workspace tracking array (parallel to projects array)
declare -g -a project_workspaces=()

# Function to get the config directory path
# Returns: config directory path via echo
# Uses IS_INSTALLED and BASE_DIR variables set in startup.sh
get_config_directory() {
    if [ "$IS_INSTALLED" = true ]; then
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

    # Read each project object from JSON - use safer approach
    local json_content
    json_content=$(cat "$json_file" 2>/dev/null)
    if [ $? -ne 0 ] || [ -z "$json_content" ]; then
        return 1
    fi

    # Remove newlines and split on project boundaries
    local flat_json
    flat_json=$(echo "$json_content" | tr -d '\n\r' | sed 's/},/},\n/g')

    # Extract JSON objects - use more robust method
    local parsed_objects
    parsed_objects=$(echo "$flat_json" | grep -o '{[^}]*}' || true)

    if [ -z "$parsed_objects" ]; then
        return 1
    fi

    # Process each JSON object
    while IFS= read -r line; do
        # Skip empty lines
        [ -z "$line" ] && continue

        # Skip lines that don't contain project objects
        if [[ ! "$line" =~ \"displayName\" ]]; then
            continue
        fi

        # Extract values using more robust regex patterns
        local display_name
        local project_name
        local relative_path
        local startup_cmd
        local shutdown_cmd

        display_name=$(echo "$line" | sed -n 's/.*"displayName"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        project_name=$(echo "$line" | sed -n 's/.*"projectName"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        relative_path=$(echo "$line" | sed -n 's/.*"relativePath"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        startup_cmd=$(echo "$line" | sed -n 's/.*"startupCmd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
        shutdown_cmd=$(echo "$line" | sed -n 's/.*"shutdownCmd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')

        # If no shutdown command, use empty string
        [ -z "$shutdown_cmd" ] && shutdown_cmd=""

        # Determine the folder path - prefer relativePath, fallback to projectName
        local folder_path
        if [ -n "$relative_path" ]; then
            folder_path="$relative_path"
        elif [ -n "$project_name" ]; then
            folder_path="$project_name"
        else
            continue  # Skip if neither field is available
        fi

        # Add to global projects array (startup_cmd can be empty)
        if [ -n "$display_name" ] && [ -n "$folder_path" ]; then
            projects+=("$display_name:$folder_path:$startup_cmd:$shutdown_cmd")
            project_workspaces+=("$json_file")
        fi
    done <<< "$parsed_objects"

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

