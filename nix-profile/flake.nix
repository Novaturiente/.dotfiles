{
  description = "Flake to install extra packages via buildEnv";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";  # Change if needed, e.g. "aarch64-darwin"
      pkgs = import nixpkgs {
        inherit system;
        config = { allowUnfree = true; };
      };
    in {
      packages.${system} = {
        extras = pkgs.buildEnv {
          name = "extra-packages";
          paths = with pkgs; [
            xdg-ninja
            # Terminal UI
            materia-theme-transparent
            fluent-icon-theme
            nerd-fonts.roboto-mono
            nerd-fonts.jetbrains-mono
            nerd-fonts.fira-code
            noto-fonts-color-emoji
            nwg-look

            # Disk tools
            gparted
            
            # Media & image
            mpv
            castnow
            yt-dlp
            picard
            libva1
            libvdpau

            qimgv
            zathura
            
            # CLI utilities
            opencode
            fastfetch
            htop
            eza
            ripgrep
            zoxide
            dialog
            fd
            jq
            entr
            curl
            wget
            sshfs
            networkmanagerapplet
            tree
            ncdu
            bat
            duf
            ranger
            fzf

            # Archives
            7zip
            unrar
            unzip
            
            # Dev tools
            cmake
            gcc
            lua
            luarocks
            meson
            nodejs
            pkg-config
            pyright
            pipx
            python313Packages.pynvim
            tree-sitter
            uv
            # cargo
            # go
            # rust-analyzer
            # rustfmt
            # android-studio
            # jdk
            nixfmt-classic
            
            # Network & misc
            clipman
            playerctl
            slurp
            swappy
            zenity
            # freerdp
            # netcat-gnu
            
            
          ];
        };
      };
    };
}
