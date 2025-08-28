# Editor and system update aliases
alias vi="nvim"

alias systemupdate="sudo akshara update && reboot"

# ---- ls Aliases (with eza) ----
alias la='eza -a --color=always --group-directories-first --icons'
alias ls='eza -al --color=always --group-directories-first --icons'
alias ll='eza -l --color=always --group-directories-first --icons'
alias lt='eza -aT --color=always --group-directories-first --icons'
alias l.="eza -a | grep -e '^\.'"  # Show only dotfiles

alias jctl="journalctl -p 3 -xb"
alias winconnect="com.freerdp.FreeRDP /v:127.0.0.1 /u:Docker /p:novarch /dynamic-resolution /sound"

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

alias ollama="podman exec -it ollama ollama"
alias ollamaup="podman-compose -f ~/.dotfiles/podman/ollama.yml up -d"
alias ollamadown="podman-compose -f ~/.dotfiles/podman/ollama.yml down"

alias gadd='git add . && git commit -m "Update"'

alias hotspot='nmcli dev wifi hotspot ifname wlp0s20f3 ssid Novapc password "Novarch123"'

alias nixup="sudo systemctl enable --now nix-daemon"
alias homeup="nix run github:nix-community/home-manager -- init --switch"
alias serviceup="cd ~/.config/home-manager/ && sudo nix run 'github:numtide/system-manager' -- switch --flake '.'"
alias editpackages="nvim ~/.config/home-manager/packages.nix"


alias winsopen="docker-compose -f ~/.config/winapps/compose.yaml start && sleep 5 && xfreerdp3 /u:Docker /p:novarch /v:127.0.0.1 /cert:ignore /sound /microphone +dynamic-resolution /sec:tls /f"
alias winrestart="docker-compose -f ~/.config/winapps/compose.yaml restart && sleep 5 && xfreerdp3 /u:Docker /p:novarch /v:127.0.0.1 /cert:ignore /sound /microphone +dynamic-resolution /sec:tls /f"
alias winstop="docker-compose -f ~/.config/winapps/compose.yaml stop"
alias winstart="docker-compose -f ~/.config/winapps/compose.yaml start"


alias fileserver="python3 -m http.server 8080 --directory ~/Share"
