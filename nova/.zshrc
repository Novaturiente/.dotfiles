# ---- ZSH Configuration ----
HISTFILE=$XDG_CONFIG_HOME/zsh/.histfile
HISTSIZE=1000
SAVEHIST=1000

setopt extendedglob nonomatch
setopt notify  
setopt autocd
setopt append_history inc_append_history share_history
setopt hist_ignore_dups hist_ignore_all_dups hist_reduce_blanks
setopt no_case_glob no_case_match
setopt auto_menu menu_complete
setopt prompt_sp
setopt auto_pushd pushd_ignore_dups

# ---- Compinit ----
autoload -Uz compinit
zcompdump="${ZDOTDIR:-$HOME}/.zcompdump"
if [[ ! -s $zcompdump || $zcompdump -ot ~/.zshrc ]]; then
  compinit -C
else
  compinit -C
fi
autoload -U colors && colors

#cmp opts
zstyle ':completion:*' menu select
zstyle ':completion:*' special-dirs true
zstyle ':completion:*' squeeze-slashes false 
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS} ma=0\;33 
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=*'

# ---- Key Bindings for Special Keys ----
bindkey "^[[3~" delete-char         # Delete
bindkey "^[[1~" beginning-of-line   # Home
bindkey "^[[4~" end-of-line         # End
bindkey "^[[H" beginning-of-line    # Alternate Home
bindkey "^[[F" end-of-line          # Alternate End

# ---- Load Environment Variables ----
source $XDG_CONFIG_HOME/zsh/variables

if [ -f ~/.env.zsh ]; then
  source ~/.env.zsh
fi

# ---- Initialize Zoxide ----
eval "$(zoxide init zsh)"

# ---- FZF Configuration ----
source <(fzf --zsh)

# ---- Aliases ----
source $XDG_CONFIG_HOME/zsh/aliases

# ---- Prompt Sourcing ----
source $XDG_CONFIG_HOME/zsh/prompt.zsh 

# ---- Plugin and Theme Sourcing ----
source $XDG_CONFIG_HOME/zsh/pluginload
