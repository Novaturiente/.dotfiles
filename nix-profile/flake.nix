{
  description = "My declarative package set";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";  # Change if needed (e.g., aarch64-darwin for M1 Mac)
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      packages.${system} = {
        extras = pkgs.buildEnv {
          name = "extra-packages";
          paths = with pkgs; [
            tree
            opencode

            # DEVELOPMENT
            # cargo
            # go
            # rust-analyzer
            # rustfmt
            # android-studio
            # jdk
            # freerdp
            # netcat-gnu

            gparted
            gnome-boxes

            ncdu
            udiskie
            bat
            fastfetch

            htop
            mpv
            qimgv
            duf
            pcmanfm
            materia-theme-transparent
            fluent-icon-theme
            bibata-cursors
          ];
        };
      };
    };
}
