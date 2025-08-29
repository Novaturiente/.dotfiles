{ pkgs }:
with pkgs; [
  #Tools
  gparted
  protonup-qt
  sbctl

  # Network & Browsers
  brave
  mullvad-browser
  yt-dlp

  # Hyprland Tools
  hyprpanel
  hyprshade
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
  btop
  fastfetch
  eza
  zoxide
  ripgrep
  fd
  jq
  entr
  wget
  sshfs
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
  nwg-look

  # Media Tools
  pamixer
  mpv
  castnow
  qimgv
  zathura
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
  python310
  go
  rust-analyzer
  rustfmt
  nixfmt-classic
  sqlite
  jdk
]
