{
  description = "Flake to install extra packages via buildEnv";
  inputs = { nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable"; };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config = { allowUnfree = true; };
      };

      # Import setup services
      setupServices = import ./services/setup-services.nix { inherit pkgs; };

    in {
      packages.${system} = {
        extras = pkgs.buildEnv {
          name = "extra-packages";
          paths = (import ./packages.nix { inherit pkgs; })
            ++ [ setupServices ];
        };

        # Optional: Individual service installers
        setup-services = setupServices;
      };
    };
}
