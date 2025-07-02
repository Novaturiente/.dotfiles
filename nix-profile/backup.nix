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
            nvtopPackages.full
            
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
            #alsa-lib
            #alsa-plugins
            #gamescope
            #giflib
            #gnutls
            #gtk3
            #lib32-alsa-lib
            #lib32-alsa-plugins
            #lib32-giflib
            #lib32-gst-plugins-base-libs
            #lib32-libgcrypt
            #lib32-libgpg-error
            #lib32-libpng
            #lib32-libpulse
            #lib32-libva
            #lib32-mpg123
            #lib32-ncurses
            #lib32-openal
            #lib32-sqlite
            #lib32-vulkan-icd-loader
            #libgcrypt
            #libgpg-error
            #libinput
            #libpng
            #libpulse
            #libva
            #libxkbcommon
            #lutris
            #mpg123
            #ncurses
            #openal
            #sqlite
            #vulkan-tools
            #wine-staging

          ];
        };
      };
    };
}
