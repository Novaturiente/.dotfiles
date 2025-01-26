
{ config, pkgs, inputs, ... }:

{
  imports =
    [ 
      ./hardware-configuration.nix
      ./system.nix
      ./packages.nix
      ./nvidia.nix
      ./flatpak.nix
      ./docker.nix
      ./fish.nix
      ./gaming.nix
      ./virtualization.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 3;
  boot.kernelPackages = pkgs.linuxPackages_latest;
#  boot.kernelParams = ["nvidia_drm.modeset=1"];

  networking.hostName = "novarch"; # Define your hostname.

  # Enable networking
  networking.networkmanager.enable = true;


  # Set your time zone.
  time.timeZone = "America/New_York";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.nova = {
    isNormalUser = true;
    description = "Nova";
    extraGroups = [ "networkmanager" "wheel" "docker"];
    shell = pkgs.fish;
    packages = with pkgs; [
    ];
  };

  # Install firefox.
  programs.firefox.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # $ nix search wget
  environment.systemPackages = with pkgs; [
  ];

  # Enable Flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  system.stateVersion = "24.11"; 
}
