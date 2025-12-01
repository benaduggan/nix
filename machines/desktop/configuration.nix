{ common, config, lib, pkgs, ... }:
let
  cuda = pkgs.cudaPackages.cudatoolkit;
  CUDA_PATH = cuda.outPath;
  CUDA_LDPATH = "${
      lib.concatStringsSep ":" [
        "/run/opengl-drivers/lib"
        # "/run/opengl-drivers-32/lib"
        "${cuda}/lib"
        "${pkgs.cudaPackages.cudnn}/lib"
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


  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";
  programs.nix-ld.enable = true;

  networking.hostName = "bduggan-desktop"; # Define your hostname.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;
  systemd.services.NetworkManager-wait-online.enable = lib.mkForce false;
  systemd.services.systemd-networkd-wait-online.enable = lib.mkForce false;

  # Set your time zone.
  time.timeZone = "America/Indiana/Indianapolis";

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

  # Enable the X11 windowing system.
  # services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  # services.xserver.displayManager.gdm.enable = true;
  # services.xserver.desktopManager.gnome.enable = true;

  # Configure keymap in X11
  # services.xserver = {
  #   xkb.layout = "us";
  #   xkb.variant = "";
  # };

  # Enable CUPS to print documents.
  # services.printing.enable = true;

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
  users.users.bduggan = {
    isNormalUser = true;
    description = "Benjamin Duggan";
    extraGroups = [ "networkmanager" "wheel" ];
    openssh.authorizedKeys.keys = common.authorizedKeys;
    packages = with pkgs; [
      #  firefox
      #  thunderbird
    ];
  };

  users.users.bdugganbak = {
    isNormalUser = true;
    description = "Benjamin Duggan";
    extraGroups = [ "networkmanager" "wheel" ];
    openssh.authorizedKeys.keys = common.authorizedKeys;
  };

  # Enable automatic login for the user.
  # services.displayManager.autoLogin.enable = true;
  # services.displayManager.autoLogin.user = "bduggan";

  # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
  # systemd.services."getty@tty1".enable = false;
  # systemd.services."autovt@tty1".enable = false;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment = {
    systemPackages = with pkgs; [
      cudaPackages.cudatoolkit
      cudaPackages.cudnn
      # nvidia-docker
    ];
    variables = {
      _CUDA_PATH = CUDA_PATH;
      _CUDA_LDPATH = CUDA_LDPATH;
      XLA_FLAGS = "--xla_gpu_cuda_data_dir=${CUDA_PATH}";
    };
  };


    services.xserver.videoDrivers = [ "nvidia" ];

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    nvidia-container-toolkit = {
      enable = true;
      mount-nvidia-executables = false;
    };
    nvidia = {
      open = false;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
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

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  networking.firewall.enable = false;

  # enable tailscale and use as exit node
  services.tailscale.enable = true;
  services.tailscale.useRoutingFeatures = "both";
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  boot.kernel.sysctl."net.ipv4.conf.all.forwarding" = 1;
  boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;

  systemd.services = {
    unifi-manager-service =
      let
        myPython = pkgs.python313.withPackages (p: with p; [
          pydantic
          pyunifi
          systemd
        ]);
      in
      {
        path = [ myPython ];
        wantedBy = [ "multi-user.target" ];
        script = ''python /home/bduggan/unifi-manager/main.py'';
        startAt = "*-*-* *:*:00";
      };

    unifi-manager-exporter-service = {
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStart = ''/home/bduggan/unifi-manager/jsongorter -file /data.json -ignore name -prefix "unifi_manager_"'';
        Restart = "on-failure";
      };
    };
  };

  virtualisation.docker.enable = true;
  users.extraGroups.docker.members = [ common.username ];
  virtualisation.oci-containers = {
    backend = "docker";

    containers.homeassistant = {
      volumes = [ "home-assistant:/config" ];
      environment.TZ = "US/Eastern";
      image = "ghcr.io/home-assistant/home-assistant:2024.8.1";
      extraOptions = [
        "--network=host"
      ];
    };
  };

  services.promtail = {
    enable = true;
    configuration = {
      positions.filename = "/tmp/positions.yaml";
      server = {
        http_listen_port = 9080;
        grpc_listen_port = 0;
      };
      clients = [{
        url = "http://home-server-1:3100/loki/api/v1/push";
      }];
      scrape_configs = [
        {
          job_name = "journal";
          journal = {
            max_age = "12h";
            labels = {
              job = "systemd-journal";
              host = "lakehouse";
            };
          };
          relabel_configs = [{
            source_labels = [ "__journal__systemd_unit" ];
            target_label = "unit";
          }];
        }
      ];
    };
  };

  services._3proxy = {
    enable = true;
    services = [{
      type = "socks";
      bindPort = 1080;
      auth = [ "none" ];
    }];
  };

  # storing stuff on /mnt/bigboi/audiobookshelf
  services.audiobookshelf = {
    enable = true;
    host = "0.0.0.0";
  };

  services.calibre-web = {
    enable = true;
    listen.ip = "0.0.0.0";
    options = {
      enableBookUploading = true;
    };
  };
  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ 1080 ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = common.stateVersion;

  # services.logind.settings = {
  #   Login = {
  #     HandleLidSwitchDocked = "ignore";
  #     HandleLidSwitchExternalPower = "ignore";
  #     HandleLidSwitch = "ignore";
  #     HandleHibernateKeyLongPress = "ignore";
  #     HandleHibernateKey = "ignore";
  #     HandleSuspendKeyLongPress = "ignore";
  #     HandleSuspendKey = "ignore";
  #     HandleRebootKeyLongPress = "ignore";
  #     HandleRebootKey = "ignore";
  #     HandlePowerKeyLongPress = "ignore";
  #     HandlePowerKey = "ignore";
  #   };
  # };

  nixpkgs.config.cudaCapabilities = [ "6.1" ];

services.llama-cpp = {
  enable = true;
  package =
    let
      version = "b7211";
      hash = "sha256-u2oUTNTiFs82xTiN9na3SCu0sG+KIGMMB2lqKec4lZY=";
    in
    (pkgs.llama-cpp.overrideAttrs (old: {
      inherit version;
      src = pkgs.fetchFromGitHub {
        inherit hash;
        tag = version;
        owner = "ggerganov";
        repo = "llama.cpp";
        leaveDotGit = true;
        postFetch = ''
          git -C "$out" rev-parse --short HEAD > $out/COMMIT
          find "$out" -name .git -print0 | xargs -0 rm -rf
        '';
      };
      # Fix the build number - strip the 'b' prefix
      cmakeFlags = (old.cmakeFlags or []) ++ [
        "-DLLAMA_BUILD_NUMBER=6085"
      ];
    })).override {
      cudaSupport = true;
    };
  port = 8015;
  model = "/opt/box/models/qwen-3-4b.gguf";
  host = "0.0.0.0";
  extraFlags = ["-c" "16384" "--temp" "0.6" "--top-k" "20" "--min-p" "0" "--top-p" "0.95"
      "--n-gpu-layers" "99" "--jinja"
  ];
};
}
