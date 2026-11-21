{ common, config, inputs, lib, pkgs, ... }:
{
  imports = [
    inputs.home-manager.darwinModules.home-manager
    "${inputs.jacobi}/hosts/modules/darwin/llama-server.nix"
    ./ca-blacklist.nix
    ./openssh-darwin.nix
  ];

  nixpkgs = {
    config.allowUnfree = true;
    overlays = [ inputs.self.overlays.default ];
  };

  nix.settings = common.nixSettings // {
    trusted-users = [ config.system.primaryUser ];
  };
  nix.extraOptions = lib.mkDefault (''
    experimental-features = nix-command flakes
  '' + lib.optionalString (pkgs.stdenv.hostPlatform.system == "aarch64-darwin") ''
    extra-platforms = x86_64-darwin aarch64-darwin x86_64-linux
  '');

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
      mru-spaces = lib.mkDefault false;
      orientation = lib.mkDefault "bottom";
      showhidden = lib.mkDefault true;
    };

    finder = {
      AppleShowAllExtensions = lib.mkDefault true;
      QuitMenuItem = lib.mkDefault true;
      FXEnableExtensionChangeWarning = lib.mkDefault false;
    };

    trackpad = {
      Clicking = lib.mkDefault true;
      TrackpadThreeFingerDrag = lib.mkDefault true;
    };
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
  };
}
