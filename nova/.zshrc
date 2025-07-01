# ---- ZSH Configuration ----

# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
setopt extendedglob notify
setopt nonomatch

# ---- Load Environment Variables ----
# Load .env.zsh if it exists
if [ -f ~/.env.zsh ]; then
  source ~/.env.zsh
fi

# ---- Initialize Zoxide ----
# Initialize zoxide for zsh
eval "$(zoxide init zsh)"

# ---- Aliases ----
# Editor and system update aliases
alias vi="nvim"
alias systemupdate="sudo akshara update && reboot"

# Common file operations
alias grubup="sudo grub-mkconfig -o /boot/grub/grub.cfg"
alias tarnow='tar -acf '
alias untar='tar -zxvf '
alias wget='wget -c '
alias psmem='ps auxf | sort -nr -k 4'
alias psmem10='ps auxf | sort -nr -k 4 | head -10'
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

# Nix package manager
alias nixupdate="nix flake update && nix profile upgrade --profile ~/.nix-profile --all"
alias nixinstall="nix profile install"
alias nixlist="nix profile list"
alias nixuninstall="nix profile remove"
alias nixrollbak="nix-env --rollback"

# Journalctl and Windows connection
alias jctl="journalctl -p 3 -xb"
alias winconnect="com.freerdp.FreeRDP /v:127.0.0.1 /u:Docker /p:novarch /dynamic-resolution /sound"

# Ollama (Podman) aliases
alias ollama="podman exec -it ollama ollama"
alias ollamaup="podman-compose -f ~/.dotfiles/podman/ollama.yml up -d"
alias ollamadown="podman-compose -f ~/.dotfiles/podman/ollama.yml down"

# ---- Editor Configuration ----
export VISUAL="nvim"
export EDITOR="nvim"
export NVIM_LOG_FILE="$HOME/.cache/nvim/my_custom_log.txt"  # Custom Neovim log file

# ---- Man Page Formatting ----
export MANROFFOPT="-c"
export MANPAGER="sh -c 'col -bx | bat -l man -p'"

# ---- Custom PATH Configuration ----
# Add ~/.local/bin to PATH if not already present
if [ -d "$HOME/.local/bin" ] && [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
  export PATH="$HOME/.local/bin:$PATH"
fi

# Add depot_tools to PATH if not already present
if [ -d "$HOME/Applications/depot_tools" ] && [[ ":$PATH:" != *":$HOME/Applications/depot_tools:"* ]]; then
  export PATH="$HOME/Applications/depot_tools:$PATH"
fi

# ---- Nix Environment ----
# Ensure nix environment is sourced in Zsh
export NIX_PROFILES="$HOME/.nix-profile"
if [ -n "$ZSH_VERSION" ]; then
    if [ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
        source "$HOME/.nix-profile/etc/profile.d/nix.sh"
    fi
fi

# ---- Backup Function ----
backup() {
  cp "$1" "$1.bak"
}

# ---- Plugin and Theme Sourcing ----
source ~/.zsh/zsh-256color.plugin.zsh
source ~/.zsh/zsh-sudo.zsh
# source ~/.zsh/autopair.zsh
# source ~/.zsh/auto-venv.zsh
source ~/.zsh/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh
source ~/.zsh/zsh-autosuggestions.zsh
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#808080"

# ---- ls Aliases (with eza) ----
alias ls='eza -a --color=always --group-directories-first --icons'
alias la='eza -al --color=always --group-directories-first --icons'
alias ll='eza -l --color=always --group-directories-first --icons'
alias lt='eza -aT --color=always --group-directories-first --icons'
alias l.="eza -a | grep -e '^\.'"  # Show only dotfiles

# ---- Compinit ----
zstyle :compinstall filename '/home/nova/.zshrc'
autoload -Uz compinit
compinit

# ---- Key Bindings for Special Keys ----
bindkey "^[[3~" delete-char         # Delete
bindkey "^[[1~" beginning-of-line   # Home
bindkey "^[[4~" end-of-line         # End
bindkey "^[[H" beginning-of-line    # Alternate Home
bindkey "^[[F" end-of-line          # Alternate End

# ---- Prompt Sourcing ----
source ~/.zsh/prompt.zsh
