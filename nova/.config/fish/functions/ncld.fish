# Open Neovim as a single full-window Claude Code pane (skips permissions).
function ncld
    nvim --cmd 'let g:ncld = 1' $argv
end
