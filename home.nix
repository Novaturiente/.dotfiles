{ config, pkgs, lib, ... }:

let
in

{
  imports = [
  ];

  home.username = "nova";
  home.homeDirectory = "/home/nova";
  
  home.stateVersion = "24.11"; 
  home.packages = [
    pkgs.waybar
  ];

  
  home.file = {
  };

  home.sessionVariables = {
    EDITOR = "nvim";
  };

  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    userName = "Novaturiente";
    userEmail = "novaturiente@proton.me";
  };

}

