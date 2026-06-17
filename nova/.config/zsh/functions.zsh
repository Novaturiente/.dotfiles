# ===================================================================
# Shell functions  (parity with fish functions/)
# ===================================================================

# Open Neovim as a single full-window Claude Code pane (skips permissions).
# Mirror of fish functions/ncld.fish.
ncld() {
    nvim --cmd 'let g:ncld = 1' "$@"
}

# Re-source ~/.env into the current shell without restarting zsh.
# Use after editing ~/.env so already-open sessions pick up new vars.
# Mirror of fish functions/reloadenv.fish.
reloadenv() {
    if [ -f "$HOME/.env" ]; then
        set -a
        source "$HOME/.env"
        set +a
        echo "reloaded ~/.env"
    else
        echo "~/.env not found" >&2
        return 1
    fi
}
