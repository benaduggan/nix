{ common, ... }:
{
  users.users.benduggan = {
    name = "benduggan";
    home = "/Users/benduggan";
    openssh.authorizedKeys.keys = common.authorizedKeys;
  };

  ids.gids.nixbld = 30000;
  system = {
    primaryUser = "benduggan";
    defaults.NSGlobalDomain = {
      InitialKeyRepeat = 5;
      KeyRepeat = 5;
    };
  };

  # security.pam.enableSudoTouchIdAuth = true;

  homebrew = {
    global.autoUpdate = true;
    enable = true;
    onActivation = {
      autoUpdate = true;
      cleanup = "zap";
      upgrade = true;
    };

    #  brews = [ "readline" "qemu" ];

    taps = [ ];

    casks = map (name: { inherit name; greedy = true; }) [
      #    "epic-games"
      # "spotify"
      #   "steam"
      #  "discord"
      "slack"
      #    "obs"
      #     "karabiner-elements"
      "microsoft-remote-desktop"
      "notion"
      #      "parsec"
      "raycast"
      "rectangle"
      "firefox"
      "google-chrome"
      "visual-studio-code"
      "vlc"
      #      "zoom"
      #       "insomnia"
      "tabby"
    ];

    # These appear to be gated by having "purchased" the thing
    # even if it's free per apple id
    masApps = {
      Wireguard = 1451685025;
      # Xcode = 497799835;
    };
  };
}

