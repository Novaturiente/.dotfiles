{ config, pkgs, inputs,lib, ... }:

{
  home.username = "nova"; 
  home.homeDirectory = "/home/nova";  
  programs.home-manager.enable = true;
  home.stateVersion = "24.11";
}
