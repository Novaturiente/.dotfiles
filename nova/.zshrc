# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
setopt extendedglob notify
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '/home/nova/.zshrc'
autoload -Uz compinit
compinit
# End of lines added by compinstall

source ~/.zsh/prompt.zsh
# source ~/.zsh/zsh-256color.plugin.zsh
source ~/.zsh/zsh-sudo.zsh
source ~/.zsh/autopair.zsh
source ~/.zsh/auto-venv.zsh
source ~/.zsh/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh

source ~/.zsh/zsh-autosuggestions.zsh
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#808080"
