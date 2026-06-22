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

# Deduplicate PATH (paths already added by .profile / variables.zsh)
typeset -U path PATH
path=("$HOME/.local/bin" "$HOME/.cargo/bin" "$HOME/.npm-global/bin" $path)

# Cache dir for generated tool-init scripts + the compdump
[ -d "${XDG_CACHE_HOME:-$HOME/.cache}/zsh" ] || mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/zsh"

# Source a tool's init script from a cache file; regenerate only when the tool
# binary is newer than the cache. Avoids a subprocess fork on every startup.
_cache_eval() {
  local f=$1; shift
  if [[ ! -s $f || $commands[$1] -nt $f ]]; then
    "$@" >| $f 2>/dev/null
  fi
  source $f
}

# -------------------------------------------------------------------
# Shell Options
# -------------------------------------------------------------------
setopt extendedglob nonomatch
setopt notify
setopt autocd
setopt no_case_glob no_case_match
setopt auto_pushd pushd_ignore_dups pushd_silent  # silent: don't dump dir stack on cd
setopt interactive_comments                       # allow `# comment` on the command line
setopt complete_in_word always_to_end             # complete mid-word; cursor to word end after

# -------------------------------------------------------------------
# History  (zsh history feeds inline autosuggestions; atuin owns Ctrl-R/Up)
# -------------------------------------------------------------------
HISTFILE=${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history
HISTSIZE=100000
SAVEHIST=100000
[ -d "${HISTFILE:h}" ] || mkdir -p "${HISTFILE:h}"
setopt SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE HIST_VERIFY HIST_FCNTL_LOCK \
       HIST_REDUCE_BLANKS HIST_SAVE_NO_DUPS INC_APPEND_HISTORY EXTENDED_HISTORY

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
# Completions  (fix 6: compinit runs HERE, before zsh-autocomplete loads in
# pluginload — was previously sourced after it, which was fragile)
# -------------------------------------------------------------------
fpath=(~/.config/zsh/completions $fpath)
autoload -Uz compinit
ZSH_COMPDUMP="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
if [[ -n $ZSH_COMPDUMP(#qN.mh+24) ]]; then
  compinit -d "$ZSH_COMPDUMP"        # dump >24h old -> full rebuild + security audit
else
  compinit -C -d "$ZSH_COMPDUMP"     # fresh -> trust cache, skip audit
fi

# File-type completion colors: derive from LS_COLORS (per-extension GNU palette:
# archives red, images magenta, audio cyan, dirs blue, exec green, ...) instead
# of the old flat fi=31 that painted every file red. dircolors output is cached.
_cache_eval "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/dircolors.zsh" dircolors -b
zstyle ':completion:*'         list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS} 'ma=48;5;17;38;5;255'
zstyle ':completion:*' list-columns 2
zstyle ':completion:*' list-packed yes
# -------------------------------------------------------------------
# External Tools & Plugins  (zsh-autocomplete loads here, AFTER compinit — fix 6)
# -------------------------------------------------------------------
source $XDG_CONFIG_HOME/zsh/pluginload.zsh
source $HOME/.config/zsh/plugins/zsh-defer/zsh-defer.plugin.zsh
_cache_eval "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/fzf.zsh" fzf --zsh
# atuin cached (not deferred): keeps preexec hook eager so the FIRST command is recorded
_cache_eval "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/atuin.zsh" atuin init zsh

# Tab / menu-select keybindings (applied after zsh-autocomplete has loaded)
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
[ -s "$HOME/.bun/_bun" ] && zsh-defer source "$HOME/.bun/_bun"
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

zsh-defer source /home/nova/.config/broot/launcher/bash/br

# -------------------------------------------------------------------
# Vi-mode UX parity with fish (cursor shape per mode + `jk` to exit insert)
#   Uses add-zle-hook-widget so it chains with fast-syntax-highlighting /
#   zsh-autocomplete instead of clobbering their zle-keymap-select hook.
# -------------------------------------------------------------------
KEYTIMEOUT=20                                   # 0.2s, matches fish_sequence_key_delay_ms
autoload -Uz add-zle-hook-widget
_vi_cursor_select() {                           # block in normal mode, beam in insert
  case $KEYMAP in
    vicmd)      print -n '\e[2 q';;
    viins|main) print -n '\e[6 q';;
  esac
}
_vi_cursor_beam() { print -n '\e[6 q' }         # beam on new prompt / after command
add-zle-hook-widget keymap-select _vi_cursor_select
add-zle-hook-widget line-init     _vi_cursor_beam
add-zle-hook-widget line-finish   _vi_cursor_beam
bindkey -M viins 'jk' vi-cmd-mode               # jk -> normal mode (like fish)

# -------------------------------------------------------------------
# Carapace — multi-shell completion bridge (fish parity, after compinit)
# -------------------------------------------------------------------
export CARAPACE_BRIDGES='zsh,fish,bash,inshellisense'
zstyle ':completion:*' format $'\e[2;37mCompleting %d\e[m'
_cache_eval "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/carapace.zsh" carapace _carapace zsh

# -------------------------------------------------------------------
# zoxide — MUST be initialized last (zoxide doctor requirement)
# -------------------------------------------------------------------
_cache_eval "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zoxide.zsh" zoxide init zsh --cmd cd

# bun completions
[ -s "/home/nova/.bun/_bun" ] && source "/home/nova/.bun/_bun"
