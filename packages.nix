{ config, lib, pkgs, ... }:

{
  
  environment.systemPackages = with pkgs; [
    home-manager
    mullvad-browser
    neovim
    ghostty
    wget
    htop
    nvtopPackages.full
    duf
    zoxide
    eza
    pyright
    rsync
    stow
    python3
    scrcpy
    distrobox
    gparted
    openssl
    bluez
    OVMFFull
    lsof
    baobab
    ranger
  ];

  programs.git.enable = true;

  programs.adb.enable = true;

  virtualisation.podman = {
    enable = true;
  };

  users.users.nova.extraGroups = ["adbusers" "kvm"];

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "both";
  };

}
