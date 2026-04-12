# ===================================================================
# ZSH CONFIGURATION
# ===================================================================
source ~/.profile

# -------------------------------------------------------------------
# Environment Variables & Path
# -------------------------------------------------------------------
source $XDG_CONFIG_HOME/zsh/variables.zsh

[ -f ~/.env.zsh ] && source ~/.env.zsh
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.npm-global/bin:$PATH"

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
# External Tools & Plugins
# -------------------------------------------------------------------
source $XDG_CONFIG_HOME/zsh/pluginload.zsh
eval "$(zoxide init zsh --cmd cd)"
source <(fzf --zsh)
eval "$(atuin init zsh)"

# -------------------------------------------------------------------
# Completions
# -------------------------------------------------------------------
fpath=(~/.config/zsh/completions $fpath)
autoload -U compinit && compinit

zstyle ':completion:*:default' list-colors \
  'di=34:fi=31:ln=36:ex=32' \
  'ma=48;5;17;38;5;255'
zstyle ':completion:*' list-columns 2
zstyle ':completion:*' list-packed yes

bindkey "$terminfo[kcbt]" menu-select
bindkey -M menuselect              '^I'         menu-complete
bindkey -M menuselect "$terminfo[kcbt]" reverse-menu-complete
bindkey '^I' menu-select

# -------------------------------------------------------------------
# Google Cloud SDK
# -------------------------------------------------------------------
[ -f "$HOME/google-cloud-sdk/path.zsh.inc" ] && . "$HOME/google-cloud-sdk/path.zsh.inc"
[ -f "$HOME/google-cloud-sdk/completion.zsh.inc" ] && . "$HOME/google-cloud-sdk/completion.zsh.inc"

# -------------------------------------------------------------------
# Bun
# -------------------------------------------------------------------
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
