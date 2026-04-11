#!/bin/bash
# Opens a file in the Emacs editor pane (skips vterm/treemacs windows)
# Used by Claude Code PostToolUse hook
file=$(jq -r '.tool_input.file_path // empty')
[ -z "$file" ] && exit 0
emacsclient -e "(my/open-in-editor \"$file\")" 2>/dev/null || emacsclient -n "$file" 2>/dev/null
