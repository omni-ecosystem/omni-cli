#!/bin/bash

# Source dependencies (BASE_DIR is passed from index.sh)
source "$ECOSYSTEM/omni-ui-kit/index.sh"
source "$BASE_DIR/modules/config/json.sh"

config_dir=$(get_config_directory)
layouts_dir="$config_dir/layouts"
mkdir -p "$layouts_dir" 2>/dev/null

while true; do
    clear

    # Get list of layout files
    layout_files=()
    if [ -d "$layouts_dir" ]; then
        while IFS= read -r file; do
            layout_files+=("$file")
        done < <(find "$layouts_dir" -maxdepth 1 -name "*.json" -type f 2>/dev/null | sort)
    fi

    layout_count=${#layout_files[@]}

    # Get terminal height for flex layout
    term_height=$(tput lines 2>/dev/null || echo 24)

    # Calculate content heights
    # Top: 1 empty + 1 header + 1 empty + list lines (or 2 if empty)
    if [ "$layout_count" -eq 0 ]; then
        top_lines=5  # empty + header + empty + "no layouts" + empty
    else
        top_lines=$((3 + layout_count + 1))  # empty + header + empty + items + empty
    fi

    # Bottom: menu items + empty + prompt
    if [ "$layout_count" -gt 0 ]; then
        bottom_lines=7  # load + save + overwrite + delete + back + empty + prompt
    else
        bottom_lines=4  # save + back + empty + prompt
    fi

    # Calculate spacer
    spacer=$((term_height - top_lines - bottom_lines))
    [[ $spacer -lt 1 ]] && spacer=1

    # === TOP SECTION: Header + List ===
    echo ""
    echo -e " ${BRIGHT_WHITE}Layouts${NC}"
    echo ""

    if [ "$layout_count" -eq 0 ]; then
        echo -e " ${DIM}No layouts configured.${NC}"
        echo ""
    else
        counter=1
        for layout_file in "${layout_files[@]}"; do
            layout_name=""
            if command -v jq >/dev/null 2>&1 && [ -f "$layout_file" ]; then
                layout_name=$(jq -r '.layoutName // empty' "$layout_file" 2>/dev/null)
            fi

            if [ -z "$layout_name" ]; then
                layout_name=$(basename "$layout_file" .json)
            fi

            echo -e " ${BRIGHT_CYAN}${counter}.${NC} ${BRIGHT_WHITE}${layout_name}${NC}"
            counter=$((counter + 1))
        done
        echo ""
    fi

    # === SPACER: Push menu to bottom ===
    for ((i=0; i<spacer; i++)); do echo ""; done

    # === BOTTOM SECTION: Menu + Input ===
    [[ $layout_count -gt 0 ]] && echo -e " $(menu_num_cmd '' "$layout_count" 'load layout' "$MENU_COLOR_OPEN")"
    echo -e " $(menu_cmd 's' 'save layout' "$MENU_COLOR_ADD")"
    [[ $layout_count -gt 0 ]] && echo -e " $(menu_cmd 'o' 'overwrite layout' "$MENU_COLOR_EDIT")"
    [[ $layout_count -gt 0 ]] && echo -e " $(menu_cmd 'd' 'delete layout' "$MENU_COLOR_DELETE")"
    echo -e " $(menu_cmd 'b' 'back' "$MENU_COLOR_NAV")"
    echo ""
    echo -ne " ${BRIGHT_CYAN}>${NC} "

    # Read input (with ESC support)
    IFS= read -r -s -n 1 choice

    # ESC to close
    if [[ "$choice" == $'\x1b' ]]; then
        exit 0
    fi
    echo ""

    case "$choice" in
        [0-9])
            # Instant load if number matches a layout
            if [[ $layout_count -gt 0 ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "$layout_count" ]]; then
                idx=$((choice - 1))
                selected_layout="${layout_files[$idx]}"
                workspaces_file="$config_dir/.workspaces.json"

                if [[ -f "$selected_layout" ]] && [[ -f "$workspaces_file" ]]; then
                    new_active_config=$(jq '.activeConfig' "$selected_layout")
                    jq --argjson active "$new_active_config" '.activeConfig = $active' "$workspaces_file" > "${workspaces_file}.tmp" \
                        && mv "${workspaces_file}.tmp" "$workspaces_file"
                fi
                exit 0
            fi
            ;;
        s|S)
            echo ""
            echo -ne " ${BRIGHT_WHITE}Layout name (ESC to cancel):${NC} "

            # Read with ESC support
            layout_name=""
            while true; do
                IFS= read -r -s -n 1 char
                # ESC key
                if [[ "$char" == $'\x1b' ]]; then
                    layout_name=""
                    echo ""
                    break
                fi
                # Enter key
                if [[ -z "$char" ]]; then
                    echo ""
                    break
                fi
                # Backspace
                if [[ "$char" == $'\x7f' ]] || [[ "$char" == $'\x08' ]]; then
                    if [[ -n "$layout_name" ]]; then
                        layout_name="${layout_name%?}"
                        echo -ne "\b \b"
                    fi
                    continue
                fi
                layout_name+="$char"
                echo -n "$char"
            done

            if [[ -n "$layout_name" ]]; then
                # Get current activeConfig from .workspaces.json
                workspaces_file="$config_dir/.workspaces.json"

                # Check if there are any active workspaces
                if command -v jq >/dev/null 2>&1 && [ -f "$workspaces_file" ]; then
                    active_count=$(jq '.activeConfig | length' "$workspaces_file" 2>/dev/null)
                    if [[ -z "$active_count" ]] || [[ "$active_count" -eq 0 ]]; then
                        echo ""
                        echo -e " ${RED}No active workspaces to save.${NC}"
                        sleep 1.5
                        continue
                    fi
                fi

                filename=$(echo "$layout_name" | tr ' ' '_' | tr -cd '[:alnum:]_-')
                layout_file="$layouts_dir/${filename}.json"

                if command -v jq >/dev/null 2>&1 && [ -f "$workspaces_file" ]; then
                    # Extract activeConfig and save with layout name
                    jq -n \
                        --arg name "$layout_name" \
                        --argjson activeConfig "$(jq '.activeConfig' "$workspaces_file")" \
                        '{layoutName: $name, activeConfig: $activeConfig}' \
                        > "$layout_file"
                fi
            fi
            ;;
        o|O)
            if [[ $layout_count -gt 0 ]]; then
                echo ""
                echo -ne " ${BRIGHT_WHITE}Overwrite layout # (ESC to cancel):${NC} "

                # Read number with ESC support
                overwrite_num=""
                while true; do
                    IFS= read -r -s -n 1 char
                    # ESC key
                    if [[ "$char" == $'\x1b' ]]; then
                        overwrite_num=""
                        echo ""
                        break
                    fi
                    # Enter key
                    if [[ -z "$char" ]]; then
                        echo ""
                        break
                    fi
                    # Backspace
                    if [[ "$char" == $'\x7f' ]] || [[ "$char" == $'\x08' ]]; then
                        if [[ -n "$overwrite_num" ]]; then
                            overwrite_num="${overwrite_num%?}"
                            echo -ne "\b \b"
                        fi
                        continue
                    fi
                    # Only accept digits
                    if [[ "$char" =~ ^[0-9]$ ]]; then
                        overwrite_num+="$char"
                        echo -n "$char"
                    fi
                done

                # Validate and overwrite
                if [[ -n "$overwrite_num" ]] && [[ "$overwrite_num" -ge 1 ]] && [[ "$overwrite_num" -le "$layout_count" ]]; then
                    idx=$((overwrite_num - 1))
                    file_to_overwrite="${layout_files[$idx]}"

                    # Get layout name for confirmation
                    layout_name=""
                    if command -v jq >/dev/null 2>&1 && [ -f "$file_to_overwrite" ]; then
                        layout_name=$(jq -r '.layoutName // empty' "$file_to_overwrite" 2>/dev/null)
                    fi
                    if [ -z "$layout_name" ]; then
                        layout_name=$(basename "$file_to_overwrite" .json)
                    fi

                    # Confirm overwrite
                    echo -ne " ${YELLOW}Overwrite '${layout_name}'? (y/n):${NC} "
                    IFS= read -r -s -n 1 confirm
                    echo ""

                    if [[ "$confirm" == "y" ]] || [[ "$confirm" == "Y" ]]; then
                        workspaces_file="$config_dir/.workspaces.json"

                        # Check if there are any active workspaces
                        if command -v jq >/dev/null 2>&1 && [ -f "$workspaces_file" ]; then
                            active_count=$(jq '.activeConfig | length' "$workspaces_file" 2>/dev/null)
                            if [[ -z "$active_count" ]] || [[ "$active_count" -eq 0 ]]; then
                                echo ""
                                echo -e " ${RED}No active workspaces to save.${NC}"
                                sleep 1.5
                                continue
                            fi

                            # Overwrite with current activeConfig, keeping layout name
                            jq -n \
                                --arg name "$layout_name" \
                                --argjson activeConfig "$(jq '.activeConfig' "$workspaces_file")" \
                                '{layoutName: $name, activeConfig: $activeConfig}' \
                                > "$file_to_overwrite"
                        fi
                    fi
                fi
            fi
            ;;
        d|D)
            if [[ $layout_count -gt 0 ]]; then
                echo ""
                echo -ne " ${BRIGHT_WHITE}Delete layout # (ESC to cancel):${NC} "

                # Read number with ESC support
                delete_num=""
                while true; do
                    IFS= read -r -s -n 1 char
                    # ESC key
                    if [[ "$char" == $'\x1b' ]]; then
                        delete_num=""
                        echo ""
                        break
                    fi
                    # Enter key
                    if [[ -z "$char" ]]; then
                        echo ""
                        break
                    fi
                    # Backspace
                    if [[ "$char" == $'\x7f' ]] || [[ "$char" == $'\x08' ]]; then
                        if [[ -n "$delete_num" ]]; then
                            delete_num="${delete_num%?}"
                            echo -ne "\b \b"
                        fi
                        continue
                    fi
                    # Only accept digits
                    if [[ "$char" =~ ^[0-9]$ ]]; then
                        delete_num+="$char"
                        echo -n "$char"
                    fi
                done

                # Validate and delete
                if [[ -n "$delete_num" ]] && [[ "$delete_num" -ge 1 ]] && [[ "$delete_num" -le "$layout_count" ]]; then
                    idx=$((delete_num - 1))
                    file_to_delete="${layout_files[$idx]}"
                    rm -f "$file_to_delete"
                fi
            fi
            ;;
        b|B)
            exit 0
            ;;
    esac
done
