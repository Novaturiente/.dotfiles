{ config, lib, pkgs, ... }:

{
  
  environment.systemPackages = with pkgs; [

    home-manager

    # Browser
    mullvad-browser           # Privacy-focused browser with VPN
    neovim                    # Modern text editor
    ghostty                   # (Terminal tool, needs context)
    wget                      # Command-line file downloader

    htop
    nvtopPackages.full
    duf


    zoxide                    # Fuzzy file search
    eza                        # Enhanced `ls`
    pyright                   # Python type checker
    rsync
    stow
    python3

    scrcpy
  ];

  # Enable BIND DNS server service
  services.bind.enable = true;

  programs.git.enable = true;

  programs.adb.enable = true;
  users.users.nova.extraGroups = ["adbusers" "kvm"];


}
