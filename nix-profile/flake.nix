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
    in {
      packages.${system} = {
        extras = pkgs.buildEnv {
          name = "extra-packages";
          paths = with pkgs; [

            # --- Terminal Tools ---
            ranger
            networkmanagerapplet
            nwg-look
            dialog
            htop
            fastfetch
            eza
            zoxide
            ripgrep
            fd
            jq
            entr
            curl
            wget
            sshfs
            tree
            ncdu
            bat
            duf
            fzf
            lsof

            # --- Themes, Fonts, Appearance ---
            materia-theme-transparent
            fluent-icon-theme
            nerd-fonts.roboto-mono
            nerd-fonts.jetbrains-mono
            nerd-fonts.fira-code
            noto-fonts-color-emoji
            lohit-fonts.malayalam

            # --- Media, Image & Viewing Tools ---
            pamixer
            mpv
            castnow
            yt-dlp
            qimgv
            zathura
            remmina

            # --- Clipboard, Audio & Screen Tools ---
            clipman
            playerctl
            slurp
            swappy
            zenity
            wf-recorder

            # --- Archive Utilities ---
            7
            zip
            unrar
            unzip

            # --- Development Tools ---
            opencode
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
            python313Packages.debugpy
            tree-sitter
            uv
            cargo
            go
            rust-analyzer
            rustfmt
            nixfmt-classic
            freetype
          ];
        };
      };
    };
}
