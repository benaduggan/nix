{ common, lib, pkgs, ... }:
{

  nix.settings = common.nixSettings;
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

  users.users."${common.username}" = {
    name = common.username;
    shell = pkgs.bashInteractive;
    home = "/Users/${common.username}";
    openssh.authorizedKeys.keys = common.authorizedKeys;
    packages = [
      common.jacobi.pkgs.llama-cpp-latest
    ];
  };



  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 4;
  system = {
    primaryUser = common.username;
    defaults = {
      NSGlobalDomain = {
        ApplePressAndHoldEnabled = false;
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

  # security.pam.enableSudoTouchIdAuth = true;
  # services.mlx-vlm-api.servers = {
  #   qwen2-vl-2b-Instruct-4bit = {
  #     enable = true;
  #     model = "mlx-community/Qwen2.5-VL-7B-Instruct-8bit";
  #   };
  # };

  services.llama-server =
    let
      package = common.jacobi.pkgs.llama-cpp-latest;
    in
    {
      servers = {
        # deepscaler-1-5b = {
        #   inherit package;
        #   enable = true;
        #   port = 8014;
        #   model = "/opt/box/models/agentica-org_DeepScaleR-1.5B-Preview-Q8_0.gguf";
        #   ngl = 99;
        # };
        # qwen-coder-14 = {
        #   inherit package;
        #   enable = true;
        #   port = 8020;
        #   model = "/opt/box/models/qwen25coder14.gguf";
        #   ngl = 99;
        # };
        # qwen-coder-32 = {
        #   inherit package;
        #   enable = true;
        #   port = 8020;
        #   model = "/opt/box/models/Qwen2.5-Coder-32B-Instruct-Q4_0.gguf";
        #   ngl = 99;
        # };
        # qwen-coder = {
        #   inherit package;
        #   enable = true;
        #   port = 8015;
        #   model = "/opt/box/models/Qwen2.5.1-Coder-7B-Instruct-Q6_K_L.gguf";
        #   ngl = 99;
        # };
        # qwen-r1-distill = {
        #   inherit package;
        #   enable = false;
        #   port = 8016;
        #   model = "/opt/box/models/DeepSeek-R1-Distill-Qwen-14B-Q8_0.gguf";
        #   ngl = 99;
        #   extraFlags = "-c 16384";
        # };


        # mutually exclusive:
        # gemma-3-12b = {
        #   inherit package;
        #   enable = true;
        #   port = 8017;
        #   model = "/opt/box/models/gemma-3-12b.gguf";
        #   ngl = 99;
        #   extraFlags = "-c 16384 --temp 1.0 --top-k 64 --min-p 0 --top-p 0.95";
        # };
        # qwen-3-30-a3b-ud = {
        #   inherit package;
        #   enable = true;
        #   port = 8017;
        #   model = "/opt/box/models/qwen-3-30-ud-q4.gguf";
        #   ngl = 99;
        #   extraFlags = "-c 16384 --temp 0.6 --top-k 20 --min-p 0 --top-p 0.95";
        # };
        qwen-3-coder-30-a3b-ud = {
          inherit package;
          enable = true;
          port = 8017;
          model = "/opt/box/models/qwen-3-coder-30b-a3b.gguf";
          ngl = 99;
          extraFlags = "-c 16384 --temp 0.6 --top-k 20 --min-p 0 --top-p 0.95";
        };
      };
    };

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
      "homebrew/services"
    ];

    casks = map (name: { inherit name; greedy = true; }) [
      "authy"
      "font-fira-code-nerd-font"
      "spotify"
      "discord"
      # "slack"
      "karabiner-elements"
      "microsoft-remote-desktop"
      "qlvideo"
      "raycast"
      "rectangle"
      "firefox"
      "chromium"
      "google-chrome"
      "visual-studio-code"
      "vlc"
      "insomnia"
      "tabby"
    ];

    # should install directly -> tailscale, notion, docker

    # These appear to be gated by having "purchased" the thing
    # even if it's free per apple id
    # masApps = {
    #   Wireguard = 1451685025;
    #   # Xcode = 497799835;
    # };
  };
}

