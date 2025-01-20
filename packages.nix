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


    zoxide                    # Fuzzy file search
    eza                        # Enhanced `ls`
    pyright                   # Python type checker
    rsync
    stow
    python3
  ];

  # Enable BIND DNS server service
  services.bind.enable = true;

  programs.git.enable = true;

}
