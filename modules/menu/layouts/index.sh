#!/bin/bash

# ========================================
# Layouts Menu Module
# ========================================
# This module handles layout management
# Usage: source modules/menu/layouts/index.sh

# Function to show layout menu in tmux popup
show_layout_menu() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    tmux display-popup -E -w 50% -h 60% "BASE_DIR='$BASE_DIR' IS_INSTALLED='$IS_INSTALLED' ECOSYSTEM='$ECOSYSTEM' bash $script_dir/layouts.sh"
}
