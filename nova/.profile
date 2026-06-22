# Custom XDG Base Directories
export EDITOR="nvim"
export VISUAL="neovide"

export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_DOTFILES_HOME="$HOME/.dotfiles"

# --- Per-app XDG overrides (relocate dirs out of $HOME) ---
# Rust
export CARGO_HOME="$XDG_DATA_HOME/cargo"
export RUSTUP_HOME="$XDG_DATA_HOME/rustup"
# Go
export GOPATH="$XDG_DATA_HOME/go"
# Bun
export BUN_INSTALL="$XDG_DATA_HOME/bun"
# npm (cache relocated; prefix stays in ~/.npmrc)
export NPM_CONFIG_CACHE="$XDG_CACHE_HOME/npm"
# Android (SDK kept at ~/Android/Sdk; user/config data relocated)
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_USER_HOME="$XDG_DATA_HOME/android"
export ANDROID_SDK_HOME="$XDG_DATA_HOME/android"
export ADB_VENDOR_KEYS="$XDG_DATA_HOME/android"
# Java (relocate ~/.java prefs dir)
export _JAVA_OPTIONS="-Djava.util.prefs.userRoot=$XDG_CONFIG_HOME/java"
# Maven (no settings.xml; only local repo moved)
export MAVEN_OPTS="-Dmaven.repo.local=$XDG_DATA_HOME/maven/repository"
# Ruby (rbenv)
export RBENV_ROOT="$XDG_DATA_HOME/rbenv"
# GnuPG
export GNUPGHOME="$XDG_DATA_HOME/gnupg"
# wget (hsts file via wgetrc)
export WGETRC="$XDG_CONFIG_HOME/wget/wgetrc"
# Relocated tool bin dirs on PATH
export PATH="$CARGO_HOME/bin:$GOPATH/bin:$BUN_INSTALL/bin:$PATH"

export QT_SELECT=qt6
export QT_QPA_PLATFORMTHEME=qt6ct

[ -f ~/.env ] && set -a && source ~/.env && set +a

export __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json
export __GLX_VENDOR_LIBRARY_NAME=mesa

[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"
