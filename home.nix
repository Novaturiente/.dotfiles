home-manager.users.theNameOfTheUser = { pkgs, ... }: {
  home.username = "nova";
  home.homeDirectory = "/home/nova";
  programs.home-manager.enable = true;
  home.packages = with pkgs; [
    # your desired nixpkgs here
  ];
  home.stateVersion = "24.11";
};
