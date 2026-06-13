# omni-ui-kit

Terminal styling primitives for bash — colors, UI components, and animations.

## Usage

```bash
source libs/omni-ui-kit/index.sh
```

Or load individual modules:

```bash
source libs/omni-ui-kit/colors.sh      # just colors
source libs/omni-ui-kit/ui.sh          # colors + UI components
source libs/omni-ui-kit/animations.sh  # colors + loading spinner
```

`ui.sh` and `animations.sh` auto-source `colors.sh` if needed.

## Colors

### Variables

| Variable | Value |
|----------|-------|
| `RED`, `GREEN`, `BLUE`, `WHITE` | Basic colors |
| `BRIGHT_RED`, `BRIGHT_GREEN`, `BRIGHT_YELLOW` | Bright variants |
| `BRIGHT_BLUE`, `BRIGHT_PURPLE`, `BRIGHT_CYAN`, `BRIGHT_WHITE` | Bright variants |
| `BOLD`, `ITALIC`, `DIM` | Text styles |
| `NC` | Reset / no color |

### Functions

```bash
print_color "$BRIGHT_CYAN" "colored text"
```

## UI Components

```bash
print_header "TITLE"          # Bold title with underline
print_separator               # Horizontal rule (optional color arg)
print_success "it worked"     # [success] green
print_error "it broke"        # [error] red
print_warning "watch out"     # [warning] yellow
print_info "fyi"              # [info] white
print_step "doing thing"      # → blue
print_warning_box             # Boxed warning banner
wait_for_enter                # "Press Enter to continue..." prompt
get_terminal_width            # Returns width (clamped 60-120)
```

## Animations

```bash
show_loading "Loading config" 3   # Braille spinner for 3 seconds
show_loading "Quick task"         # Default: 2 seconds
```

## File structure

```
omni-ui-kit/
  index.sh       — loads all modules
  colors.sh      — color variables + print_color
  ui.sh          — headers, messages, separators
  animations.sh  — loading spinner
```
