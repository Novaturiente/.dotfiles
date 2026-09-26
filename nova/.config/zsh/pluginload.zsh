
source $HOME/.config/zsh/plugins/zsh-sudo.zsh
source $HOME/.config/zsh/plugins/autopair.zsh
source $HOME/.config/zsh/plugins/auto-venv.zsh
# Theme for fast-syntax-highlighting lives in ~/.config/fsh/current.ini (generated),
# activated once with `fast-theme XDG:current` (persisted in ~/.cache/fast-syntax-highlighting).
source $HOME/.config/zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh

# deja — inline ghost-text suggestions (replaces zsh-autosuggestions; it stands
# down if that plugin is loaded). Both vars are read once at init, so set first.
export DEJA_HIGHLIGHT_STYLE='fg=#6c7086'   # Catppuccin Mocha overlay0
export DEJA_CYCLE_KEY='^N'                 # default is Tab, which would steal it from the completion menu
if [[ -r "$HOME/.local/share/deja/init.zsh" ]]; then
  source "$HOME/.local/share/deja/init.zsh"
elif (( $+commands[deja] )); then
  eval "$(deja init zsh)"                  # first run: writes init.zsh
fi
