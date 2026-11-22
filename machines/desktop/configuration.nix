{ common, config, inputs, lib, pkgs, ... }:
let
  # Use time-traveled nixpkgs for CUDA packages
  nixpkgs-pascal-cuda-meme = import inputs.nixpkgs-pascal-cuda {
    system = pkgs.stdenv.hostPlatform.system;
    config = {
      allowUnfree = true;
      cudaCapabilities = [ "6.1" ];
    };
  };
  cudaPkg = nixpkgs-pascal-cuda-meme.cudaPackages;
  cuda = cudaPkg.cudatoolkit;
  CUDA_PATH = cuda.outPath;
  CUDA_LDPATH = "${
      lib.concatStringsSep ":" [
        "/run/opengl-drivers/lib"
        # "/run/opengl-drivers-32/lib"
        "${cuda}/lib"
        "${cudaPkg.cudnn}/lib"
      ]
    }:${
      lib.makeLibraryPath [ nixpkgs-pascal-cuda-meme.stdenv.cc.cc.lib cuda.lib ]
    }";

in
{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../../modules/vaultwarden-replication.nix
    ];

  # Bootloader.
  # Keep the 6.12 kernel series while using the module layout expected by
  # the current nixpkgs module aggregator.
  boot.kernelPackages = pkgs.linuxPackages_6_12;
  # The NVIDIA module only autoloads with X enabled; this machine uses the
  # GPU for CUDA without enabling the X server.
  boot.kernelModules = [ "nvidia" ];
  hardware.deviceTree.enable = false;
  system.boot.loader.kernelFile = "bzImage";
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";

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

  services.pipewire.enable = true;

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

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment = {
    systemPackages = [
      cudaPkg.cudatoolkit
      cudaPkg.cudnn
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
      # Keep the Pascal-compatible 580 driver on the current kernel's
      # module packaging, including its module certificates.
      package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
    };
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  services.vaultwardenReplication = {
    enable = true;
    role = "standby";
    secretFile = ../../secrets/vaultwarden.age;
    archiveDir = common.desktopVaultwardenArchiveDir;
  };

  networking.firewall.enable = false;

  systemd.services = {
    unifi-manager-service =
      let
        myPython = pkgs.python313.withPackages (p: with p; [
          pydantic
          pyunifi
          systemd-python
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
      image = "ghcr.io/home-assistant/home-assistant:2026.8.3";
      extraOptions = [
        "--network=host"
      ];
    };
  };

  services.alloy.hostLabel = "lakehouse";

  services._3proxy.enable = true;

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
  system.stateVersion = "24.11";

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

  services.llama-cpp = {
    enable = true;
    package =
      let
        version = "b7211";
        hash = "sha256-UPjQBoqLM9u2TGrltdHtfYF+Q204kgZ3JWM0I4iYdyg=";
      in
      # Use llama-cpp entirely from pinned nixpkgs to avoid ABI mismatches
      (nixpkgs-pascal-cuda-meme.llama-cpp.overrideAttrs (old: {
        inherit version;
        src = nixpkgs-pascal-cuda-meme.fetchFromGitHub {
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
        cmakeFlags = (old.cmakeFlags or [ ]) ++ [
          "-DLLAMA_BUILD_NUMBER=6085"
          "-DCMAKE_CUDA_ARCHITECTURES=61"
        ];
      })).override {
        cudaSupport = true;
      };
    settings = {
      host = "0.0.0.0";
      port = 8015;
      model = "/opt/box/models/qwen-3-4b.gguf";
      ctx-size = 16384;
      temp = 0.6;
      top-k = 20;
      min-p = 0;
      top-p = 0.95;
      n-gpu-layers = 99;
      jinja = true;
    };
  };
}
