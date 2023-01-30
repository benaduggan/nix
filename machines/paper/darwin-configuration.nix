{ config, lib, pkgs, ... }:

{
  nix.settings.substituters = [
    "https://cache.nixos.org/"
  ];
  nix.settings.trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
  ];

  documentation.enable = true;

  # Use a custom configuration.nix location.
  # how I currently build and switch the system:
  # darwin-rebuild switch --flake ~/cfg/machines/paper/
  environment.darwinConfig = "$HOME/cfg/machines/darwin-configuration.nix";


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
  system = {
    defaults = {
      NSGlobalDomain = {
        InitialKeyRepeat = 10;
        KeyRepeat = 1;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticDashSubstitutionEnabled = false;
        NSAutomaticPeriodSubstitutionEnabled = false;
        NSAutomaticQuoteSubstitutionEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;
        NSNavPanelExpandedStateForSaveMode = true;
        NSNavPanelExpandedStateForSaveMode2 = true;
        _HIHideMenuBar = false;

        "com.apple.keyboard.fnState" = true;
      };

      screencapture.location = "/tmp";
      dock = {
        autohide = true;
        mru-spaces = false;
        orientation = "bottom";
        showhidden = true;
      };

      finder = {
        AppleShowAllExtensions = true;
        QuitMenuItem = true;
        FXEnableExtensionChangeWarning = false;
      };

      trackpad = {
        Clicking = true;
        TrackpadThreeFingerDrag = true;
      };
    };
  };

  security.pam.enableSudoTouchIdAuth = true;

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
      "postman"
      "qlvideo"
      "raycast"
      "rectangle"
      "firefox"
      "google-chrome"
      "visual-studio-code"
      "vlc"
      "zoom"
    ];

    # These appear to be gated by having "purchased" the thing
    # even if it's free per apple id
    masApps = { Wireguard = 1451685025; };
  };
}

