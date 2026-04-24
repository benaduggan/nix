# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, lib, pkgs, common, ... }:
let
  cudaPkg = pkgs.cudaPackages;
  cuda = cudaPkg.cudatoolkit;
  CUDA_PATH = cuda.outPath;
  CUDA_LDPATH = "${
      lib.concatStringsSep ":" [
        "/run/opengl-drivers/lib"
        "${cuda}/lib"
        "${cudaPkg.cudnn}/lib"
      ]
    }:${
      lib.makeLibraryPath [ pkgs.stdenv.cc.cc.lib cuda.lib ]
    }";
in
{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  nix.settings = common.nixSettings;
  programs.nix-ld.enable = true;
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.supportedFilesystems = [ "exfat" ];

  services.openssh.enable = true;
  networking.hostName = "beast"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  systemd.sleep.settings.Sleep = {
    AllowSuspend = "no";
    AllowHibernation = "no";
    AllowHybridSleep = "no";
    AllowSuspendThenHibernate = "no";
  };

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/Denver";

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

  services = {
    flatpak.enable = true;
    pantheon.apps.enable = true;
    xserver = {
      enable = true;
      displayManager = {
        lightdm.enable = true;
        lightdm.greeters.pantheon.enable = true;
        lightdm.extraConfig = ''
          logind-check-graphical=true
        '';
      };
    };
    desktopManager = {
      pantheon = {
        enable = true;
        extraWingpanelIndicators = with pkgs; [
          monitor
          wingpanel-indicator-namarupa
        ];
      };
    };
  };

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
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users = {
    bduggan = {
      isNormalUser = true;
      description = "ben";
      extraGroups = [ "networkmanager" "wheel" ];
      openssh.authorizedKeys.keys = common.authorizedKeys;
      packages = with pkgs; [
        #  thunderbird
      ];
    };
  };

  services.tailscale.enable = true;
  services.tailscale.useRoutingFeatures = "both";
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  boot.kernel.sysctl."net.ipv4.conf.all.forwarding" = 1;
  boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;

  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "bduggan";

  # Install firefox.
  programs.firefox.enable = true;
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.cudaCapabilities = [ "8.6" ];

  programs.steam.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.variables = {
    _CUDA_PATH = CUDA_PATH;
    _CUDA_LDPATH = CUDA_LDPATH;
    XLA_FLAGS = "--xla_gpu_cuda_data_dir=${CUDA_PATH}";
  };

  environment.systemPackages = with pkgs; [
    cudaPkg.cudatoolkit
    cudaPkg.cudnn
    appeditor # elementary OS menu editor
    celluloid # Video Player
    formatter # elementary OS filesystem formatter
    gthumb # Image Viewer
    simple-scan # Scanning
    indicator-application-gtk3 # App Indicator
    pantheon.sideload # elementary OS Flatpak installer
    pantheon-tweaks
  ];

  programs = {
    gnome-disks.enable = true;
  };

  environment.pantheon.excludePackages = with pkgs.pantheon; [
    elementary-music
    elementary-photos
    elementary-videos
    epiphany
  ];

  # App indicator
  # - https://discourse.nixos.org/t/anyone-with-pantheon-de/28422
  # - https://github.com/NixOS/nixpkgs/issues/144045#issuecomment-992487775
  environment.pathsToLink = [ "/libexec" ];

  # App indicator
  # - https://github.com/NixOS/nixpkgs/issues/144045#issuecomment-992487775
  systemd.user.services.indicatorapp = {
    description = "indicator-application-gtk3";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.indicator-application-gtk3}/libexec/indicator-application/indicator-application-service";
    };
  };


  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    nvidia = {
      open = false;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };
  };

  services.jellyfin = {
    enable = true;
    openFirewall = true;
    dataDir = "/mnt/massive/jellyfin";
    cacheDir = "/mnt/massive/jellyfin/cache";
  };

  services.sunshine = {
    enable = true;
    autoStart = false;
    capSysAdmin = true; # only needed for Wayland -- omit this when using with Xorg
    openFirewall = true;
  };

  services.llama-cpp = {
    enable = true;
    package = common.jacobi.pkgs.llama-cpp-cuda-latest;
    port = 8015;
    model = "/opt/box/models/Qwen3.6-27B-UD-Q4_K_XL.gguf";
    host = "0.0.0.0";
    extraFlags = [
      "-c"
      "65536"
      "--temp"
      "0.6"
      "--top-k"
      "20"
      "--min-p"
      "0"
      "--top-p"
      "0.8"
      "--n-gpu-layers"
      "99"
      "--jinja"
      "--flash-attn"
      "on"
      "--no-mmap"
      "-b"
      "1024"
      "-ub"
      "1024"
      "--sleep-idle-seconds"
      "300"
    ];
  };

  services.alloy.enable = true;

  system.stateVersion = common.stateVersion;
}
