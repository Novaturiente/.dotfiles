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
    jq

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
    cargo
    rustc
    rust-analyzer
    rustfmt
    uv

    firefox
    geckodriver
  ];

  programs.adb.enable = true;

# Gaming setup
  security.wrappers.fuse = {
    source = "${pkgs.fuse}/bin/fusermount";
    group = "users";
    owner = "nova";
    capabilities = "cap_sys_admin=eip";
  };
}
