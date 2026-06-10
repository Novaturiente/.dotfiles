# Custom key bindings — applied after the vi-mode bindings load.
function fish_user_key_bindings
    # Ctrl-L: clear screen (both insert and command modes)
    bind --mode insert  \cl 'clear; commandline -f repaint'
    bind --mode default \cl 'clear; commandline -f repaint'

    # Esc Esc: toggle `sudo` prefix on the current line (zsh-sudo plugin).
    bind --mode insert  \e\e __sudo_toggle
    bind --mode default \e\e __sudo_toggle

    # jk: exit insert mode (like neovim) — no reach for Esc.
    bind --mode insert -m default jk repaint-mode
end
