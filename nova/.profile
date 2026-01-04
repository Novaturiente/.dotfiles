# Custom XDG Base Directories
export EDITOR="emacs --background-color=black"
export VISUAL="emacs --background-color=black"

export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_DOTFILES_HOME="$HOME/.dotfiles"

export QT_SELECT=qt6
export QT_QPA_PLATFORMTHEME=gtk3

[ -f ~/.env ] && set -a && source ~/.env && set +a

export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_DOTFILES_HOME="$HOME/.dotfiles"

export __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json
export __GLX_VENDOR_LIBRARY_NAME=mesa
