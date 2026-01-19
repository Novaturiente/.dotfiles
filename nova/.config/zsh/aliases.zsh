# Editor and system update aliases
# alias vi="nvim"
alias vi="nvim"
alias doom="~/.config/emacs/bin/doom"
alias inova="sudo novarch install"
alias unova="sudo novarch update"
alias anova="sudo novarch add"
alias rnova="sudo novarch remove"

alias cedit="nvim -c 'enew | put + | setlocal buftype=nofile bufhidden=wipe noswapfile'"

# ---- ls Aliases (with eza) ----
alias la='eza -a --color=always --group-directories-first --icons=always "$@"'
alias ls='eza -al --color=always --group-directories-first --icons=always "$@"'
alias ll='eza -l --color=always --group-directories-first --icons=always "$@"'
alias lt='eza -aT --color=always --group-directories-first --icons=always "$@"'
alias l.="eza -a | grep -e '^\.'"

alias rm="trash"

alias cp='rsync -ah --info=progress2 --inplace --no-whole-file'

alias grubup="sudo grub-mkconfig -o /boot/grub/grub.cfg"
alias jctl="journalctl -p 3 -xb"
alias tarnow='tar -acf '
alias untar='tar -zxvf '
alias wget='wget -c '
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'
# alias grep='rg --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias cat='bat --paging=never'

alias gadd='git add . && git commit -m "Update"'
alias hotspot='nmcli dev wifi hotspot ifname wlp0s20f3 ssid Novapc password "Novarch123"'
alias fileserver="python3 -m http.server 8080 --directory ~/Share"

alias winsopen="podman-compose -f ~/.config/winapps/compose.yaml start && sleep 5 && xfreerdp3 /u:Nova /p:novarch /v:127.0.0.1 /cert:ignore /sound /microphone +dynamic-resolution /sec:tls /f +span +home-drive"
alias winrestart="podman-compose -f ~/.config/winapps/compose.yaml restart && sleep 5 && xfreerdp3 /u:Nova /p:novarch /v:127.0.0.1 /cert:ignore /sound /microphone +dynamic-resolution /sec:tls /f +span +home-drive"
alias winstop="podman-compose -f ~/.config/winapps/compose.yaml stop"
alias winstart="podman-compose -f ~/.config/winapps/compose.yaml start"

alias macup="podman-compose -f ~/.dotfiles/docker/macos.yaml up -d"
alias macdown="podman-compose -f ~/.dotfiles/docker/macos.yaml down"

# alias novarch="uv run --project ~/.dotfiles/novarch ~/.dotfiles/novarch/run.py"
alias editsystem="nvim ~/.dotfiles/novarch"
alias systemupdate="sudo reflector --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist && paru -Syu"

alias clear-cache="rm -rf ~/.config/qutebrowser_work/cache/* && rm -rf ~/.cache/qutebrowser && rm -rf ~/.cache/floorp"

alias eeclogin="ssh -i ~/.ssh/id_eecdev eecdev@139.59.75.32"

alias agentrun="~/.dotfiles/scripts/tmux_agent.sh"

# alias ollama="docker exec -it ollama ollama"
# alias ollamaup="podman-compose -f ~/.dotfiles/docker/ollama.yml up -d"
# alias ollamadown="podman-compose -f ~/.dotfiles/docker/ollama.yml down"

# alias nixup="sudo systemctl enable --now nix-daemon"
# alias homeup="nix run github:nix-community/home-manager -- init --switch"
# alias serviceup="cd ~/.config/home-manager/ && sudo nix run 'github:numtide/system-manager' -- switch --flake '.'"
# alias editpackages="nvim ~/.config/home-manager/packages.nix"
