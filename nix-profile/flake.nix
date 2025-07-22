{
  description =
    "Flake to install extra packages via buildEnv with Home Manager support";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs"; # Use the same nixpkgs version
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config = { allowUnfree = true; };
      };

      # Import setup services (preserved from your original)
      setupServices = import ./services/setup-services.nix { inherit pkgs; };

    in {
      # Preserve your existing package definitions
      packages.${system} = {
        extras = pkgs.buildEnv {
          name = "extra-packages";
          paths = (import ./packages.nix { inherit pkgs; })
            ++ [ setupServices ];
        };

        setup-services = setupServices;
      };

      # Add Home Manager support
      homeConfigurations = {
        # Replace "username" with your actual username
        nova = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [{
            home = {
              username = "nova";
              homeDirectory = "/home/nova";
              stateVersion = "25.05"; # Match your Nixpkgs version
            };

            # Example: Enable KDE Connect through Home Manager
            programs.kdeconnect.enable = true;

            # Include your packages in the user environment
            home.packages = [ self.packages.${system}.extras ];
          }
          # You can add more Home Manager modules here
            ];
        };
      };
    };
}
