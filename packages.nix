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
  ];

  # Enable BIND DNS server service

  programs.git.enable = true;

  programs.adb.enable = true;

  virtualisation.podman = {
    enable = true;
  };

  users.users.nova.extraGroups = ["adbusers" "kvm"];


}
