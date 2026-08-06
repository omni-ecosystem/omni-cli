#!/bin/bash

# ========================================
# Workspaces Module Index
# ========================================
# Main entry point for all workspace modules
# This file imports and makes available all workspace functions
# Usage: source modules/settings/workspaces/index.sh

# Get the directory where this script is located
WORKSPACES_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Import all workspace modules in dependency order
source "$WORKSPACES_DIR/components.sh"     # UI components
source "$WORKSPACES_DIR/add.sh"            # Add/create workspace functionality
source "$WORKSPACES_DIR/delete.sh"         # Delete workspace functionality
source "$WORKSPACES_DIR/rename.sh"         # Rename workspace functionality
source "$WORKSPACES_DIR/toggle.sh"         # Toggle workspace active/inactive
source "$WORKSPACES_DIR/reorder.sh"        # Reorder workspaces in the list
source "$WORKSPACES_DIR/manage.sh"         # Manage workspace (depends on delete, rename)
