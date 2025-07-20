{ pkgs }:
with pkgs; [
  # Browsers
  chromium
  brave
  mullvad-browser

  # Hyprland Tools
  hyprpanel
  stow
  rofi-wayland
  brightnessctl
  font-awesome
  grim
  wl-clipboard
  clipman
  playerctl
  slurp
  swappy
  zenity
  wf-recorder

  # Terminal Tools
  ranger
  networkmanagerapplet
  nwg-look
  dialog
  htop
  fastfetch
  eza
  zoxide
  ripgrep
  fd
  jq
  entr
  curl
  wget
  sshfs
  tree
  ncdu
  bat
  duf
  fzf
  lsof

  # Themes & Fonts
  materia-theme-transparent
  fluent-icon-theme
  nerd-fonts.roboto-mono
  nerd-fonts.jetbrains-mono
  nerd-fonts.fira-code
  noto-fonts-color-emoji
  lohit-fonts.malayalam

  # Media Tools
  pamixer
  mpv
  castnow
  yt-dlp
  qimgv
  zathura
  remmina
  mpd
  mpc
  ncmpcpp

  # Archive Utilities
  p7zip
  zip
  unrar
  unzip

  # Development Tools
  cmake
  gcc
  lua
  luarocks
  meson
  nodejs
  pkg-config
  pyright
  pipx
  python313Packages.pynvim
  python313Packages.debugpy
  tree-sitter
  uv
  cargo
  go
  rust-analyzer
  rustfmt
  nixfmt-classic
  freetype
]
