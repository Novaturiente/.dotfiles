{ config, pkgs, inputs, ... }:

{
  home.username = "nova"; 
  home.homeDirectory = "/home/nova";  
  programs.home-manager.enable = true;
  home.stateVersion = "24.11";

}
