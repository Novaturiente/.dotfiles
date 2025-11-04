# ===================================================================
# ZSH CONFIGURATION
# ===================================================================

# -------------------------------------------------------------------
# Environment Variables & Path
# -------------------------------------------------------------------
source $XDG_CONFIG_HOME/zsh/variables.zsh

if [ -f ~/.env.zsh ]; then
  source ~/.env.zsh
fi

export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"
. "$HOME/.local/share/../bin/env"
export PATH=~/.npm-global/bin:$PATH

# -------------------------------------------------------------------
# Shell Options
# -------------------------------------------------------------------
setopt extendedglob nonomatch
setopt notify
setopt autocd
setopt CORRECT
setopt no_case_glob no_case_match
setopt auto_pushd pushd_ignore_dups

# -------------------------------------------------------------------
# Terminal Setup
# -------------------------------------------------------------------
autoload -U colors && colors

# Change cursor to vertical bar when inside tmux
if [ -n "$TMUX" ]; then
  echo -ne "\e[3 q"
fi

# -------------------------------------------------------------------
# Key Bindings
# -------------------------------------------------------------------
bindkey "^[[3~" delete-char         # Delete
bindkey "^[[1~" beginning-of-line   # Home
bindkey "^[[4~" end-of-line         # End
bindkey "^[[H" beginning-of-line    # Alternate Home
bindkey "^[[F" end-of-line          # Alternate End
bindkey "^l" clear-screen

bindkey -v

# -------------------------------------------------------------------
# Custom Widgets
# -------------------------------------------------------------------
# Strip leading/trailing newlines from pasted content
bracketed-paste-strip-edges() {
  local content
  zle .$WIDGET
  LBUFFER="${LBUFFER##$'\n'##}"
  BUFFER="${BUFFER%%$'\n'##}"
}
zle -N bracketed-paste bracketed-paste-strip-edges

# -------------------------------------------------------------------
# Source Additional Configuration
# -------------------------------------------------------------------
source $XDG_CONFIG_HOME/zsh/prompt.zsh
source $XDG_CONFIG_HOME/zsh/aliases.zsh
source $XDG_CONFIG_HOME/zsh/functions.zsh

# -------------------------------------------------------------------
# -------------------------------------------------------------------
# External Tools & Plugins
# -------------------------------------------------------------------
source $XDG_CONFIG_HOME/zsh/pluginload.zsh
# Initialize Zoxide
eval "$(zoxide init zsh --cmd cd)"

# FZF Configuration
source <(fzf --zsh)

# Initialize Atuin
eval "$(atuin init zsh)"

# Completion Configuration
# -------------------------------------------------------------------
zstyle ':completion:*:default' list-colors \
  'di=34:fi=31:ln=36:ex=32' \
  'ma=48;5;17;38;5;255'
zstyle ':completion:*' list-columns 2
zstyle ':completion:*' list-packed yes

# Autosuggestions & Menu Selection
bindkey "$terminfo[kcbt]" menu-select
bindkey -M menuselect              '^I'         menu-complete
bindkey -M menuselect "$terminfo[kcbt]" reverse-menu-complete
bindkey '^I' menu-select
