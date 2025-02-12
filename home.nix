{ config, pkgs, ... }:

{
  home.username = "nova";  # Replace with your actual username
  home.homeDirectory = "/home/nova";  # Replace with your actual home directory

  programs.home-manager.enable = true;

  home.stateVersion = "24.11";  # Update this to match the version of home-manager
}
