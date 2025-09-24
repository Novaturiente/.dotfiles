# ---- ZSH Configuration ----
HISTFILE=$XDG_CONFIG_HOME/zsh/.histfile
HISTSIZE=10000
SAVEHIST=10000

# ---- Load Environment Variables ----
source $XDG_CONFIG_HOME/zsh/variables.zsh
if [ -f ~/.env.zsh ]; then
  source ~/.env.zsh
fi

# Change cursor to vertical bar when inside tmux
if [ -n "$TMUX" ]; then
  echo -ne "\e[3 q"
fi

setopt extendedglob nonomatch
setopt notify
setopt autocd
setopt CORRECT
setopt append_history inc_append_history share_history
setopt hist_ignore_dups hist_ignore_all_dups hist_reduce_blanks
setopt no_case_glob no_case_match
setopt auto_menu menu_complete
setopt auto_pushd pushd_ignore_dups

# ---- Key Bindings for Special Keys ----
bindkey "^[[3~" delete-char         # Delete
bindkey "^[[1~" beginning-of-line   # Home
bindkey "^[[4~" end-of-line         # End
bindkey "^[[H" beginning-of-line    # Alternate Home
bindkey "^[[F" end-of-line          # Alternate End
bindkey "^l" clear-screen

#cmp opts
zstyle ':completion:*' menu select
zstyle ':completion:*' special-dirs true
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS} ma=0\;33
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=*'
zstyle ':completion:*' verbose yes
zstyle ':completion:*:descriptions' format '%B%d%b'
zstyle ':completion:*' group-name ''
zstyle ':completion::complete::' group-order files local-directories
zstyle ':completion:*' file-sort modification

export PATH="$HOME/.local/bin:$PATH"

# ---- Initialize Zoxide ----
eval "$(zoxide init zsh)"
# ---- FZF Configuration ----
source <(fzf --zsh)
# ---- Aliases ----
source $XDG_CONFIG_HOME/zsh/aliases.zsh
# ---- Prompt Sourcing ----
source $XDG_CONFIG_HOME/zsh/prompt.zsh
# ---- Functions ----
source $XDG_CONFIG_HOME/zsh/functions.zsh
# ---- Plugin and Theme Sourcing ----
source $XDG_CONFIG_HOME/zsh/pluginload.zsh

# ---- Compinit ----
autoload -Uz compinit
zcompdump="${ZDOTDIR:-$HOME}/.zcompdump"

if [[ "$(date +'%j')" != "$(stat -c '%y' "$zcompdump" 2>/dev/null | cut -d' ' -f1)" ]]; then
  compinit
  # Optional: compile dump for faster load next time
  zcompile "$zcompdump"
else
  compinit -C
fi
autoload -U colors && colors

. "$HOME/.local/share/../bin/env"
