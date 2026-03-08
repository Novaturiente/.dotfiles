# Custom XDG Base Directories
export EDITOR="nvim"
export VISUAL="neovide"

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

. "$HOME/.local/share/../bin/env"

export NVAPI_KEY="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"

export OPENROUTER_API_KEY="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"
export ANTHROPIC_BASE_URL="https://openrouter.ai/api"
export ANTHROPIC_AUTH_TOKEN="$OPENROUTER_API_KEY"
export ANTHROPIC_API_KEY=""
