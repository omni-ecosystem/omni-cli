#!/bin/bash

# ========================================
# Projects Module Index
# ========================================
# Main entry point for all project modules
# This file imports and makes available all project functions
# Usage: source modules/settings/projects/index.sh

# Get the directory where this script is located
PROJECTS_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Import all project modules in dependency order
source "$PROJECTS_DIR/components.sh"       # UI components
source "$PROJECTS_DIR/add.sh"              # Add project functionality
source "$PROJECTS_DIR/remove.sh"           # Remove project functionality
source "$PROJECTS_DIR/edit.sh"             # Edit project functionality
source "$PROJECTS_DIR/reorder.sh"          # Reorder project functionality
source "$PROJECTS_DIR/secure/index.sh"     # Secure files to vault
