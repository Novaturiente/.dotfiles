{ config, pkgs, ... }:

{
  home.username = "nova";
  home.homeDirectory = "/home/nova";
  home.stateVersion = "25.05"; # Please read the comment before changing.

  nixpkgs.config.allowUnfree = true;
  #
  home.packages = (import ./packages.nix { inherit pkgs; });
  # home.packages = 
  #   (import ./packages.nix { inherit pkgs; }) ++
  #   (import ./dev-packages.nix { inherit pkgs; }) ++
  #   (import ./media-packages.nix { inherit pkgs; });

  home.file = { };

  home.sessionVariables = {
    # EDITOR = "emacs";
  };

  # services.kdeconnect.enable = true;

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
