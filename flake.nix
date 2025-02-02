{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
#    home-manager.url = "github:nix-community/home-manager/release-24.11";
#    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    catppuccin.url = "github:catppuccin/nix";
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";
  };
  outputs = { self, nixpkgs, home-manager, catppuccin, nix-flatpak, ... } @ inputs:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
    nixosConfigurations = {
      novarch = lib.nixosSystem {
        inherit system;
	specialArgs = { inherit inputs; };
	modules = [
	  ./configuration.nix
	  catppuccin.nixosModules.catppuccin
	  nix-flatpak.nixosModules.nix-flatpak
	];
      };
    };

#    homeConfigurations = {
#      nova = home-manager.lib.homeManagerConfiguration {
#        inherit pkgs;
#	modules = [./home.nix];
#      };
#    };
  };
}

