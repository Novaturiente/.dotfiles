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
            # File utilities
            tree
            ncdu
            bat

            # Disk tools
            gparted
              
            # Performance & info
            fastfetch
            htop
            
            # Media & image
            mpv
            qimgv
            
            # Terminal UI
            duf
            pcmanfm
            materia-theme-transparent
            fluent-icon-theme
            nerd-fonts.roboto-mono
            nerd-fonts.jetbrains-mono
            nerd-fonts.symbols-only
            nwg-look
            
            # CLI utilities
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
            #nvtopPackages.full
            # android-studio
            # jdk
            
            # Network & misc
            clipman
            playerctl
            slurp
            swappy
            zenity
            flatpak
            protonup
            python313Packages.adblock
            
            # Archives
            7zip
            unrar
            unzip
            
            # Virtualization
            distrobox
            # freerdp
            # netcat-gnu

            # Compatibility (Gaming)
            (lutris.override {
               extraPkgs = pkgs: [
                  wineWowPackages.staging
                  alsa-lib
                  alsa-plugins
                  gamescope
                  giflib
                  gnutls
                  gtk3
                  libgcrypt
                  libgpg-error
                  libinput
                  libpng
                  libpulseaudio
                  libva
                  libxkbcommon
                  mpg123
                  ncurses
                  openal
                  sqlite
               ];
            })
          ];
        };
      };
    };
}
