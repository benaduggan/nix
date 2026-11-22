{ common, config, inputs, lib, pkgs, ... }:
{
  imports = [
    inputs.home-manager.darwinModules.home-manager
    inputs.ncro.darwinModules.default
    "${inputs.jacobi}/hosts/modules/darwin/llama-server.nix"
    ./ca-blacklist.nix
    ./ncro.nix
    ./openssh-darwin.nix
  ];

  nix = {
    settings = common.nixSettings // {
      trusted-users = [ config.system.primaryUser ];
    };
    gc.automatic = lib.mkDefault true;
    optimise.automatic = lib.mkDefault true;
    extraOptions = lib.mkDefault (''
      experimental-features = nix-command flakes
    '' + lib.optionalString (pkgs.stdenv.hostPlatform.system == "aarch64-darwin") ''
      extra-platforms = x86_64-darwin aarch64-darwin x86_64-linux
    '');
  };

  documentation.enable = lib.mkDefault true;
  environment.darwinConfig = lib.mkDefault "$HOME/cfg/machines/darwin-configuration.nix";

  programs = {
    zsh.enable = lib.mkDefault true;
    bash.enable = lib.mkDefault true;
    bash.completion.enable = lib.mkDefault true;
    nix-index.enable = lib.mkDefault true;
  };

  system.stateVersion = lib.mkDefault common.darwinStateVersion;
  system.defaults = {
    NSGlobalDomain = {
      ApplePressAndHoldEnabled = lib.mkDefault false;
      InitialKeyRepeat = lib.mkDefault 10;
      KeyRepeat = lib.mkDefault 5;
      NSAutomaticCapitalizationEnabled = lib.mkDefault false;
      NSAutomaticDashSubstitutionEnabled = lib.mkDefault false;
      NSAutomaticPeriodSubstitutionEnabled = lib.mkDefault false;
      NSAutomaticQuoteSubstitutionEnabled = lib.mkDefault false;
      NSAutomaticSpellingCorrectionEnabled = lib.mkDefault false;
      NSNavPanelExpandedStateForSaveMode = lib.mkDefault true;
      NSNavPanelExpandedStateForSaveMode2 = lib.mkDefault true;
      _HIHideMenuBar = lib.mkDefault false;
      "com.apple.keyboard.fnState" = lib.mkDefault true;
    };

    screencapture.location = lib.mkDefault "/tmp";

    dock = {
      autohide = lib.mkDefault true;
      autohide-delay = lib.mkDefault 0.0;
      autohide-time-modifier = lib.mkDefault 0.2;
      mru-spaces = lib.mkDefault false;
      orientation = lib.mkDefault "bottom";
      show-recents = lib.mkDefault false;
      showhidden = lib.mkDefault true;
    };

    finder = {
      AppleShowAllExtensions = lib.mkDefault true;
      AppleShowAllFiles = lib.mkDefault true;
      FXDefaultSearchScope = lib.mkDefault "SCcf";
      FXEnableExtensionChangeWarning = lib.mkDefault false;
      FXPreferredViewStyle = lib.mkDefault "Nlsv";
      QuitMenuItem = lib.mkDefault true;
      ShowPathbar = lib.mkDefault true;
      ShowStatusBar = lib.mkDefault true;
      _FXShowPosixPathInTitle = lib.mkDefault true;
    };

    trackpad = {
      Clicking = lib.mkDefault true;
      TrackpadThreeFingerDrag = lib.mkDefault true;
    };

    CustomUserPreferences."com.apple.desktopservices" = {
      DSDontWriteNetworkStores = true;
      DSDontWriteUSBStores = true;
    };
  };

  security.pam.services.sudo_local = {
    enable = lib.mkDefault true;
    touchIdAuth = lib.mkDefault true;
    reattach = lib.mkDefault true;
  };

  fonts.packages = [
    pkgs.nerd-fonts.fira-code
  ];

  homebrew = {
    enable = lib.mkDefault true;
    global.autoUpdate = lib.mkDefault false;
    onActivation = {
      autoUpdate = lib.mkDefault true;
      cleanup = lib.mkDefault "uninstall";
      upgrade = lib.mkDefault true;
    };

    casks = [
      "discord"
      "firefox"
      "google-chrome"
      "karabiner-elements"
      "notion"
      "raycast"
      "rectangle"
      "slack"
      "tabby"
      "visual-studio-code"
      "vlc"
      "windows-app"
    ];
    # should install directly -> tailscale, docker, spotify, bruno
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
  };
}
