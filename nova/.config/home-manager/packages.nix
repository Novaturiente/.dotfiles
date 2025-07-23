{ pkgs }:
with pkgs; [

  # Network & Browsers
  brave
  mullvad-browser
  protonup-qt

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
  less

  # Themes & Fonts
  materia-theme-transparent
  materia-kde-theme
  fluent-icon-theme
  nerd-fonts.roboto-mono
  nerd-fonts.jetbrains-mono
  nerd-fonts.fira-code
  noto-fonts-color-emoji
  lohit-fonts.malayalam
  kdePackages.qtstyleplugin-kvantum

  # Media Tools
  pamixer
  mpv
  castnow
  yt-dlp
  qimgv
  zathura
  remmina
  mpc
  ncmpcpp
  kdePackages.dolphin

  # Archive Utilities
  p7zip
  zip
  unrar
  unzip

  # Development Tools
  lazygit
  cmake
  gcc
  lua
  luarocks
  meson
  nodejs
  pkg-config
  pyright
  pipx
  python312Packages.pynvim
  tree-sitter
  uv
  cargo
  go
  rust-analyzer
  rustfmt
  nixfmt-classic
]
