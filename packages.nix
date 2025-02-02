{ config, lib, pkgs, ... }:

{
  
  environment.systemPackages = with pkgs; [
    mullvad-browser
    wget
    duf
    pyright
    rsync
    stow
    python3
    scrcpy
    gparted
    openssl
    OVMFFull
    lsof
    baobab
    yazi
    fastfetch
    gzip
    curl

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

    # Gaming packages
    vulkan-tools
    lutris
    gamescope
    wineWowPackages.stable
    winetricks
    wineWowPackages.waylandFull
    dwarfs
    fuse-overlayfs
  ];

  programs.adb.enable = true;

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "both";
  };

# Fish Terminal
  programs.fish.enable = true;
  
# Gaming setup
  security.wrappers.fuse = {
    source = "${pkgs.fuse}/bin/fusermount";
    group = "users";
    owner = "nova";
    capabilities = "cap_sys_admin=eip";
  };
}
