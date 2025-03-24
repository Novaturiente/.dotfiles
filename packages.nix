{ config, lib, pkgs, pkgs-unstable, ... }:

{
  environment.systemPackages = with pkgs; [
    wget
    duf
    pyright
    rsync
    stow
    python3
    gparted
    openssl
    lsof
    baobab
    yazi
    fastfetch
    gzip
    curl
    bat
    unzip
    unrar
    p7zip
    vlc

    # Fish shell
    fishPlugins.done
    fishPlugins.fzf-fish
    fishPlugins.forgit
    fishPlugins.hydro
    fzf
    fishPlugins.grc
    grc
    zoxide
    eza

    #Development
    cpio
    cmake
    gcc
    gnumake
    nmap
    file
    conda
    cargo
    rustc
    rust-analyzer
    rustfmt
    uv
    python310
    python312Packages.ollama

    pkgs-unstable.firefox
    geckodriver
  ];

  programs.adb.enable = true;

#  services.ollama = {
#    enable = true;
#    acceleration = "cuda";
#    package = pkgs-unstable.ollama;
#  };
#
#  services.open-webui = {
#    enable = true;
#    port = 3000;
#    openFirewall = true;
#  };
#
#  services.tailscale = {
#    enable = true;
#    useRoutingFeatures = "both";
#  };

# Gaming setup
  security.wrappers.fuse = {
    source = "${pkgs.fuse}/bin/fusermount";
    group = "users";
    owner = "nova";
    capabilities = "cap_sys_admin=eip";
  };
}
