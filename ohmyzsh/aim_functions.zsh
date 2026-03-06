# AIM Show log management functions
# Usage: aimlog [action]
# Actions: tail (default), head, cat, open, edit, less, cd

AIMSHOW_ROOT="/d/AIMSHOW"

# Help text for aimlog
_aimlog_help() {
    cat <<'EOF'
aimlog - Browse and interact with AIM show logs using fzf

USAGE:
    aimlog [ACTION]

ACTIONS:
    tail      Follow log in real-time (default)
    tail100   Show last 100 lines
    head      Show first 100 lines
    cat       Print entire file
    open      Open in Windows default application
    edit      Open in $EDITOR (defaults to VS Code)
    less      View in less (starts at end)
    cd        Change to log's directory
    path      Print full path to log

ALIASES:
    aimtail, aimhead, aimopen, aimedit, aimless, aimcd

RELATED COMMANDS:
    aimshow   Select a show and cd to its Logs directory
    aimapp    Select a log within the current show directory

EXAMPLES:
    aimlog            # Select log with fzf, then tail -f
    aimlog open       # Select log, open in default app
    aimlog edit       # Select log, open in editor
    aimshow           # Jump to a show's Logs folder
    aimapp tail100    # When in a show dir, pick log and show last 100 lines
EOF
}

# Main log function - multi-step selection: Show -> App -> Log -> Action
aimlog() {
    local action="${1:-tail}"

    # Handle help option
    if [[ "$action" == "-h" || "$action" == "--help" ]]; then
        _aimlog_help
        return 0
    fi
    
    # Validate AIMSHOW_ROOT exists
    if [[ ! -d "$AIMSHOW_ROOT" ]]; then
        echo "Error: AIMSHOW_ROOT directory not found: $AIMSHOW_ROOT"
        return 1
    fi

    # Step 1: Select show
    local show
    show=$(find "$AIMSHOW_ROOT" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | \
        xargs -I{} basename {} | \
        sort | \
        fzf --prompt="Select show: " --height=50%)
    
    [[ -z "$show" ]] && return 0

    local logs_dir="$AIMSHOW_ROOT/$show/Logs"
    if [[ ! -d "$logs_dir" ]]; then
        echo "No Logs directory found for show: $show"
        return 1
    fi

    # Step 2: Select application
    local app
    app=$(find "$logs_dir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | \
        xargs -I{} basename {} | \
        sort | \
        fzf --prompt="[$show] Select app: " --height=50%)
    
    [[ -z "$app" ]] && return 0

    local app_dir="$logs_dir/$app"

    # Step 3: Select log file
    local log
    log=$(find "$app_dir" -maxdepth 1 -name "*.log" -type f 2>/dev/null | \
        xargs -I{} basename {} | \
        sort | \
        fzf --prompt="[$show/$app] Select log ($action): " \
            --preview="tail -50 '$app_dir/{}'" \
            --preview-window=right:60%:wrap \
            --height=80%)
    
    [[ -z "$log" ]] && return 0

    local full_path="$app_dir/$log"

    if [[ ! -f "$full_path" ]]; then
        echo "Error: Log file not found: $full_path"
        return 1
    fi

    # Execute action
    _aimlog_exec "$action" "$full_path"
}

# Execute action on a log file
_aimlog_exec() {
    local action="$1"
    local full_path="$2"

    case "$action" in
        tail)
            tail -f "$full_path"
            ;;
        tail100)
            tail -100 "$full_path"
            ;;
        head)
            head -100 "$full_path"
            ;;
        cat)
            cat "$full_path"
            ;;
        open)
            start "" "$full_path"
            ;;
        edit)
            ${EDITOR:-code} "$full_path"
            ;;
        less)
            less +G "$full_path"
            ;;
        cd)
            cd "$(dirname "$full_path")"
            ;;
        path)
            echo "$full_path"
            ;;
        *)
            echo "Unknown action: $action"
            echo "Available actions: tail, tail100, head, cat, open, edit, less, cd, path"
            return 1
            ;;
    esac
}

# Convenience aliases for common actions
alias aimtail='aimlog tail'
alias aimhead='aimlog head'
alias aimopen='aimlog open'
alias aimedit='aimlog edit'
alias aimless='aimlog less'
alias aimcd='aimlog cd'

# Quick show selector - just cd to a show's Logs directory
aimshow() {
    local selected
    selected=$(find "$AIMSHOW_ROOT" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | \
        xargs -I{} basename {} | \
        sort | \
        fzf --prompt="Select show: " --height=50%)
    
    [[ -z "$selected" ]] && return 0
    
    local logs_dir="$AIMSHOW_ROOT/$selected/Logs"
    if [[ -d "$logs_dir" ]]; then
        cd "$logs_dir"
    else
        echo "No Logs directory found for show: $selected"
        cd "$AIMSHOW_ROOT/$selected"
    fi
}

# Quick app selector within current show context (two-step: app -> log)
aimapp() {
    local action="${1:-tail}"
    local current_show=""
    
    # Try to detect current show from pwd
    if [[ "$PWD" == *"$AIMSHOW_ROOT"* ]]; then
        current_show=$(echo "$PWD" | sed "s|$AIMSHOW_ROOT/||" | cut -d'/' -f1)
    fi
    
    if [[ -z "$current_show" ]]; then
        echo "Not in a show directory. Use 'aimshow' to select a show first, or use 'aimlog'."
        return 1
    fi
    
    local logs_base="$AIMSHOW_ROOT/$current_show/Logs"

    # Step 1: Select application
    local app
    app=$(find "$logs_base" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | \
        xargs -I{} basename {} | \
        sort | \
        fzf --prompt="[$current_show] Select app: " --height=50%)
    
    [[ -z "$app" ]] && return 0

    local app_dir="$logs_base/$app"

    # Step 2: Select log file
    local log
    log=$(find "$app_dir" -maxdepth 1 -name "*.log" -type f 2>/dev/null | \
        xargs -I{} basename {} | \
        sort | \
        fzf --prompt="[$current_show/$app] Select log ($action): " \
            --preview="tail -50 '$app_dir/{}'" \
            --preview-window=right:60%:wrap \
            --height=80%)
    
    [[ -z "$log" ]] && return 0

    local full_path="$app_dir/$log"
    
    _aimlog_exec "$action" "$full_path"
}

# Show open GitLab merge requests authored by the authenticated user.
open_mrs() {
    local uv_cmd
    local script_path

    uv_cmd=$(command -v uv || true)
    if [[ -z "$uv_cmd" ]]; then
        echo "Error: uv not found in PATH. Install it from https://docs.astral.sh/uv/" >&2
        return 1
    fi

    script_path="$HOME/configs/scripts/open_mrs.py"
    if [[ ! -f "$script_path" ]]; then
        echo "Error: script not found: $script_path" >&2
        return 1
    fi

    "$uv_cmd" run "$script_path" "$@"
}

# Zsh completions for aimlog and aimapp
_aimlog_actions=(tail tail100 head cat open edit less cd path)

_aimlog() {
    _describe 'action' _aimlog_actions
}

compdef _aimlog aimlog
compdef _aimlog aimapp

# Play media files with VLC
vlc() {
    "/c/Program Files/VideoLAN/VLC/vlc.exe" "$@" &>/dev/null &disown
}
