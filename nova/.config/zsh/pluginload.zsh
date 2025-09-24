
source $HOME/.config/zsh/plugins/zsh-256color.plugin.zsh
source $HOME/.config/zsh/plugins/zsh-sudo.zsh
source $HOME/.config/zsh/plugins/autopair.zsh
source $HOME/.config/zsh/plugins/auto-venv.zsh
source $HOME/.config/zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh
source $HOME/.config/zsh/plugins/zsh-autosuggestions.zsh
source $HOME/.config/zsh/plugins/zsh-autocomplete/zsh-autocomplete.plugin.zsh

HISTDB_TABULATE_CMD=(sed -e $'s/\x1f/\t/g')
source $HOME/.config/zsh/plugins/zsh-histdb/sqlite-history.zsh
autoload -Uz add-zsh-hook

ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#808080"
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
