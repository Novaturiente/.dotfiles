{
  description = "My declarative package list";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: {
    packages.x86_64-linux.extras = let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in pkgs.buildEnv {
      name = "extra-packages";
      paths = with pkgs; [
          tree
          btop
      ];
    };
  };
}
