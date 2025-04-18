{ common, lib, pkgs, ... }:
{

  nix.settings.extra-trusted-substituters = common.cacheSubstituters ++ common.magicSubstituters;
  nix.settings.extra-trusted-public-keys = common.trustedPublicKeys ++ common.magicTrustedPublicKeys;
  nix.settings.trusted-users = [ "benduggan" ];

  documentation.enable = true;

  # Use a custom configuration.nix location.
  # how I currently build and switch the system:
  # darwin-rebuild switch --flake ~/cfg/machines/paper/
  environment.darwinConfig = "$HOME/cfg/machines/darwin-configuration.nix";


  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '' + lib.optionalString (pkgs.system == "aarch64-darwin") ''
    extra-platforms = x86_64-darwin aarch64-darwin x86_64-linux
  '';

  programs.zsh.enable = true;
  programs.bash.enable = true;
  programs.bash.completion.enable = true;
  programs.nix-index.enable = true;

  users.users.benduggan = {
    name = "benduggan";
    home = "/Users/benduggan";
    openssh.authorizedKeys.keys = common.authorizedKeys;
  };

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;
  system = {
    defaults = {
      NSGlobalDomain = {
        InitialKeyRepeat = 5;
        KeyRepeat = 5;
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

  # security.pam.enableSudoTouchIdAuth = true;

  homebrew = {
    global.autoUpdate = false;
    enable = true;
    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
      upgrade = true;
    };

    brews = [ "readline" "qemu" ];

    taps = [
      "homebrew/cask"
      "homebrew/cask-fonts"
      "homebrew/cask-versions"
      "homebrew/core"
      "homebrew/services"
    ];

    casks = map (name: { inherit name; greedy = true; }) [
      # "android-studio"
      "authy"
      "font-fira-code-nerd-font"
      "epic-games"
      "spotify"
      "steam"
      "discord"
      "slack"
      "obs"
      # "docker"
      "karabiner-elements"
      # "macfuse"
      "microsoft-remote-desktop"
      # "notion"
      "parsec"
      # "postman"
      "qlvideo"
      "raycast"
      "rectangle"
      # "redisinsight"
      "firefox"
      "google-chrome"
      "visual-studio-code"
      "vlc"
      "zoom"
      "insomnia"
      "tabby"
      "tailscale"
      # "macfuse"
      # "maccy"
    ];

    # These appear to be gated by having "purchased" the thing
    # even if it's free per apple id
    masApps = {
      Wireguard = 1451685025;
      # Xcode = 497799835;
    };
  };
}

