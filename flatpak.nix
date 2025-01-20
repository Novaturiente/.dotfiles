{ config, lib, pkgs, ... }:

{
  services.flatpak.enable = true;

  services.flatpak.remotes = lib.mkOptionDefault [{
    name = "flathub";
    location = "https://dl.flathub.org/repo/flathub.flatpakrepo";
  }];

  services.flatpak.packages = [
    "net.lutris.Lutris"
    "app.zen_browser.zen"
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

