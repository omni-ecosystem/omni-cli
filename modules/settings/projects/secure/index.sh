#!/bin/bash

# ========================================
# Secure Files Module
# ========================================
# Move files from project to vault and symlink back
# Usage: source modules/settings/projects/secure/index.sh

# Get the directory of this script
SECURE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Global for selected vault info
declare -g SELECTED_VAULT_NAME=""
declare -g SELECTED_VAULT_MOUNT=""

# Cache for vault lookups (populated by init_vault_lookup)
declare -gA VAULT_MOUNT_MAP=()    # mount_point -> vault_name
declare -ga VAULT_MOUNT_LIST=()   # ordered list of mount points

# Source sub-modules
source "$SECURE_DIR/menu.sh"
source "$SECURE_DIR/add.sh"
source "$SECURE_DIR/move.sh"

# Main flow orchestrator
# Parameters: workspace_file, project_display_name, project_path
show_secure_files_flow() {
    local workspace_file="$1"
    local project_display_name="$2"
    local project_path="$3"
    local project_name=$(basename "$project_path")

    # omni-secrets is sourced lazily; ensure it's loaded so load_vaults and
    # get_vault_status are available even if the Secrets menu wasn't visited yet
    if ! ensure_secrets_loaded; then
        clear
        print_header "SECURE FILES"
        echo ""
        print_error "Failed to load secrets module"
        echo ""
        wait_for_enter
        return 1
    fi

    while true; do
        # Step 1: Select vault and operation
        select_vault_screen "$workspace_file" "$project_path"
        local operation=$?

        if [ $operation -eq 1 ]; then
            return 1  # User cancelled
        elif [ $operation -eq 10 ]; then
            # Add to vault operation
            # Step 2: Browse and mark files
            show_interactive_browser "files" "$project_path" "$project_path"

            # Check if any files were marked
            if [ ${#MARKED_FILES[@]} -eq 0 ]; then
                echo ""
                print_warning "No files selected."
                wait_for_enter      
                continue  # Return to vault selection
            fi

            # Step 3: Confirm
            if ! confirm_secure_files "$project_name" "$project_path"; then
                echo ""
                print_warning "Operation cancelled."
                wait_for_enter
                continue  # Return to vault selection
            fi

            # Step 4: Execute and track vault assignment
            execute_secure_files "$project_name" "$project_path"
            assign_vault_to_project "$workspace_file" "$project_path" "$SELECTED_VAULT_NAME"
            return 0
        elif [ $operation -eq 20 ]; then
            # Move from vault operation
            local vault_project_dir="${SELECTED_VAULT_MOUNT}/${project_name}"

            # Check if project directory exists in vault
            if [ ! -d "$vault_project_dir" ]; then
                clear
                print_header "MOVE FROM VAULT"
                echo ""
                echo -e "${DIM}No files found for this project in vault '${SELECTED_VAULT_NAME}'.${NC}"
                echo ""
                wait_for_enter
                continue  # Return to vault selection
            fi

            # Check if there are any files in the vault directory
            local file_count=$(find "$vault_project_dir" -type f 2>/dev/null | wc -l)
            if [ "$file_count" -eq 0 ]; then
                clear
                print_header "MOVE FROM VAULT"
                echo ""
                echo -e "${DIM}No files found for this project in vault '${SELECTED_VAULT_NAME}'.${NC}"
                echo ""
                wait_for_enter
                continue  # Return to vault selection
            fi

            # Step 2: Browse vault and mark files to restore
            show_interactive_browser "files" "$vault_project_dir" "$vault_project_dir"

            # Check if any files were marked
            if [ ${#MARKED_FILES[@]} -eq 0 ]; then
                echo ""
                print_warning "No files selected."
                sleep 1
                continue  # Return to vault selection
            fi

            # Step 3: Confirm
            if ! confirm_move_from_vault "$project_name" "$project_path"; then
                echo ""
                print_warning "Operation cancelled."
                wait_for_enter
                continue  # Return to vault selection
            fi

            # Step 4: Execute
            execute_move_from_vault "$project_name" "$project_path"
            return 0
        fi
    done
}
