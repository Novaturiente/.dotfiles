{ pkgs }:
with pkgs; [
  #Tools
  gparted
  podman-compose

  # Network & Browsers
  brave
  mullvad-browser
  protonup-qt

  # Hyprland Tools
  hyprpanel
  stow
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
  speedtest-cli
  hostname

  # Themes & Fonts
  materia-theme-transparent
  materia-kde-theme
  fluent-icon-theme
  nerd-fonts.roboto-mono
  nerd-fonts.jetbrains-mono
  nerd-fonts.fira-code
  noto-fonts-color-emoji
  lohit-fonts.malayalam
  adwaita-fonts

  kdePackages.qtstyleplugin-kvantum

  # Media Tools
  pamixer
  mpv
  castnow
  yt-dlp
  qimgv
  zathura
  mpc
  ncmpcpp
  deluge
  ranger

  scrcpy

  # Archive Utilities
  p7zip
  zip
  unrar
  unzip

  # Development Tools
  lazygit
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
