# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, lib, pkgs, common, nixpkgs-beast-pkgs, ... }:
let
  cudaPkg = nixpkgs-beast-pkgs.cudaPackages;
  cuda = cudaPkg.cudatoolkit;
  CUDA_PATH = cuda.outPath;
  CUDA_LDPATH = "${
      lib.concatStringsSep ":" [
        "/run/opengl-drivers/lib"
        "${cuda}/lib"
        "${cudaPkg.cudnn}/lib"
      ]
    }:${
      lib.makeLibraryPath [ nixpkgs-beast-pkgs.stdenv.cc.cc.lib cuda.lib ]
    }";
in
{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../../modules/audiobookshelf.nix
      ../../modules/calibre-web.nix
      ../../modules/strata/module.nix
    ];

  nix.settings = common.nixSettings;
  programs.nix-ld.enable = true;
  # Bootloader.
  # boot.kernelPackages = nixpkgs-beast-pkgs.linuxPackages_6_12;
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
    xserver.enable = true;
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;
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
      extraGroups = [ "networkmanager" "wheel" "podman" "docker" ];
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
    celluloid # Video Player
    gthumb # Image Viewer
    simple-scan # Scanning
    gnome-tweaks
  ];

  programs = {
    gnome-disks.enable = true;
  };

  # Exclude some default GNOME apps
  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    epiphany # web browser
  ];

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
      package = config.boot.kernelPackages.nvidiaPackages.production;
    };
    # nvidia-container-toolkit.enable = true;
  };

  services.jellyfin = {
    enable = true;
    openFirewall = true;
    dataDir = "/mnt/massive/jellyfin";
    cacheDir = "/mnt/massive/jellyfin/cache";
  };

  services.audiobookshelf = {
    enable = true;
    libraryDir = "/mnt/massive/books/audiobookshelf";
  };

  services.calibre-web = {
    enable = true;
    libraryDir = "/mnt/massive/books/calibre/cl";
  };

  services.sunshine = {
    enable = true;
    package = nixpkgs-beast-pkgs.sunshine.override {
      cudaSupport = true;
      inherit (nixpkgs-beast-pkgs) cudaPackages;
    };
    autoStart = false;
    capSysAdmin = true; # only needed for Wayland -- omit this when using with Xorg
    openFirewall = true;
  };

  # Sunshine's CUDA package wraps the binary in a shell script. The
  # privileged NixOS wrapper must target the ELF binary directly.
  security.wrappers.sunshine.source = lib.mkForce "${config.services.sunshine.package}/bin/.sunshine-wrapped";
  systemd.user.services.sunshine.environment.LD_LIBRARY_PATH =
    lib.makeLibraryPath [ nixpkgs-beast-pkgs.vulkan-loader ];

  services.llama-cpp = {
    enable = false;
    package = common.jacobiLegacy.pkgs.llama-cpp-cuda-latest;
    settings = {
      host = "0.0.0.0";
      port = 8015;
      # No top-level model: Pi's /llama needs the multi-model router.
      no-models-autoload = true;
      # Presets pair the existing flat model files with their projector without
      # exposing the projector as a separate model. Downloads use LLAMA_CACHE.
      models-preset = pkgs.writeText "llama-cpp-models.ini" ''
        version = 1

        [Qwen3.8-27B-UD-Q4_K_XL]
        model = /opt/box/models/Qwen3.8-27B-UD-Q4_K_XL.gguf
        mmproj = /opt/box/models/Qwen3.8-27B-mmproj-BF16.gguf
        no-mmproj-offload = true
        reasoning-effort = low
        temp = 1.0
        top-k = 20
        min-p = 0
        top-p = 0.95
        spec-type = draft-mtp
        spec-draft-n-max = 2
      '';
      ctx-size = 65536;
      n-gpu-layers = "all";
      ctx-checkpoints = 32;
      checkpoint-min-step = 0;
      jinja = true;
      flash-attn = "on";
      cache-type-k = "q8_0";
      cache-type-v = "q8_0";
      # no-mmap = true;
      batch-size = 1024;
      ubatch-size = 1024;
      sleep-idle-seconds = 300;
    };
  };

  services.alloy.enable = true;

  # Local Qwen3.8-Flash-Next (125B MoE) over an OpenAI/Anthropic-compatible API.
  # The 3090 (24 GB) takes the weights that fit; the rest lives in RAM.
  # First start downloads ~70 GB of model weights into stateDir.
  services.strata = {
    enable = true;
    family = "qwen"; # original Qwen3.8-Flash-Next ("swift" is the ~1.8x faster distill)
    model = "IQ3_S"; # best quality (~62 GB RAM; beast has 128 GB)
    context = 131072; # 128k
    stateDir = "/mnt/massive/strata"; # ~70 GB of weights on the data partition, not /
    host = "0.0.0.0";
    port = 8015;
    # gpus = [ ]; # default: engine picks the most-VRAM card (the 3090)
    # Two flags worth their cost on this box (24 GB card, experts in DDR4, long pi sessions).
    # Both are upstream measurements for this shape of machine, not forum lore; each is one
    # line to take back out if it ever earns its keep the other way.
    extraEngineArgs = [
      # INT8 keys (the attention scores stay exact) + Hadamard-rotated Q4_0 values: 816 B per
      # KV cell per attention layer where fp16 costs 2,112 (strata_control/vram_fit.py), and
      # this family is full attention only every 4th layer (docs/DETAILS.md). So the
      # --kv-resident 32768 tier keeps ~350 MB in VRAM instead of ~900 - some 550 MB back to
      # expert slots, a dozen IQ3_S blobs on a card that has none to spare - and the pinned
      # host copy the stream keeps shrinks by the same factor. Measured on a 3090 at 198K
      # context: 85 -> 99 tok/s out, same needle results, prompts 2-5% slower (docs/DETAILS.md
      # 0.1.25). K8V4 streams with --kv-resident in the CUDA build
      # (include/strata/core/layer.hpp: "streams with --kv-resident too", and the stream has
      # its own three runs for it); the "k8v4 does not stream" note in docs/INTEL.md is the
      # SYCL build. What it cannot be is the K/V ring state (kv_mode 2 in that header, the
      # drafter's window - src/core/conversation_snapshot.cpp refuses the combination), one
      # more reason that drafter stays off. Prompt checkpoints and SAVE files written in
      # another KV format do not restore - the engine drops them, it does not fail to start.
      "--kv k8v4"
      # Keep the six prompt checkpoints spread back from the conversation's end instead of the
      # six most recent ones. pi rewrites its history (compaction, dropped tool output, edits),
      # and with the default the next turn resumes at the system-prompt checkpoint and reads
      # the whole conversation again. Upstream measured exactly this: a pi coding-agent turn
      # rewritten a few steps back went 40.0 s of re-read -> 10.2 s (docs/DETAILS.md). Same
      # RAM, same bits, nothing else moves.
      "--prompt-cache-spread"
    ];
  };

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
    dockerSocket.enable = true;
  };

  # just adding this so I don't forget in the future
  # virtualisation.oci-containers = {
  #   backend = "podman";
  # };

  system.stateVersion = common.stateVersion;
}
