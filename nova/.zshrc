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


# Replace ls with eza
alias ls='eza -a --color=always --group-directories-first --icons' # preferred listing
alias la='eza -al --color=always --group-directories-first --icons'  # all files and dirs
alias ll='eza -l --color=always --group-directories-first --icons'  # long format
alias lt='eza -aT --color=always --group-directories-first --icons' # tree listing
alias l.="eza -a | grep -e '^\.'"                                     # show only dotfiles

# Common use
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

# Get the error messages from journalctl
alias jctl="journalctl -p 3 -xb"

alias winconnect="com.freerdp.FreeRDP /v:127.0.0.1 /u:Docker /p:novarch /dynamic-resolution /sound"

alias ollama="podman exec -it ollama ollama"
alias ollamaup="podman-compose -f ~/.dotfiles/podman/ollama.yml up -d"
alias ollamadown="podman-compose -f ~/.dotfiles/podman/ollama.yml down"

