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
            nixfmt

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
            qemu_full

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
            nerd-fonts.roboto-mono
            nerd-fonts.jetbrains-mono
            nerd-fonts.symbols-only
          ];
        };
      };
    };
}
