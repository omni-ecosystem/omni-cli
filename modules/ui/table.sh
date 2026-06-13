#!/bin/bash

# ========================================
# Shared Table UI Component
# ========================================
# Provides reusable table rendering for workspace/project displays
# Usage: source modules/ui/table.sh

# Format workspace display name using nameref (no subshell)
# Parameters:
#   $1 - workspace_file path
#   $2 - nameref for result
format_workspace_display_name_ref() {
    local workspace_file="$1"
    local -n _result=$2
    local workspace_name="${workspace_file##*/}"
    workspace_name="${workspace_name%.json}"
    # Title case: replace _ and - with space, capitalize first letter of each word
    local word result_str=""
    for word in ${workspace_name//[-_]/ }; do
        result_str+="${word^} "
    done
    _result="${result_str% }"
}

# Get workspace files from config directory
# Parameters:
#   $1 - mode: "active" (only active workspaces) or "all" (all workspaces)
#   $2 - nameref to array to populate
# Usage: get_workspace_files "active" workspace_files
get_workspace_files() {
    local mode="$1"
    local -n result_array=$2

    result_array=()
    local config_dir=$(get_config_directory)
    local workspaces_file="$config_dir/.workspaces.json"

    if [ ! -f "$workspaces_file" ] || ! command -v jq >/dev/null 2>&1; then
        return 1
    fi

    if [ "$mode" = "active" ]; then
        # Get only active workspaces
        while IFS= read -r active_workspace; do
            local full_path="$config_dir/$active_workspace"
            if [ -f "$full_path" ]; then
                result_array+=("$full_path")
            fi
        done < <(jq -r '.activeConfig[]? // empty' "$workspaces_file" 2>/dev/null)
    else
        # Get all available workspaces
        local available=()
        if get_available_workspaces available; then
            for ws in "${available[@]}"; do
                result_array+=("$config_dir/$ws")
            done
        fi
    fi

    [ ${#result_array[@]} -gt 0 ]
}

# Get assigned vaults for a project
# Parameters:
#   $1 - workspace_file path
#   $2 - relative_path of project
# Returns: comma-separated vault names via echo
get_project_vaults() {
    local workspace_file="$1"
    local relative_path="$2"

    if [ -f "$workspace_file" ] && command -v jq >/dev/null 2>&1; then
        jq -r --arg path "$relative_path" \
            '.[] | select(.relativePath == $path) | .assignedVaults[]? // empty' \
            "$workspace_file" 2>/dev/null | tr '\n' ',' | sed 's/,$//'
    fi
}

# Vault cache for batch loading
declare -gA _vault_cache=()

# Load all vaults for a workspace into cache (single jq call)
# Parameters: $1 - workspace_file path
load_workspace_vaults() {
    local workspace_file="$1"

    if [ -f "$workspace_file" ] && command -v jq >/dev/null 2>&1; then
        local project_path vaults
        while IFS=$'\t' read -r project_path vaults; do
            [[ -n "$project_path" ]] && _vault_cache["${workspace_file}:${project_path}"]="$vaults"
        done < <(jq -r '.[] | [.relativePath, (.assignedVaults // [] | join(","))] | @tsv' "$workspace_file" 2>/dev/null)
    fi
}

# Get vaults from cache using nameref (no subshell)
# Parameters: $1 - workspace_file, $2 - relative_path, $3 - nameref for result
get_project_vaults_ref() {
    local workspace_file="$1"
    local relative_path="$2"
    local -n _vaults=$3
    _vaults="${_vault_cache["${workspace_file}:${relative_path}"]:-}"
}

# Render workspace header
# Parameters:
#   $1 - mode: "menu" or "settings"
#   $2 - display_name
#   $3 - counter (for settings mode)
#   $4 - status_icon (for settings mode, optional)
#   $5 - status_text (for settings mode, optional)
render_workspace_header() {
    local mode="$1"
    local display_name="$2"
    local counter="$3"
    local status_icon="$4"
    local status_text="$5"

    case "$mode" in
        menu)
            echo ""
            printf " ${BRIGHT_CYAN}%s${NC}\n" "$display_name"
            ;;
        settings)
            printf " %s ${BRIGHT_CYAN}%s${NC} ${BOLD}%-25s${NC} %s" \
                "$status_icon" "Workspace #$counter" "\"${display_name:0:45}\""
            echo ""
            echo ""
            ;;
        *)
            # Unknown mode: basic fallback
            printf " ${BRIGHT_CYAN}%s${NC}\n" "$display_name"
            echo ""
            ;;
    esac
}

