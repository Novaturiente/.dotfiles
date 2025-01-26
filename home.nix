{ config, pkgs, lib, ... }:

let
in

{
  imports = [
  ];

  home.username = "nova";
  home.homeDirectory = "/home/nova";

  home.enableNixpkgsReleaseCheck = false;
  
  home.stateVersion = "25.05"; 
  home.packages = [
    pkgs.waybar
  ];

  
  home.file = {
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    userName = "Novaturiente";
    userEmail = "novaturiente@proton.me";
  };

}

