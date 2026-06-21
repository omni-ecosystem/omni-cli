#!/bin/bash

# ========================================
# Secure Files - Vault Selection Menu
# ========================================
# Show vault selection screen with add/move options
# Usage: source modules/settings/projects/secure/menu.sh

# Show vault selection screen
# Parameters: workspace_file, project_path
# Returns: 10 for add, 20 for move, 1 if cancelled/no vaults
select_vault_screen() {
    local workspace_file="$1"
    local project_path="$2"

    local -a vaults=()
    load_vaults vaults

    local project_name=$(basename "$project_path")

    if [ ${#vaults[@]} -eq 0 ]; then
        clear
        print_header "SECURE FILES"
        echo ""
        echo -e "${DIM}No vaults configured. Add a vault in Settings > Secrets first.${NC}"
        echo ""
        wait_for_enter
        return 1
    fi

    # Check if any vaults are mounted
    local has_mounted=false
    for vault_info in "${vaults[@]}"; do
        IFS=':' read -r name _ mount_point _ <<< "$vault_info"
        if get_vault_status "$mount_point"; then
            has_mounted=true
            break
        fi
    done

    if [ "$has_mounted" = false ]; then
        clear
        print_header "SECURE FILES"
        echo ""
        echo -e "${DIM}No vaults are currently mounted. Mount a vault first.${NC}"
        echo ""
        wait_for_enter
        return 1
    fi

    # Pre-scan: check if any mounted vault has files for this project.
    # Determines display mode: filter+both-ops vs show-all+add-only.
    local has_any_files=false
    for vault_info in "${vaults[@]}"; do
        IFS=':' read -r _ _ mount_point _ <<< "$vault_info"
        if get_vault_status "$mount_point"; then
            local vpc="${mount_point}/${project_name}"
            if [ -d "$vpc" ] && [ -n "$(find "$vpc" -type f 2>/dev/null | head -1)" ]; then
                has_any_files=true
                break
            fi
        fi
    done

    while true; do
        clear
        print_header "SELECT VAULT"
        echo ""
        echo -e "${DIM}Select a mounted vault:${NC}"
        echo ""

        local counter=1
        local -a mounted_indices=()
        for i in "${!vaults[@]}"; do
            local vault_info="${vaults[$i]}"
            IFS=':' read -r name _ mount_point _ <<< "$vault_info"

            if get_vault_status "$mount_point"; then
                local vault_project_dir="${mount_point}/${project_name}"
                local -a secured_files=()
                if [ -d "$vault_project_dir" ]; then
                    while IFS= read -r f; do
                        secured_files+=("$(basename "$f")")
                    done < <(find "$vault_project_dir" -type f 2>/dev/null | sort)
                fi

                local secured_count=${#secured_files[@]}

                # If some vault has files: only list vaults that have files
                [ "$has_any_files" = true ] && [ "$secured_count" -eq 0 ] && continue

                if [ "$secured_count" -gt 0 ]; then
                    local preview="${secured_files[0]}"
                    [ "$secured_count" -ge 2 ] && preview+=", ${secured_files[1]}"
                    [ "$secured_count" -ge 3 ] && preview+=", ${secured_files[2]}"
                    [ "$secured_count" -gt 3 ] && preview+=" +$((secured_count - 3)) more"
                    echo -e "  ${BRIGHT_CYAN}${counter}${NC}  ${BRIGHT_GREEN}●${NC} ${BOLD}${BRIGHT_WHITE}${name}${NC}"
                    echo -e "      ${DIM}${mount_point}${NC}"
                    echo -e "      ${DIM}secured · ${NC}${BRIGHT_WHITE}${preview}${NC}"
                else
                    echo -e "  ${BRIGHT_CYAN}${counter}${NC}  ${BRIGHT_GREEN}●${NC} ${BOLD}${BRIGHT_WHITE}${name}${NC}"
                    echo -e "      ${DIM}${mount_point}${NC}"
                    echo -e "      ${DIM}nothing secured yet${NC}"
                fi

                mounted_indices+=("$i")
                counter=$((counter + 1))
            fi
        done

        echo ""

        local vault_count="${#mounted_indices[@]}"
        menu_line \
            "$(menu_num_cmd 'a' "$vault_count" 'add to vault' "$MENU_COLOR_ADD")" \
            "$( [ "$has_any_files" = true ] && menu_num_cmd 'm' "$vault_count" 'move from vault' "$MENU_COLOR_ACTION")" \
            "$(menu_cmd 'b' 'back' "$MENU_COLOR_NAV")"
        echo ""
        echo -ne "${BRIGHT_CYAN}>${NC} "

        local choice
        read_with_instant_back choice

        if [[ "$choice" == "b" ]]; then
            return 1
        fi

        # Check for add operation (a1, a2, etc.)
        if [[ "$choice" =~ ^[Aa]([0-9]+)$ ]]; then
            local vault_num="${BASH_REMATCH[1]}"
            if [ "$vault_num" -ge 1 ] && [ "$vault_num" -le "$vault_count" ]; then
                local selected_idx="${mounted_indices[$((vault_num - 1))]}"
                local vault_info="${vaults[$selected_idx]}"
                IFS=':' read -r SELECTED_VAULT_NAME _ SELECTED_VAULT_MOUNT _ <<< "$vault_info"
                return 10  # Return code for "add"
            fi
        fi

        # Check for move operation (m1, m2, etc.)
        if [[ "$choice" =~ ^[Mm]([0-9]+)$ ]]; then
            local vault_num="${BASH_REMATCH[1]}"
            if [ "$vault_num" -ge 1 ] && [ "$vault_num" -le "$vault_count" ]; then
                local selected_idx="${mounted_indices[$((vault_num - 1))]}"
                local vault_info="${vaults[$selected_idx]}"
                IFS=':' read -r SELECTED_VAULT_NAME _ SELECTED_VAULT_MOUNT _ <<< "$vault_info"
                return 20  # Return code for "move"
            fi
        fi
    done
}