# Render table header row
# Parameters:
#   $1 - mode: "menu" or "settings"
# Outputs directly to stdout
render_table_header() {
    local mode="$1"

    case "$mode" in
        menu)
            echo ""
            printf "  ${BRIGHT_WHITE}%-3s%-34s%-16s${NC}\n" "#" "Name" "Status"
            ;;
        settings)
            printf "   ${BRIGHT_WHITE}%-24s %-24s %-20s %-20s %-20s${NC}\n" \
                "Project name" "Folder name" "Startup cmd" "Shutdown cmd" "Vaults"
            ;;
        *)
            # Unknown mode: basic fallback
            echo -e "  ${BRIGHT_WHITE}# Name${NC}"
            echo ""
            ;;
    esac
}

# Render project row for menu mode
# Render project row for menu mode (optimized - no subshells)
# Parameters:
#   $1 - counter
#   $2 - project_name
#   $3 - status_text
#   $4 - status_color
render_menu_project_row() {
    local counter="$1"
    local project_name="$2"
    local status_text="$3"
    local status_color="$4"

    # Truncate name if needed
    [[ ${#project_name} -gt 34 ]] && project_name="${project_name:0:31}..."

    printf "  ${BRIGHT_CYAN}%-3s${NC}${DIM}%-34s${NC}${status_color}%-16s${NC}\n" \
        "$counter" "$project_name" "$status_text"
}

# Render project row for settings mode (optimized - no subshells)
# Parameters:
#   $1 - project_name
#   $2 - folder_name
#   $3 - startup_cmd
#   $4 - shutdown_cmd
#   $5 - vaults
render_settings_project_row() {
    local project_name="$1"
    local folder_name="$2"
    local startup_cmd="$3"
    local shutdown_cmd="$4"
    local vaults="${5:-}"

    # Inline truncation (no subshells)
    [[ ${#project_name} -gt 24 ]] && project_name="${project_name:0:19}..."
    [[ ${#folder_name} -gt 24 ]] && folder_name="${folder_name:0:21}..."
    [[ ${#startup_cmd} -gt 24 ]] && startup_cmd="${startup_cmd:0:17}..."
    [[ ${#shutdown_cmd} -gt 20 ]] && shutdown_cmd="${shutdown_cmd:0:17}..."
    [[ ${#vaults} -gt 20 ]] && vaults="${vaults:0:17}..."

    # Direct printf with width specifiers (no subshells)
    printf "   ${DIM}%-24s %-24s %-20s %-20s %-20s${NC}\n" \
        "$project_name" "$folder_name" "$startup_cmd" "$shutdown_cmd" "$vaults"
}

# Get project status for menu display
# Parameters:
#   $1 - project_display_name
#   $2 - folder_path
# Returns via echo: "status_text|status_color"
get_project_status() {
    local project_name="$1"
    local folder_path="$2"

    local status_text=""
    local status_color=""

    if is_project_running "$project_name"; then
        status_text="running"
        status_color="${GREEN}"
    else
        if [ -d "$folder_path" ]; then
            status_text="stopped"
            status_color="${DIM}"
        else
            status_text="not found"
            status_color="${RED}"
        fi
    fi

    echo "${status_text}|${status_color}"
}

# Get workspace status using nameref (no subshell)
# Parameters:
#   $1 - workspace_file path
#   $2 - nameref for icon
#   $3 - nameref for text
get_workspace_status_ref() {
    local workspace_file="$1"
    local -n _icon=$2
    local -n _text=$3

    if is_workspace_active "$workspace_file"; then
        _icon="${BRIGHT_GREEN}●${NC}"
        _text="${DIM}active${NC}"
    else
        _icon="${DIM}○${NC}"
        _text="${DIM}inactive${NC}"
    fi
}
