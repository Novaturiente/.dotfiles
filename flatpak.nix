{ config, lib, pkgs, ... }:

{
  services.flatpak.enable = true;

  services.flatpak.remotes = lib.mkOptionDefault [{
    name = "flathub";
    location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
  }];

  services.flatpak.packages = [
    "app.zen_browser.zen"
    "org.qbittorrent.qBittorrent"
    "com.github.tchx84.Flatseal"
  ];

  services.flatpak.overrides = {
    global = {
      # Force Wayland by default
      Context.sockets = ["wayland" "!x11" "!fallback-x11"];

      Environment = {
        GTK_THEME = "Catppuccin-Macchiato";
      };
    };
  };
}

