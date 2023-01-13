{ config, lib, pkgs, ... }:

{
  nix.settings.substituters = [
    "https://cache.nixos.org/"
  ];
  nix.settings.trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
  ];

  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  environment.systemPackages = [ pkgs.vim ];
  # Use a custom configuration.nix location.
  # $ darwin-rebuild switch -I darwin-config=$HOME/.config/nixpkgs/darwin/configuration.nix
  environment.darwinConfig = "$HOME/cfg/machines/paper/darwin-configuration.nix";

  # environment.systemPackages = with pkgs; [
  #   kitty
  #   terminal-notifier
  # ];

  # Auto upgrade nix package and the daemon service.
  # services.nix-daemon.enable = true;
  # nix.package = pkgs.nix;

  nix.extraOptions = ''
    auto-optimise-store = true
    experimental-features = nix-command flakes
  '' + lib.optionalString (pkgs.system == "aarch64-darwin") ''
    extra-platforms = x86_64-darwin aarch64-darwin
  '';

  programs.zsh.enable = true;
  programs.bash.enable = true;
  programs.bash.enableCompletion = true;

  programs.nix-index.enable = true;

  services.nix-daemon.enable = true;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;

  # not sure if it works yet
  # security.pam.enableSudoTouchIdAuth = true;

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
      upgrade = true;
    };

    brews = [ "readline" "qemu" ];

    taps = [
      "homebrew/cask"
      "homebrew/cask-drivers"
      "homebrew/cask-fonts"
      "homebrew/cask-versions"
      "homebrew/core"
      "homebrew/services"
    ];

    casks = [
      "authy"
      "font-fira-code-nerd-font"
      "epic-games"
      "spotify"
      "steam"
      "discord"
      "slack"
      "docker"
      "karabiner-elements"
      "macfuse"
      "notion"
      "parsec"
      "qlvideo"
      "raycast"
      "rectangle"
      "firefox"
      "google-chrome"
      "visual-studio-code"
      "vlc"
    ];

    # These appear to be gated by having "purchased" the thing
    # even if it's free per apple id
    masApps = { Wireguard = 1451685025; };
  };
}

