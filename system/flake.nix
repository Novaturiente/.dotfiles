{
  description = "Nix profile";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";  # Pinned channel
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";  # Adjust for your CPU arch
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      # Define your package set
      packages.${system} = {
        myProfile = pkgs.buildEnv {
          name = "extra-packages";
          paths = with pkgs; [
          ];
          extraOutputsToInstall = ["man" "doc"];
        };
      };
    };
}
