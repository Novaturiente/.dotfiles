# ---- ZSH Configuration ----
HISTFILE=$XDG_CONFIG_HOME/zsh/.histfile
HISTSIZE=1000
SAVEHIST=1000

setopt extendedglob notify
setopt nonomatch
setopt autocd
setopt append_history inc_append_history share_history
setopt no_case_glob no_case_match
setopt auto_menu menu_complete
setopt prompt_sp

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

# ---- Compinit ----
autoload -U compinit && compinit
autoload -U colors && colors

#cmp opts
zstyle ':completion:*' menu select
zstyle ':completion:*' special-dirs true
zstyle ':completion:*' squeeze-slashes false 
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS} ma=0\;33 

# ---- Key Bindings for Special Keys ----
bindkey "^[[3~" delete-char         # Delete
bindkey "^[[1~" beginning-of-line   # Home
bindkey "^[[4~" end-of-line         # End
bindkey "^[[H" beginning-of-line    # Alternate Home
bindkey "^[[F" end-of-line          # Alternate End

# ---- Prompt Sourcing ----
source $XDG_CONFIG_HOME/zsh/prompt.zsh 

# ---- Plugin and Theme Sourcing ----
source $XDG_CONFIG_HOME/zsh/pluginload
