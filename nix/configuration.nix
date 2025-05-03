
{ config, pkgs, inputs,pkgs-unstable, ... }:

{
  imports =
    [ 
      ./hardware-configuration.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 3;
  #boot.kernelPackages = pkgs.linuxPackages_6_13;
  boot.kernelPackages = pkgs.linuxPackages_latest;
  system.nixos.label = "_";

  networking.hostName = "novarch"; # Define your hostname.
  networking.networkmanager.enable = true;
  networking.wireless.enable = false;

  # Set your time zone.
  time.timeZone = "Asia/Kolkata";
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

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable sound with pipewire.
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
    extraGroups = [ "networkmanager" "wheel" "docker" "libvirtd" "adbusers" "kvm" "qemu-libvirtd"];
    shell = pkgs.fish;
    packages = with pkgs; [
    ];
  };

  programs.fish.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # $ nix search wget
  environment.systemPackages = with pkgs; [
    ghostty
    git
    pkgs-unstable.neovim
    firefox
  ];

  # Enable Flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  system.stateVersion = "24.11"; 
}
