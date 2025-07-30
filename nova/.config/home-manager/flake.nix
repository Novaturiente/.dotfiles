{
  description =
    "Nix configuration to install packages in archlinux using Home-manager and flakes";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    system-manager = {
      url = "github:numtide/system-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, system-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      # userPackages = import ./packages.nix { inherit pkgs; };
    in {
      # packages.${system}.default = pkgs.buildEnv {
      #   name = "user-packages";
      #   paths = userPackages;
      # };

      homeConfigurations."nova" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./home.nix ];
      };
      systemConfigs.default =
        system-manager.lib.makeSystemConfig { modules = [ ./modules ]; };
    };
}
