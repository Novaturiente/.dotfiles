{ config, lib, pkgs, pkgs-unstable, ... }:

{
  services.flatpak = {
    enable = true;
    package = pkgs-unstable.flatpak;
  };
  services.flatpak.remotes = lib.mkOptionDefault [{
    name = "flathub";
    location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
  }];

  services.flatpak.packages = [
    "app.zen_browser.zen"
    "org.qbittorrent.qBittorrent"
    "com.github.tchx84.Flatseal"
    "org.remmina.Remmina"
    "com.freerdp.FreeRDP"
    "net.mullvad.MullvadBrowser"
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

