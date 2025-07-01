{
  description = "Declarative Nix user profile";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

  outputs = { nixpkgs, ... }: {
    packages.x86_64-linux.default = import nixpkgs {
      system = "x86_64-linux";
    };

    apps.x86_64-linux.default = {
      type = "app";
      program = toString (
        let pkgs = import nixpkgs { system = "x86_64-linux"; };
        in pkgs.writeShellScript "install-packages" ''
          nix profile install nixpkgs#{builtins.concatStringsSep " " [
            "tree"
          ]}
        '';
      );
    };
  };
}

