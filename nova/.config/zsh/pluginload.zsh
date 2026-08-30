
source $HOME/.config/zsh/plugins/zsh-sudo.zsh
source $HOME/.config/zsh/plugins/autopair.zsh
source $HOME/.config/zsh/plugins/auto-venv.zsh
# Catppuccin Mocha for fast-syntax-highlighting: theme lives in ~/.config/fsh/,
# activated once with `fast-theme XDG:catppuccin-mocha` (persisted in ~/.cache/fast-syntax-highlighting).
source $HOME/.config/zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh
source $HOME/.config/zsh/plugins/zsh-autosuggestions.zsh
source $HOME/.config/zsh/plugins/zsh-autocomplete/zsh-autocomplete.plugin.zsh

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#6c7086"   # Catppuccin Mocha overlay0
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
